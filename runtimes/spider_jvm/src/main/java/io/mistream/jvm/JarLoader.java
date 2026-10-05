package io.mistream.jvm;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.TimeUnit;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.jar.JarOutputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import org.objectweb.asm.AnnotationVisitor;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassVisitor;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.Label;
import org.objectweb.asm.MethodVisitor;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.Type;
import org.objectweb.asm.TypePath;
import org.objectweb.asm.tree.AbstractInsnNode;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.FieldNode;
import org.objectweb.asm.tree.InsnNode;
import org.objectweb.asm.tree.InvokeDynamicInsnNode;
import org.objectweb.asm.tree.LabelNode;
import org.objectweb.asm.tree.LdcInsnNode;
import org.objectweb.asm.tree.MethodInsnNode;
import org.objectweb.asm.tree.JumpInsnNode;
import org.objectweb.asm.tree.LookupSwitchInsnNode;
import org.objectweb.asm.tree.MultiANewArrayInsnNode;
import org.objectweb.asm.tree.TableSwitchInsnNode;
import org.objectweb.asm.tree.TryCatchBlockNode;
import org.objectweb.asm.tree.MethodNode;
import org.objectweb.asm.tree.TypeInsnNode;
import org.objectweb.asm.tree.VarInsnNode;

/**
 * 加载 TVBox 蜘蛛 jar。
 *
 * 关键点（B1/B2 研究结论）：
 * - 配置源的 `spider` 字段指向的 jar 是 **dex jar**（内含 classes.dex），标准
 *   JVM 无法直接加载，必须先转成 java class jar。
 * - dex2jar 的转换产物在 JVM 严格验证下会被拒绝（static 误标、坏 StackMapTable、
 *   非法 ConstantValue），且 static 误标问题遍布产物（Init、Market、protobuf 等），
 *   纯 Java 修复不现实。因此主转换器用 **enjarify**（Google，Python3，产物字节码
 *   干净、严格验证可通过）。
 * - enjarify 会丢弃全部注解，而 qist 蜘蛛的 JSON 字段靠 @SerializedName 注解映射
 *   （如字段 a→"class"），所以从 dex2jar 产物（保留注解）里按 name+desc 拷贝
 *   类/字段/方法注解回来。
 * - enjarify 会把 R8 内联的 `new X; invoke-direct Object.<init>` 原样转成
 *   `new X; invokespecial Object.<init>`（DEX 合法，JVM 拒绝 "Call to wrong
 *   initialization method"），需要改写 owner 为 X 并合成缺失的 <init>。
 * - enjarify 的 writeField 对非基础类型的 final 字段（HashMap 等）错误附带
 *   ConstantValue，需要跳过（已在 enjarify-adapter 里打补丁）。
 * - 转换以子进程方式调用：enjarify（python3）与 dex2jar（本运行时所在 java），
 *   避免在运行时进程内加载 dex2jar 污染类路径。结果按原始 jar 的 MD5 缓存。
 * - 转换后的 jar 用 URLClassLoader 加载，parent 是本运行时（android shim +
 *   okhttp3 + org.json 等都在运行时 classpath 里）。
 */
public final class JarLoader {

    private static final String DEX_ENTRY = "classes.dex";
    /**
     * 转换缓存前缀。**改了转换逻辑就要改这里** —— 缓存按「原始 jar 的 md5」命名，
     * 不含转换器版本，不升版会一直复用旧产物。
     *
     * v2 -> v3（2026-10-04）：开始从 dex2jar 产物拷回**泛型签名**，修 Gson 的
     * TypeToken 校验崩溃（见 copyAnnotations 注释）。
     *
     * v3 -> v4（2026-10-05）：新增接口方法规范化，修
     * `ClassFormatError: ... has illegal modifiers`（见 normalizeInterfaceMethods）。
     *
     * v4 -> v5（2026-10-05）：新增 invoke-super owner 修正，修
     * `StackOverflowError at ...Pan.init`（见 fixSuperCalls）。
     *
     * v5 -> v6（2026-10-05）：重写 init owner 修正（旧实现因「不记调用点所在类」而
     * 实际是 no-op），修 `VerifyError: Call to wrong initialization method`（见 fixInitOwner）。
     *
     * v6 -> v7（2026-10-05）：修 v6 那个「假修好」—— 汇合点判定把 try-catch 的
     * start/end 也算进去，而 enjarify 每个 dex try 区间都产一个 try-catch 块，
     * 导致追踪器每步清栈、修复实际仍是 no-op；同时补上 `uninitializedThis` 场景
     * 与「栈按值计数」（见 fixInitOwner 的 bug 清单）。
     *
     * v7 -> v8（2026-10-05）：v7 仍漏 `merge/A0/et` 那种「`super()` 分散在
     * tableswitch 各分支」的构造器 —— 线性扫描扫完第一个分支就把 `this` 标成已初始化，
     * 后面几个分支再也认不出来。修法：汇合点重置时把 `this` 也恢复成未初始化
     * （保守，只会多认出真错点）。
     *
     * v8 -> v9（2026-10-05）：新增**最后一道**工序「接口方法引用修正」——
     * enjarify 对 `invoke-static` 目标其实是接口的静态方法（`Comparator.comparingInt`
     * 之类）时置 `itf=false`，JVM 报
     * `IncompatibleClassChangeError: ... must be InterfaceMethodref constant`。
     * 修 itf 的同时必须把那些类升到 major 52（49 不允许 invokestatic 引
     * InterfaceMethodref）并重算 StackMapTable（见 InterfaceRefFixer）。
     *
     * v9 -> v10（2026-10-05）：新增「JCE 变换名改写」——
     * Android 的 JCE 是 BouncyCastle，认 `PKCS7Padding`；桌面 JDK 的 SunJCE 只认
     * `PKCS5Padding`，`Cipher.getInstance("AES/ECB/PKCS7Padding")` 直接抛
     * `NoSuchAlgorithmException: Cannot find any provider supporting ...`。
     * 实测 csp_AppDrama 的 init 就是这么挂的（还有 csp_Czsapp 与 merge 包里的公共
     * 加解密工具）。修法：把常量池里的变换串改写掉（见 fixCryptoTransforms）。
     *
     * v10 -> v11（2026-10-05）：v10 只认「完整变换名 ALG/MODE/PKCS7Padding」，
     * 实测只改到 11 处 / 7 类，`csp_AppDrama` 依旧报同一个
     * `NoSuchAlgorithmException`。反汇编后确认它的变换名是**运行时拼**的：
     * `"AES/" + mode + "/PKCS7Padding"`，常量池里根本没有完整串，只有片段
     * `"/PKCS7Padding"`。v11 让 `rewritePkcs7` 同时认片段形式（见该方法注释）。
     */
    private static final String CACHE_PREFIX = "converted-v11-";

    private final File cacheDir;
    private final List<File> runtimeClasspath;

    JarLoader(File cacheDir, List<File> runtimeClasspath) {
        this.cacheDir = cacheDir;
        this.runtimeClasspath = runtimeClasspath;
        if (!cacheDir.exists() && !cacheDir.mkdirs()) {
            throw new IllegalStateException("无法创建 jar 缓存目录: " + cacheDir);
        }
    }

    /** 计算文件 MD5（用于缓存命名）。 */
    static String md5(File file) throws IOException {
        MessageDigest md;
        try {
            md = MessageDigest.getInstance("MD5");
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IOException(e);
        }
        try (FileInputStream in = new FileInputStream(file)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) {
                md.update(buf, 0, n);
            }
        }
        StringBuilder sb = new StringBuilder();
        for (byte b : md.digest()) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    /** 判断是否为 dex jar（内含 classes.dex）。 */
    static boolean isDexJar(File jar) throws IOException {
        try (ZipInputStream zin = new ZipInputStream(new FileInputStream(jar))) {
            ZipEntry entry;
            while ((entry = zin.getNextEntry()) != null) {
                if (entry.getName().equals(DEX_ENTRY)) return true;
            }
        }
        return false;
    }

    /**
     * 加载 jar 并返回类加载器。
     *
     * @param jarPath   原始 jar 路径（dex 或 java 均可）
     * @param className 要加载的 csp_ 类全名
     * @return 已加载并实例化前的 ClassLoader
     */
    ClassLoader loadJar(String jarPath) throws Exception {
        File jar = new File(jarPath);
        if (!jar.exists()) {
            throw new IOException("jar 不存在: " + jarPath);
        }
        File loadable = isDexJar(jar) ? convert(jar) : jar;
        URL[] urls = {loadable.toURI().toURL()};
        return new URLClassLoader(urls, JarLoader.class.getClassLoader());
    }

    /**
     * 把 dex jar 转成可严格验证的 java jar，结果缓存到 cacheDir。
     *
     * 管线：提取 classes.dex → enjarify（严格验证可用产物）→ dex2jar（注解供体）
     * → 修 init owner → 从 dex2jar 拷贝注解 → 补缺失类 stub → 接口方法规范化 → 缓存。
     */
    File convert(File dexJar) throws Exception {
        String digest = md5(dexJar);
        File out = new File(cacheDir, CACHE_PREFIX + digest + ".jar");
        if (out.exists() && out.length() > 0) {
            return out;
        }

        File work = new File(cacheDir, "work-" + digest);
        deleteQuietly(work);
        if (!work.mkdirs()) {
            throw new IOException("无法创建工作目录: " + work);
        }

        File classesDex = new File(work, "classes.dex");
        File enjarifyRaw = new File(work, "enjarify.jar");
        File enjarifyFixed = new File(work, "enjarify-fixed.jar");
        File dex2jarRaw = new File(work, "dex2jar.jar");
        File superFixed = new File(work, "enjarify-super.jar");
        File tmp = new File(cacheDir, CACHE_PREFIX + digest + ".tmp");
        File tmpStubbed = new File(cacheDir, CACHE_PREFIX + digest + ".tmp2");
        File tmpNormalized = new File(cacheDir, CACHE_PREFIX + digest + ".tmp3");
        File tmpIface = new File(cacheDir, CACHE_PREFIX + digest + ".tmp4");
        File tmpCrypto = new File(cacheDir, CACHE_PREFIX + digest + ".tmp5");
        try {
            extractEntry(dexJar, DEX_ENTRY, classesDex);
            runEnjarify(classesDex, enjarifyRaw);
            runDex2jar(dexJar, dex2jarRaw);
            // 修 init owner 后再拷贝注解（注解来自 dex2jar 产物，其注解与 fix 前一致）
            fixInitOwner(enjarifyRaw, enjarifyFixed);
            // dex `invoke-super` 被 enjarify 译错 owner —— 会变成自己调自己（见该方法注释）
            fixSuperCalls(enjarifyFixed, superFixed);
            copyAnnotations(dex2jarRaw, superFixed, tmp);
            // R8 合并类残留引用：为缺失类合成 stub（见 addMissingStubs 注释）
            addMissingStubs(tmp, tmpStubbed);
            // 转换产物修补：接口方法规范化 + maxStack/maxLocals 重算（见该方法注释）
            normalizeConvertedClasses(tmpStubbed, tmpNormalized);
            // JCE 变换名改写（PKCS7Padding -> PKCS5Padding）—— 必须在类集合定型后、
            // 且在 InterfaceRefFixer 之前（后者可能重算 StackMapTable，改常量要在那之前）。
            fixCryptoTransforms(tmpNormalized, tmpCrypto);
            // 接口方法引用修正（Methodref / InterfaceMethodref）—— 必须放在**最后**：
            // 它要按「类集合已定型」来判断 owner 是不是接口（stub 也在这一步之前补完）。
            // 需要引用 InterfaceMethodref 的类会被升到 major 52 并重算 StackMapTable。
            InterfaceRefFixer.Report ir =
                InterfaceRefFixer.fix(tmpCrypto, tmpIface, runtimeClasspath);
            if (ir.fixed > 0) {
                System.err.println("[jvm] 接口方法引用修正 " + ir.fixed + " 处"
                    + "（Methodref/InterfaceMethodref 标记错，见 InterfaceRefFixer）"
                    + (ir.upgraded.isEmpty() ? ""
                        : "；类文件版本升到 52 的类 " + ir.upgraded.size() + " 个: "
                          + String.join(", ", ir.upgraded)));
            }
            if (!tmpIface.renameTo(out)) {
                Files.move(tmpIface.toPath(), out.toPath(),
                    StandardCopyOption.REPLACE_EXISTING);
            }
            return out;
        } finally {
            deleteQuietly(work);
            deleteQuietly(tmp);
            deleteQuietly(tmpStubbed);
            deleteQuietly(tmpNormalized);
            deleteQuietly(tmpIface);
            deleteQuietly(tmpCrypto);
        }
    }

    // ---- enjarify ----------------------------------------------------------

    /**
     * 用 Python3 运行 enjarify 把 .dex 转成 jar。
     * enjarify-adapter 无 __main__，通过 -c 调用其 python API。
     */
    private void runEnjarify(File dex, File outJar) throws IOException {
        String[] py = findPython();
        if (py == null) {
            throw new IOException("未找到 Python3（py/python3/python）——需要它运行 "
                + "enjarify 转换器，请安装 Python3 并 `pip install enjarify-adapter`");
        }
        List<String> cmd = new ArrayList<>(List.of(py));
        cmd.add("-c");
        cmd.add("import sys; from enjarify import enjarify; "
            + "enjarify(sys.argv[1], output_file=sys.argv[2], overwrite=True, "
            + "quiet=True, raise_translation_errors=True)");
        cmd.add(dex.getAbsolutePath());
        cmd.add(outJar.getAbsolutePath());
        String out = runSubprocess(cmd);
        if (!outJar.exists() || outJar.length() == 0) {
            deleteQuietly(outJar);
            throw new IOException("enjarify 转换失败: " + out.trim());
        }
    }

    /** 探测可用的 python3，并确认已装 enjarify。 */
    private static String[] findPython() {
        String[][] candidates = { {"py", "-3"}, {"python3"}, {"python"} };
        for (String[] cand : candidates) {
            try {
                List<String> cmd = new ArrayList<>(List.of(cand));
                cmd.add("-c");
                cmd.add("import enjarify");
                Process p = new ProcessBuilder(cmd).redirectErrorStream(true).start();
                boolean done = p.waitFor(15, TimeUnit.SECONDS);
                if (done && p.exitValue() == 0) return cand;
            } catch (Exception ignored) {
            }
        }
        return null;
    }

    // ---- dex2jar（仅作注解供体） ---------------------------------------------

    private void runDex2jar(File dexJar, File outJar) throws IOException {
        String javaBin = new File(System.getProperty("java.home"), "bin/java").getPath();
        if (!new File(javaBin).exists()) {
            javaBin = new File(System.getProperty("java.home"), "bin/java.exe").getPath();
        }
        String classpath = buildDex2jarClasspath();
        if (classpath == null || classpath.isEmpty()) {
            throw new IOException("dex2jar 库未在运行时 classpath 中找到");
        }
        List<String> cmd = new ArrayList<>();
        cmd.add(javaBin);
        cmd.add("-cp");
        cmd.add(classpath);
        cmd.add("com.googlecode.dex2jar.tools.Dex2jarCmd");
        cmd.add(dexJar.getAbsolutePath());
        cmd.add("-o");
        cmd.add(outJar.getAbsolutePath());
        String out = runSubprocess(cmd);
        if (!outJar.exists() || outJar.length() == 0) {
            deleteQuietly(outJar);
            throw new IOException("dex2jar 转换失败: " + out.trim());
        }
    }

    // ---- ASM：JCE 变换名改写 ----------------------------------------------------

    /**
     * 把常量池里的 {@code .../PKCS7Padding} 变换名改写成 {@code .../PKCS5Padding}。
     *
     * <p><b>为什么需要</b>：Android 的 JCE 实现是 BouncyCastle，它把
     * {@code PKCS7Padding} 注册成了标准填充名；桌面 JDK 的 SunJCE **只认
     * {@code PKCS5Padding}**。于是 {@code Cipher.getInstance("AES/ECB/PKCS7Padding")}
     * 直接抛：
     *
     * <pre>
     * java.security.NoSuchAlgorithmException:
     *     Cannot find any provider supporting AES/ECB/PKCS7Padding
     * </pre>
     *
     * <p>实测踩到的源：{@code csp_AppDrama}（init 阶段就炸）、{@code csp_Czsapp}，
     * 以及 merge 包里被多个源共用的加解密工具类。
     *
     * <p><b>为什么改写是安全的</b>：PKCS#5 只定义了 8 字节分组的填充，PKCS#7 把它
     * 推广到 1..255 字节分组。对 AES（16 字节分组）来说两者**逐字节完全等价** ——
     * 都是「补 N 个字节、每个字节的值都是 N」。所以改写后与 Android 上的密文
     * 完全一致，不是近似。
     *
     * <p><b>为什么在 jar 层面改，而不是注册一个 JCE provider</b>：试过后者，失败。
     * JDK 17 的 {@code Cipher.getInstance} 会先用
     * {@code Transform.suffix} 对 {@code service.getAlgorithm()} 做
     * {@code endsWith} 匹配，再按 {@code SupportedModes}/{@code SupportedPaddings}
     * 属性做正则过滤；自建 provider 即使注册成功、{@code Provider.getService}
     * 也查得到，仍然会在这一层被静默跳过（SPI 连实例化都不会发生）。
     * 与其和 JDK 内部选择逻辑较劲，不如在常量池上做一次等价的确定性改写。
     */
    private void fixCryptoTransforms(File inJar, File outJar) throws IOException {
        Map<String, ClassNode> classes = readClasses(inJar);
        int rewritten = 0;
        Set<String> touched = new TreeSet<>();
        for (ClassNode cn : classes.values()) {
            for (MethodNode m : cn.methods) {
                if (m.instructions == null) continue;
                for (AbstractInsnNode insn : m.instructions.toArray()) {
                    if (!(insn instanceof LdcInsnNode)) continue;
                    Object cst = ((LdcInsnNode) insn).cst;
                    if (!(cst instanceof String)) continue;
                    String fixed = rewritePkcs7((String) cst);
                    if (fixed == null) continue;
                    ((LdcInsnNode) insn).cst = fixed;
                    rewritten++;
                    touched.add(cn.name);
                }
            }
        }
        writeJar(inJar, outJar, classes);
        if (rewritten > 0) {
            System.err.println("[jvm] JCE 变换名改写 " + rewritten + " 处"
                + "（PKCS7Padding -> PKCS5Padding，见 fixCryptoTransforms）"
                + "，涉及 " + touched.size() + " 个类");
        }
    }

    /**
     * 把 {@code PKCS7Padding} 改写成 {@code PKCS5Padding}；不是这个填充名就返回 {@code null}。
     *
     * <p>要处理两种字面量形式（都实测出现过）：
     *
     * <ol>
     *   <li><b>片段形式</b>：{@code "/PKCS7Padding"} 或裸 {@code "PKCS7Padding"}。
     *       源用 StringBuilder 拼变换名时就是这个形状 —— 例如 csp_AppDrama：
     *       {@code "AES/" + mode + "/PKCS7Padding"}，常量池里只留下
     *       {@code "AES/"} 和 {@code "/PKCS7Padding"} 两段。</li>
     *   <li><b>完整变换名</b>：{@code ALG/MODE/PKCS7Padding}。</li>
     * </ol>
     *
     * <p>大小写风格原样保留（全大写输入 → 全大写输出），避免改出
     * {@code AES/ECB/PKCS5PADDING} 这种和源风格不一致的串。
     */
    private static String rewritePkcs7(String s) {
        // 形式 1：整串（允许带前导斜杠）就是填充名
        int lead = 0;
        while (lead < s.length() && s.charAt(lead) == '/') lead++;
        if (lead < s.length()) {
            String tail = s.substring(lead);
            if (tail.equalsIgnoreCase("PKCS7Padding")) {
                return s.substring(0, lead) + pkcs5Like(tail);
            }
        }
        // 形式 2：完整变换名 ALG/MODE/PKCS7Padding（形状严格校验，避免误改业务串）
        int slash = s.lastIndexOf('/');
        if (slash <= 0 || slash == s.length() - 1) return null;
        String pad = s.substring(slash + 1);
        if (!pad.equalsIgnoreCase("PKCS7Padding")) return null;
        String head = s.substring(0, slash);
        int prev = head.lastIndexOf('/');
        if (prev <= 0 || prev == head.length() - 1) return null;
        for (int i = 0; i < head.length(); i++) {
            char c = head.charAt(i);
            if (!(Character.isLetterOrDigit(c) || c == '/')) return null;
        }
        return head + "/" + pkcs5Like(pad);
    }

    /** 按入参的大小写风格产出 {@code PKCS5Padding}。 */
    private static String pkcs5Like(String pkcs7) {
        return pkcs7.equals(pkcs7.toUpperCase(java.util.Locale.ROOT))
            ? "PKCS5PADDING" : "PKCS5Padding";
    }

    // ---- ASM：缺失类 stub 合成 --------------------------------------------------

    /**
     * R8 类合并残留引用修复。
     *
     * qist 这类重度混淆的 dex 里，R8 把一组 helper 类合并进一个幸存类后，部分
     * 引用（checkcast / invokevirtual / 数组 clone 等）仍指向被合并掉的类，且这些
     * 类的成员在幸存类里找不到（合并时改名或属死代码路径）。标准 JVM 在
     * 加载/链接这些引用时会抛 NoClassDefFoundError，导致 csp_ 蜘蛛整体不可用。
     *
     * 做法：扫描全部 class 的指令级引用，对「被引用但未定义、且不在运行时
     * classpath、也不是 JDK 平台类」的缺失类，合成同名 stub——声明被引用的
     * 成员（方法体返回默认值），使 JVM 能完成加载与链接。缺失引用多见于死代码
     * 路径，stub 不影响正常功能；即便命中也只是拿到默认值而非崩溃。
     */
    private void addMissingStubs(File inJar, File outJar) throws IOException {
        Map<String, ClassNode> classes = new LinkedHashMap<>();
        Set<String> defined = new HashSet<>();
        // owner -> "name:desc" -> bits（1=static, 2=instance）
        Map<String, Map<String, Integer>> methodRefs = new HashMap<>();
        Map<String, Map<String, Integer>> fieldRefs = new HashMap<>();
        Map<String, Integer> classRefs = new HashMap<>();
        Set<String> interfaceOwners = new HashSet<>();
        Set<String> superOwners = new HashSet<>();

        try (JarFile jf = new JarFile(inJar)) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                if (!e.getName().endsWith(".class")) continue;
                byte[] b;
                try (InputStream is = jf.getInputStream(e)) {
                    b = readAll(is);
                }
                try {
                    new ClassReader(b).accept(new RefScan(defined, methodRefs, fieldRefs,
                        classRefs, interfaceOwners, superOwners), 0);
                } catch (Exception ignored) {
                    // 个别坏类直接跳过，stub 只依赖可读的引用
                }
                ClassNode cn = new ClassNode();
                try {
                    new ClassReader(b).accept(cn, 0);
                    classes.put(cn.name, cn);
                } catch (Exception ignored) {
                }
            }
        }

        // provided = 运行时 classpath 提供的类（父加载器可见，绝不能 stub 覆盖）
        Set<String> provided = new HashSet<>();
        for (File f : runtimeClasspath) {
            if (!f.exists() || f.isDirectory()) continue;
            try (JarFile jf = new JarFile(f)) {
                Enumeration<JarEntry> en = jf.entries();
                while (en.hasMoreElements()) {
                    JarEntry e = en.nextElement();
                    if (e.getName().endsWith(".class")) {
                        provided.add(e.getName().substring(0, e.getName().length() - 6));
                    }
                }
            } catch (IOException ignored) {
            }
        }

        Set<String> missing = new TreeSet<>();
        for (String r : allRefs(methodRefs, fieldRefs, classRefs, interfaceOwners, superOwners)) {
            if (defined.contains(r) || provided.contains(r) || isPlatform(r)) continue;
            missing.add(r);
        }
        if (!missing.isEmpty()) {
            System.err.println("[jvm] 为 " + missing.size()
                + " 个 R8 合并残留缺失类合成 stub（" + inJar.getName() + "）");
        }

        Map<String, byte[]> stubs = new LinkedHashMap<>();
        for (String name : missing) {
            stubs.put(name, buildStub(name,
                methodRefs.getOrDefault(name, Map.of()),
                fieldRefs.getOrDefault(name, Map.of()),
                interfaceOwners.contains(name)));
        }

        try (JarFile jf = new JarFile(inJar);
                JarOutputStream jos = new JarOutputStream(new FileOutputStream(outJar))) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                byte[] data;
                try (InputStream is = jf.getInputStream(e)) {
                    data = readAll(is);
                }
                jos.putNextEntry(new JarEntry(e.getName()));
                jos.write(data);
                jos.closeEntry();
            }
            for (Map.Entry<String, byte[]> me : stubs.entrySet()) {
                jos.putNextEntry(new JarEntry(me.getKey() + ".class"));
                jos.write(me.getValue());
                jos.closeEntry();
            }
        }
    }

    private static Set<String> allRefs(Map<String, Map<String, Integer>> mr,
            Map<String, Map<String, Integer>> fr, Map<String, Integer> cr,
            Set<String> io, Set<String> so) {
        Set<String> out = new TreeSet<>();
        out.addAll(mr.keySet());
        out.addAll(fr.keySet());
        out.addAll(cr.keySet());
        out.addAll(io);
        out.addAll(so);
        return out;
    }

    /** JDK/平台自带类：引导加载器提供，子加载器 stub 会错误地 shadow 掉它们。 */
    private static boolean isPlatform(String name) {
        return name.startsWith("java/") || name.startsWith("javax/")
            || name.startsWith("jdk/") || name.startsWith("sun/")
            || name.startsWith("com/sun/") || name.startsWith("org/w3c/")
            || name.startsWith("org/xml/") || name.startsWith("org/ietf/")
            || name.startsWith("kotlin/") || name.startsWith("kotlinx/")
            || name.startsWith("org/jetbrains/") || name.startsWith("org/intellij/")
            || name.startsWith("jrt-fs");
    }

    /** 数组描述符 / 内部名 → 元素类内部名；原始类型数组返回 null。 */
    private static String normalizeClassRef(String type) {
        if (type == null) return null;
        if (type.startsWith("[")) {
            int i = 1;
            while (type.charAt(i) == '[') i++;
            if (type.charAt(i) == 'L') {
                return type.substring(i + 1, type.length() - 1);
            }
            return null;
        }
        if (type.startsWith("L") && type.endsWith(";")) {
            return type.substring(1, type.length() - 1);
        }
        return type;
    }

    /** 扫描一个类里的指令级引用。 */
    private static final class RefScan extends ClassVisitor {
        private static final int STATIC = 1;
        private static final int INSTANCE = 2;

        final Set<String> defined;
        final Map<String, Map<String, Integer>> methodRefs;
        final Map<String, Map<String, Integer>> fieldRefs;
        final Map<String, Integer> classRefs;
        final Set<String> interfaceOwners;
        final Set<String> superOwners;

        RefScan(Set<String> d, Map<String, Map<String, Integer>> mr,
                Map<String, Map<String, Integer>> fr, Map<String, Integer> cr,
                Set<String> io, Set<String> so) {
            super(Opcodes.ASM9);
            defined = d;
            methodRefs = mr;
            fieldRefs = fr;
            classRefs = cr;
            interfaceOwners = io;
            superOwners = so;
        }

        @Override
        public void visit(int version, int access, String name, String signature,
                String superName, String[] interfaces) {
            defined.add(name);
            if (superName != null) superOwners.add(superName);
            if (interfaces != null) {
                for (String i : interfaces) interfaceOwners.add(i);
            }
        }

        void addMethodRef(String owner, String name, String desc, boolean isStatic) {
            if (owner == null) return;
            if (owner.startsWith("[")) {  // 数组 .clone() 等：只需元素类存在
                String el = normalizeClassRef(owner);
                if (el != null) addClassRef(el);
                return;
            }
            Map<String, Integer> m = methodRefs.computeIfAbsent(owner, k -> new HashMap<>());
            String key = name + desc;
            m.merge(key, isStatic ? STATIC : INSTANCE, (a, b) -> a | b);
        }

        void addFieldRef(String owner, String name, String desc, boolean isStatic) {
            if (owner == null) return;
            Map<String, Integer> m = fieldRefs.computeIfAbsent(owner, k -> new HashMap<>());
            String key = name + ":" + desc;
            m.merge(key, isStatic ? STATIC : INSTANCE, (a, b) -> a | b);
        }

        void addClassRef(String type) {
            String n = normalizeClassRef(type);
            if (n != null) classRefs.merge(n, 1, Integer::sum);
        }

        @Override
        public MethodVisitor visitMethod(int access, String name, String desc,
                String signature, String[] exceptions) {
            return new MethodVisitor(Opcodes.ASM9) {
                @Override
                public void visitMethodInsn(int opcode, String owner, String mname,
                        String mdesc, boolean itf) {
                    if (itf) interfaceOwners.add(owner);
                    addMethodRef(owner, mname, mdesc, opcode == Opcodes.INVOKESTATIC);
                }

                @Override
                public void visitFieldInsn(int opcode, String owner, String fname,
                        String fdesc) {
                    addFieldRef(owner, fname, fdesc,
                        opcode == Opcodes.GETSTATIC || opcode == Opcodes.PUTSTATIC);
                }

                @Override
                public void visitTypeInsn(int opcode, String type) {
                    addClassRef(type);
                }

                @Override
                public void visitLdcInsn(Object value) {
                    if (value instanceof Type) {
                        addClassRef(((Type) value).getInternalName());
                    }
                }

                @Override
                public void visitMultiANewArrayInsn(String desc, int dims) {
                    addClassRef(desc);
                }

                @Override
                public void visitTryCatchBlock(Label start, Label end, Label handler,
                        String type) {
                    if (type != null) addClassRef(type);
                }

                @Override
                public AnnotationVisitor visitAnnotation(String descriptor,
                        boolean visible) {
                    addClassRef(descriptor);
                    return null;
                }

                @Override
                public AnnotationVisitor visitTypeAnnotation(int typeRef,
                        TypePath typePath, String descriptor, boolean visible) {
                    addClassRef(descriptor);
                    return null;
                }
            };
        }

        @Override
        public AnnotationVisitor visitAnnotation(String descriptor, boolean visible) {
            addClassRef(descriptor);
            return null;
        }

        @Override
        public AnnotationVisitor visitTypeAnnotation(int typeRef, TypePath typePath,
                String descriptor, boolean visible) {
            addClassRef(descriptor);
            return null;
        }

        @Override
        public void visitInnerClass(String name, String outerName, String innerName,
                int access) {
            addClassRef(name);
        }
    }

    /** 用 ASM 合成一个缺失类的 stub class。 */
    private static byte[] buildStub(String name, Map<String, Integer> methods,
            Map<String, Integer> fields, boolean isInterface) {
        ClassWriter cw = new ClassWriter(ClassWriter.COMPUTE_MAXS);
        if (isInterface) {
            cw.visit(52, Opcodes.ACC_PUBLIC | Opcodes.ACC_INTERFACE | Opcodes.ACC_ABSTRACT,
                name, null, "java/lang/Object", new String[0]);
        } else {
            cw.visit(52, Opcodes.ACC_PUBLIC | Opcodes.ACC_SUPER, name, null,
                "java/lang/Object", new String[0]);
        }

        for (Map.Entry<String, Integer> fe : fields.entrySet()) {
            String key = fe.getKey();
            int colon = key.indexOf(':');
            String fname = key.substring(0, colon), fdesc = key.substring(colon + 1);
            int bits = fe.getValue();
            boolean stat = (bits & 1) != 0 && (bits & 2) == 0;
            int acc = Opcodes.ACC_PUBLIC | (stat ? Opcodes.ACC_STATIC : 0);
            Object dv = null;
            if (isInterface) {
                acc |= Opcodes.ACC_STATIC | Opcodes.ACC_FINAL;
                dv = defaultFieldValue(fdesc);
            }
            cw.visitField(acc, fname, fdesc, null, dv).visitEnd();
        }

        Set<String> initDescs = new HashSet<>();
        for (Map.Entry<String, Integer> me : methods.entrySet()) {
            String key = me.getKey();
            int paren = key.indexOf('(');
            String mname = key.substring(0, paren), mdesc = key.substring(paren);
            int bits = me.getValue();
            boolean stat = (bits & 1) != 0 && (bits & 2) == 0;
            if (mname.equals("<init>")) {
                if (isInterface) continue;
                initDescs.add(mdesc);
                MethodVisitor mv = cw.visitMethod(
                    Opcodes.ACC_PUBLIC, "<init>", mdesc, null, null);
                mv.visitCode();
                mv.visitVarInsn(Opcodes.ALOAD, 0);
                mv.visitMethodInsn(
                    Opcodes.INVOKESPECIAL, "java/lang/Object", "<init>", "()V", false);
                mv.visitInsn(Opcodes.RETURN);
                mv.visitMaxs(0, 0);
                mv.visitEnd();
                continue;
            }
            int acc = Opcodes.ACC_PUBLIC | (stat ? Opcodes.ACC_STATIC : 0);
            if (isInterface) acc |= Opcodes.ACC_ABSTRACT;
            MethodVisitor mv = cw.visitMethod(acc, mname, mdesc, null, null);
            if (isInterface) {
                mv.visitEnd();
                continue;
            }
            mv.visitCode();
            emitDefaultReturn(mv, Type.getReturnType(mdesc));
            mv.visitMaxs(0, 0);
            mv.visitEnd();
        }
        if (!isInterface && !initDescs.contains("()V")) {
            MethodVisitor mv = cw.visitMethod(Opcodes.ACC_PUBLIC, "<init>", "()V", null, null);
            mv.visitCode();
            mv.visitVarInsn(Opcodes.ALOAD, 0);
            mv.visitMethodInsn(Opcodes.INVOKESPECIAL, "java/lang/Object", "<init>", "()V", false);
            mv.visitInsn(Opcodes.RETURN);
            mv.visitMaxs(0, 0);
            mv.visitEnd();
        }
        cw.visitEnd();
        return cw.toByteArray();
    }

    private static void emitDefaultReturn(MethodVisitor mv, Type rt) {
        switch (rt.getSort()) {
            case Type.VOID:
                mv.visitInsn(Opcodes.RETURN);
                break;
            case Type.BOOLEAN:
            case Type.BYTE:
            case Type.SHORT:
            case Type.CHAR:
            case Type.INT:
                mv.visitInsn(Opcodes.ICONST_0);
                mv.visitInsn(Opcodes.IRETURN);
                break;
            case Type.FLOAT:
                mv.visitInsn(Opcodes.FCONST_0);
                mv.visitInsn(Opcodes.FRETURN);
                break;
            case Type.LONG:
                mv.visitInsn(Opcodes.LCONST_0);
                mv.visitInsn(Opcodes.LRETURN);
                break;
            case Type.DOUBLE:
                mv.visitInsn(Opcodes.DCONST_0);
                mv.visitInsn(Opcodes.DRETURN);
                break;
            default:
                mv.visitInsn(Opcodes.ACONST_NULL);
                mv.visitInsn(Opcodes.ARETURN);
                break;
        }
    }

    private static Object defaultFieldValue(String desc) {
        if (desc.length() == 1) {
            switch (desc.charAt(0)) {
                case 'B':
                case 'S':
                case 'C':
                case 'I':
                case 'Z':
                    return Integer.valueOf(0);
                case 'F':
                    return Float.valueOf(0f);
                case 'J':
                    return Long.valueOf(0L);
                case 'D':
                    return Double.valueOf(0d);
                default:
                    break;
            }
        }
        return null;
    }

    // ---- ASM 修复：init owner ------------------------------------------------

    /** `uninitializedThis` 的伪实例 id（真 id 从 1 开始，用 -1 不会撞）。 */
    private static final int THIS_ID = -1;

    /** `uninitializedThis` 的伪类型名 —— 不是真实类名，只用来区分「构造器里的 this」。 */
    private static final String THIS_TYPE = "<this>";

    /**
     * 未初始化引用追踪器。
     *
     * <p>只做 JVM 校验器需要的那部分抽象解释：**操作数栈** + **局部槽位**，值域是
     * 「未初始化实例 id」或「其它（已初始化 / 非引用 / 未知）」。
     *
     * <p><b>计数口径必须区分</b>（踩过坑）：
     * <ul>
     *   <li>操作数栈按**值**计数 —— long/double 也算 **1** 个值；</li>
     *   <li>局部槽位按**槽**计数 —— long/double 占 **2** 个槽。</li>
     * </ul>
     * 早先两边都按「槽」算，于是 {@code invokespecial X.&lt;init&gt;(J)V} 会把接收者
     * 也一并弹掉，追踪当场断掉（该修的调用点一个都没修到）。
     *
     * <p>用**实例 id**（每次 {@code NEW} 一个）而不是类名，因为 {@code dup} 出来的两份
     * 是**同一个**实例，一次 {@code &lt;init&gt;} 会让两份都变成已初始化。
     *
     * <p>为什么必须追踪「已初始化」：`new X; astore N; …; invokespecial X.&lt;init&gt;`
     * 之后槽位 N 装的是**已初始化**的 X。若不失效它，后面任何
     * `aload N; invokespecial Y.&lt;init&gt;` 都会被误判成「X 的构造调用」，把
     * `new String` 和 `JSONObject.&lt;init&gt;` 配成一对 —— 实测 79 处误报。
     */
    private static final class UninitTracker {
        /** 操作数栈：Integer=未初始化实例 id；null=其它。**按值计数**（long/double 算 1）。 */
        private final List<Object> stack = new ArrayList<>();
        /** 槽位 -> 未初始化实例 id。只装未初始化引用，其它一律移除。**按槽计数**。 */
        private final Map<Integer, Integer> slots = new HashMap<>();
        private final Map<Integer, String> types = new HashMap<>();
        private int nextId = 1;
        /** 构造器里 `this` 所在的槽位；-1 = 当前方法不是构造器。 */
        private int thisSlot = -1;
        private boolean thisInitialized;

        /** 构造器开头调一次：把 `this` 标成未初始化。 */
        void seedThis(int slot) {
            thisSlot = slot;
            thisInitialized = false;
            slots.put(slot, THIS_ID);
            types.put(THIS_ID, THIS_TYPE);
        }

        void pushUninit(String type) {
            int id = nextId++;
            types.put(id, type);
            stack.add(id);
        }

        void pushUnknown() {
            stack.add(null);
        }

        void pushSlot(int slot) {
            stack.add(slots.get(slot));
        }

        /** `ASTORE s`：弹出栈顶一个值；是未初始化引用就记到槽 s，否则清掉槽 s。 */
        void store(int slot) {
            if (stack.isEmpty()) {
                slots.remove(slot);
                return;
            }
            Object v = stack.remove(stack.size() - 1);
            if (v instanceof Integer) slots.put(slot, (Integer) v);
            else slots.remove(slot);
        }

        /**
         * 非引用的 `xSTORE s`：栈顶不可能是未初始化引用，槽 s 直接作废。
         *
         * @param width 该 store 占用的槽数（long/double 为 2）
         */
        void storeOther(int slot, int width) {
            pop();
            for (int i = 0; i < width; i++) slots.remove(slot + i);
        }

        void dup() {
            if (!stack.isEmpty()) stack.add(stack.get(stack.size() - 1));
        }

        /** `dup_x1`：`[a, b] -> [b, a, b]`。 */
        void dupX1() {
            int n = stack.size();
            if (n < 2) {
                clearStack();
                return;
            }
            Object a = stack.get(n - 1);
            Object b = stack.get(n - 2);
            stack.set(n - 2, a);
            stack.set(n - 1, b);
            stack.add(b);
        }

        void pop() {
            if (!stack.isEmpty()) stack.remove(stack.size() - 1);
        }

        /** 值计数口径下 `pop2` 弹 1 个还是 2 个取决于栈顶是否 2 槽值 —— 保守弹 2。 */
        void pop2() {
            for (int i = 0; i < 2 && !stack.isEmpty(); i++) stack.remove(stack.size() - 1);
        }

        void swap() {
            int n = stack.size();
            if (n < 2) {
                clearStack();
                return;
            }
            Object a = stack.get(n - 1);
            stack.set(n - 1, stack.get(n - 2));
            stack.set(n - 2, a);
        }

        /** 弹出 n 个**值**；栈不够说明建模失败（已清栈，返回 false）。 */
        boolean popValues(int n) {
            if (n <= 0) return true;
            if (stack.size() < n) {
                clearStack();
                return false;
            }
            for (int i = 0; i < n; i++) stack.remove(stack.size() - 1);
            return true;
        }

        Object popValue() {
            return stack.isEmpty() ? null : stack.remove(stack.size() - 1);
        }

        String typeOf(Object v) {
            return v instanceof Integer ? types.get((Integer) v) : null;
        }

        /** `<init>` 执行完毕：该实例（含 dup 出来的所有副本）变成已初始化。 */
        void initialize(Object v) {
            if (!(v instanceof Integer)) return;
            Integer id = (Integer) v;
            if (id == THIS_ID) thisInitialized = true;
            types.remove(id);
            for (int i = 0; i < stack.size(); i++) {
                if (id.equals(stack.get(i))) stack.set(i, null);
            }
            slots.values().removeIf(id::equals);
        }

        /**
         * 丢操作数栈、**保留槽位**，并把 `this` 保守地当作「还没初始化」。
         *
         * <p>用于控制流汇合点与未建模指令。槽位之所以能保留：JVM 校验器要求
         * 「未初始化类型在汇合点必须**完全相等**」—— 既不能和另一个未初始化类型合并，
         * 也不能和已初始化类型合并。所以同一个槽位在汇合点两侧装的必定是同一个
         * 未初始化实例。而栈的形状在汇合点无法保证，必须丢。
         *
         * <p><b>`this` 为什么必须重置</b>：线性扫描没有路径概念，而
         * `super()` 可能出现在**每个分支**里 —— 实测
         * {@code merge/A0/et.<init>(String,int)V} 用 {@code tableswitch} 分三路，
         * 每路各有一份 super 调用（{@code dr.<init>} / {@code Object.<init>} /
         * {@code Object.<init>}）。扫到第一路时 {@link #initialize} 会把 `this`
         * 标成已初始化，于是另外两路就再也认不出来。汇合点重置是**保守**的：
         * 只会多认出真错点，不会把对的改错（`this` 已初始化后本来也不允许再调
         * {@code <init>}）。
         */
        void clearStack() {
            stack.clear();
            reseedThis();
        }

        /**
         * 异常处理器入口：栈被重置为**恰好一个**异常对象。
         * 槽位与 `this` 的处理同 {@link #clearStack()}。
         */
        void resetHandler() {
            stack.clear();
            stack.add(null);
            reseedThis();
        }

        /** `this` 回到「未初始化」态（构造器才有）。 */
        private void reseedThis() {
            if (thisSlot < 0) return;
            thisInitialized = false;
            slots.put(thisSlot, THIS_ID);
            types.put(THIS_ID, THIS_TYPE);
        }

        /** 仅 {@link #traceInitOwners} 用：把人看得懂的状态拼出来。 */
        String dump() {
            StringBuilder sb = new StringBuilder("stack=[");
            for (int i = 0; i < stack.size(); i++) {
                if (i > 0) sb.append(',');
                Object v = stack.get(i);
                if (v == null) sb.append('-');
                else if (v instanceof Integer && (Integer) v == THIS_ID) sb.append("<this>");
                else sb.append(types.getOrDefault(v, "?"));
            }
            sb.append("] slots=").append(slots);
            return sb.toString();
        }
    }

    /**
     * 修「`<init>` owner 不对」的调用点。共两类，症状都是
     * {@code VerifyError: ... Call to wrong initialization method}（类加载失败，
     * 站点直接不可用），但成因与修法不同。
     *
     * <h3>甲类：`new X` 之后的构造调用指向祖先</h3>
     * <pre>
     * new-instance X ; invoke-direct Y.&lt;init&gt;(desc)      // Y 是 X 的祖先
     * </pre>
     * R8 会把「只继承、不新增任何东西」的类（{@code merge/c/c}、{@code merge/A0/rp}、
     * 匿名内部类 {@code Djuu$1}…）的构造器**整个删掉**，把构造调用直接指向祖先。
     * ART 接受（X 自己没有构造器，直接用祖先的），**JVM 不接受** ——
     * 对 {@code uninitialized(X)} 只能调 X 自己的 {@code <init>}。
     * <p>修法：owner 改回 X，并保证 X 声明 {@code <init>(desc)}。
     *
     * <h3>乙类：`uninitializedThis` 调了祖父的构造器</h3>
     * <pre>
     * // adc extends ya extends xh
     * adc.&lt;init&gt;(I)V:  … ; invokespecial xh.&lt;init&gt;()V     // xh 是祖父
     * </pre>
     * 同一原因的另一面：R8 把**中间层**（{@code ya}）的构造器也删了，于是子类的
     * super 调用跳到了祖父。JVM 对 {@code uninitializedThis} 的约束更严 ——
     * **只能**调本类或**直接父类**的 {@code <init>}。
     * <p>修法：owner 改成**直接父类** {@code cn.superName}，再由 {@link #ensureCtor}
     * 沿链补出「委托给自己直接父类」的构造器。
     * <p>为什么不直接把 {@code cn.superName} 改成 {@code mi.owner}（改继承关系）：
     * 那会让 {@code adc} 不再是 {@code ya} 的子类，破坏 assignability
     * （{@code checkcast}/{@code invokevirtual} 立刻出问题）。改调用点则**语义等价** ——
     * 我们补出的 {@code ya.&lt;init&gt;()V} 就是「原样转发给 xh.&lt;init&gt;()V」。
     *
     * <h3>为什么必须逐级合成</h3>
     * 实测（{@code GrandSuperTest}，手工 ASM 造字节码）：
     * <ul>
     *   <li>{@code C.<init>} 里调**祖父** {@code A.<init>} →
     *       {@code VerifyError: Bad <init> method call}
     *       （"Type 't/A' is not assignable to 't/C'"）；</li>
     *   <li>{@code new C; invokespecial A.<init>} →
     *       {@code VerifyError: Call to wrong <init> method}；</li>
     *   <li>对照 {@code new C; invokespecial C.<init>} → 通过。</li>
     * </ul>
     * 所以「补一个直接委托祖先的构造器」不够 —— 中间每一级都得有自己的
     * {@code <init>}，且每一级只委托**自己的直接父类**。
     *
     * <h3>⚠️ 本方法曾经是个静默 no-op（三个 bug，2026-10-05 逐个定位）</h3>
     * <ol>
     *   <li>调用点记录里**没有「在哪个类」**，改写循环只能去扫
     *       {@code classes.get(newCls)} 的方法 —— 扫的是被 new 的类，而调用点在
     *       **别的类**里，一个都改不到（除非某类 new 自己）；</li>
     *   <li>槽位追踪不区分「未初始化」与「已初始化」，误报 79/231；</li>
     *   <li>**最致命**：{@link #mergeLabels} 把 try-catch 的 {@code start}/{@code end}
     *       也当成汇合点，而 enjarify 会把 dex 的每个 try 区间都翻译成一个
     *       try-catch 块（实测一个方法 29 个），于是**几乎每条指令前都挂着一个
     *       「汇合点」Label** → 追踪器每走一步就清空一次 →
     *       {@code new X; astore N; aload N; invokespecial} 这种 4 条指令的窗口
     *       都撑不过去。表现为：日志说「修正 172 处」看着挺好，实际
     *       {@code Djuu}/{@code JianPian}/{@code merge/A0/oj} 这些站点照旧
     *       {@code VerifyError}。定位工具：{@code TrackProbe}（逐指令打印追踪状态）。</li>
     * </ol>
     */
    private void fixInitOwner(File inJar, File outJar) throws IOException {
        Map<String, ClassNode> classes = readClasses(inJar);
        int[] stats = rewriteInitOwners(classes, false, null, null, null, null);
        writeJar(inJar, outJar, classes);
        int rewrittenNew = stats[0];
        int rewrittenThis = stats[1];
        int synthesized = stats[2];
        int skipped = stats[3];
        if (rewrittenNew > 0 || rewrittenThis > 0 || synthesized > 0) {
            System.err.println("[jvm] init owner 修正 " + (rewrittenNew + rewrittenThis)
                + " 处调用点（new 场景 " + rewrittenNew + "，this 场景 " + rewrittenThis
                + "；合成构造器 " + synthesized + " 个）"
                + (skipped > 0 ? "；跳过 " + skipped + " 处（owner 不是祖先，存疑）" : ""));
        }
    }

    /**
     * 只读自检：扫一个**已转换**的 jar，报告里面**仍然存在**的「`<init>` owner 不对」
     * 调用点。
     *
     * <p><b>为什么要把它放进运行时、而不是另写一个独立扫描器</b>：2026-10-05 之前
     * {@code .workbuddy-ai/scripts/InitOwnerScan.java} 是手抄一份追踪器，结果**抄了同一个
     * bug**（汇合点判定过宽），于是「工具报 0、站点照样 VerifyError」——
     * 假阴性比没有工具更坏。现在自检和修复**共用同一套追踪器**
     * （{@link #rewriteInitOwners}），结构上不可能再对不上。
     *
     * <p>工具只是壳：{@code InitOwnerScan} 调的就是这个方法。
     *
     * @return 残留错点描述（空列表 = 干净）；格式 {@code 类::方法  new X -> Y.<init>desc}
     */
    public static List<String> auditInitOwners(File jar) throws IOException {
        List<String> residual = new ArrayList<>();
        rewriteInitOwners(readClasses(jar), true, residual, null, null, null);
        return residual;
    }

    /**
     * 逐指令打印追踪器的判定过程，用于定位**假阴性**（「自检说 0、站点照样
     * {@code VerifyError}」）。
     *
     * <p>与 {@link #auditInitOwners} 一样，跑的是修复器**本体**的循环，所以打印出来的
     * 状态就是修复时看到的状态 —— 不会出现「调试工具和线上逻辑不是一回事」。
     * 工具壳：{@code TrackProbe}。
     *
     * @param cls    内部类名（{@code com/github/...}）
     * @param method 方法名；null = 该类全部方法
     */
    public static void traceInitOwners(File jar, String cls, String method, PrintStream out)
            throws IOException {
        rewriteInitOwners(readClasses(jar), true, null, out, cls, method);
    }

    /** 读一个 jar 的全部 class 到 {@code name -> ClassNode}。 */
    private static Map<String, ClassNode> readClasses(File jar) throws IOException {
        Map<String, ClassNode> classes = new LinkedHashMap<>();
        try (JarFile jf = new JarFile(jar)) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                if (!e.getName().endsWith(".class")) continue;
                byte[] bytes;
                try (InputStream is = jf.getInputStream(e)) {
                    bytes = readAll(is);
                }
                ClassNode cn = new ClassNode();
                new ClassReader(bytes).accept(cn, 0);
                classes.put(cn.name, cn);
            }
        }
        return classes;
    }

    /**
     * 遍历所有方法，找出并（非 dryRun 时）改写「`<init>` owner 不对」的调用点。
     *
     * @param dryRun   true = 只报告不改写（自检用）
     * @param residual dryRun 时把残留错点描述写进来（可为 null）
     * @param trace    非 null 时，对 {@code traceCls}（+ 可选 {@code traceMethod}）
     *                 逐指令打印追踪状态（调试用，见 {@link #traceInitOwners}）
     * @return {@code [new 场景改写数, this 场景改写数, 合成构造器数, 跳过数]}
     */
    private static int[] rewriteInitOwners(Map<String, ClassNode> classes,
            boolean dryRun, List<String> residual, PrintStream trace,
            String traceCls, String traceMethod) {
        // 就地改写调用点：owner 换成「真正被 new 的类」或「直接父类」
        List<String[]> needCtor = new ArrayList<>();   // {类名, 描述符}
        int[] counters = new int[3];   // {new 场景, this 场景, 跳过}
        for (ClassNode cn : classes.values()) {
            for (MethodNode m : cn.methods) {
                if (m.instructions == null) continue;
                Set<AbstractInsnNode> merges = mergeLabels(m);
                Set<AbstractInsnNode> handlers = handlerLabels(m);
                UninitTracker t = new UninitTracker();
                if (m.name.equals("<init>") && (m.access & Opcodes.ACC_STATIC) == 0) {
                    t.seedThis(0);
                }
                boolean tracing = trace != null && cn.name.equals(traceCls)
                        && (traceMethod == null || m.name.equals(traceMethod));
                if (tracing) {
                    trace.println("class " + cn.name + " extends " + cn.superName
                            + "  (major=" + cn.version + ")");
                    trace.println("---- " + m.name + m.desc + "  指令数=" + m.instructions.size()
                            + "  tryCatch=" + (m.tryCatchBlocks == null ? 0 : m.tryCatchBlocks.size())
                            + "  汇合点Label=" + merges.size() + "  处理器Label=" + handlers.size());
                }
                int idx = 0;
                for (AbstractInsnNode insn : m.instructions.toArray()) {
                    String tag = tracing ? String.format("%4d ", idx) : null;
                    idx++;
                    if (insn instanceof LabelNode) {
                        // 只有**真**汇合点才丢栈；try 区间的 start/end 不是汇合点，
                        // enjarify 会把它们插在几乎每条指令前（见方法注释 bug 3）。
                        boolean isHandler = handlers.contains(insn);
                        boolean isMerge = merges.contains(insn);
                        if (isHandler) t.resetHandler();
                        else if (isMerge) t.clearStack();
                        if (tracing) {
                            trace.println(tag + "LABEL"
                                    + (isHandler ? "  <- 异常处理器，resetHandler()"
                                        : isMerge ? "  <- 汇合点，clearStack()" : "")
                                    + "   | " + t.dump());
                        }
                        continue;
                    }
                    String act = stepInsn(insn, cn, m, t, classes, dryRun,
                            residual, needCtor, counters, tracing);
                    if (tracing) {
                        trace.println(tag + describe(insn) + "   -> " + act
                                + "   | " + t.dump());
                    }
                }
            }
        }

        // 合成缺失的 <init>(desc)：沿父类链逐级委托（自检模式不改字节码）
        int synthesized = 0;
        if (!dryRun) {
            for (String[] nc : needCtor) {
                synthesized += ensureCtor(classes, nc[0], nc[1], 0);
            }
        }
        return new int[] {counters[0], counters[1], synthesized, counters[2]};
    }

    /**
     * 处理一条指令（Label 由调用方处理），维护追踪器状态，并在需要时改写调用点。
     *
     * <p>抽出来是为了让 {@link #rewriteInitOwners} 的主循环能统一打印 trace：
     * 每个分支只返回一句「做了什么」，不再各自 {@code continue}。
     *
     * @param counters {@code {new 场景改写数, this 场景改写数, 跳过数}}，原地累加
     * @param tracing  是否要拼 trace 文案（false 时一律返回 null，省开销）
     * @return trace 文案（不 tracing 时为 null）
     */
    private static String stepInsn(AbstractInsnNode insn, ClassNode cn, MethodNode m,
            UninitTracker t, Map<String, ClassNode> classes, boolean dryRun,
            List<String> residual, List<String[]> needCtor, int[] counters,
            boolean tracing) {
        int op = insn.getOpcode();
        if (op == Opcodes.NEW) {
            String d = ((TypeInsnNode) insn).desc;
            t.pushUninit(d);
            return tracing ? "pushUninit " + d : null;
        }
        if (op == Opcodes.DUP) {
            t.dup();
            return tracing ? "dup" : null;
        }
        if (op == Opcodes.DUP_X1) {
            t.dupX1();
            return tracing ? "dup_x1" : null;
        }
        if (op == Opcodes.POP) {
            t.pop();
            return tracing ? "pop" : null;
        }
        if (op == Opcodes.POP2) {
            t.pop2();
            return tracing ? "pop2" : null;
        }
        if (op == Opcodes.SWAP) {
            t.swap();
            return tracing ? "swap" : null;
        }
        if (op == Opcodes.ASTORE) {
            int v = ((VarInsnNode) insn).var;
            t.store(v);
            return tracing ? "astore " + v : null;
        }
        if (op == Opcodes.ISTORE || op == Opcodes.FSTORE) {
            int v = ((VarInsnNode) insn).var;
            t.storeOther(v, 1);
            return tracing ? "store(1槽) " + v : null;
        }
        if (op == Opcodes.LSTORE || op == Opcodes.DSTORE) {
            int v = ((VarInsnNode) insn).var;
            t.storeOther(v, 2);
            return tracing ? "store(2槽) " + v : null;
        }
        if (op == Opcodes.ALOAD) {
            int v = ((VarInsnNode) insn).var;
            t.pushSlot(v);
            return tracing ? "pushSlot " + v : null;
        }
        if (op == Opcodes.INVOKESPECIAL) {
            MethodInsnNode mi = (MethodInsnNode) insn;
            String detail = mi.owner + "." + mi.name + mi.desc;
            if (!mi.name.equals("<init>")) {
                // 非构造的 invokespecial 会消费接收者，直接丢栈
                t.clearStack();
                return tracing ? "clearStack（非 <init> 的 invokespecial）" : null;
            }
            if (!t.popValues(argCount(mi.desc))) {
                return tracing ? "** 建模失败：栈不够，已 clearStack" : null;
            }
            Object recv = t.popValue();
            String x = t.typeOf(recv);
            if (x == null) {
                t.initialize(recv);
                return tracing ? "接收者未知，跳过   " + detail : null;
            }
            String origOwner = mi.owner;
            String verdict;
            if (THIS_TYPE.equals(x)) {
                if (mi.owner.equals(cn.name) || mi.owner.equals(cn.superName)) {
                    verdict = "this 场景 ok";
                } else {
                    String sup = cn.superName;
                    if (sup != null && isAncestorOrUnknown(classes, sup, mi.owner)) {
                        if (!dryRun) mi.owner = sup;
                        counters[1]++;
                        needCtor.add(new String[] {sup, mi.desc});
                        verdict = "this 场景改写 " + origOwner + " -> " + sup;
                        if (residual != null) {
                            residual.add(cn.name + "." + m.name + m.desc
                                + "  <this> -> " + origOwner + ".<init>" + mi.desc
                                + "  [可修：改指直接父类 " + sup + "]");
                        }
                    } else {
                        counters[2]++;
                        verdict = "this 场景但 owner 不是祖先，跳过";
                        if (residual != null) {
                            residual.add(cn.name + "." + m.name + m.desc
                                + "  <this> -> " + mi.owner + ".<init>" + mi.desc
                                + "  [无法修：owner 不是祖先]");
                        }
                    }
                }
            } else if (x.equals(mi.owner)) {
                verdict = "new 场景 ok";
            } else {
                if (!dryRun) mi.owner = x;
                counters[0]++;
                needCtor.add(new String[] {x, mi.desc});
                verdict = "new 场景改写 " + origOwner + " -> " + x;
                if (residual != null) {
                    residual.add(cn.name + "." + m.name + m.desc
                        + "  new " + x + " -> " + origOwner + ".<init>" + mi.desc);
                }
            }
            t.initialize(recv);
            return tracing ? verdict + "   " + detail : null;
        }
        if (op == Opcodes.INVOKEVIRTUAL || op == Opcodes.INVOKEINTERFACE
                || op == Opcodes.INVOKESTATIC) {
            MethodInsnNode mi = (MethodInsnNode) insn;
            int pop = argCount(mi.desc) + (op == Opcodes.INVOKESTATIC ? 0 : 1);
            if (!t.popValues(pop)) {
                return tracing ? "** 建模失败：栈不够，已 clearStack" : null;
            }
            if (retCount(mi.desc) > 0) t.pushUnknown();
            return tracing ? "popValues(" + pop + ") 后压未知返回值" : null;
        }
        if (op == Opcodes.INVOKEDYNAMIC) {
            InvokeDynamicInsnNode d = (InvokeDynamicInsnNode) insn;
            if (!t.popValues(argCount(d.desc))) {
                return tracing ? "** 建模失败：栈不够，已 clearStack" : null;
            }
            if (retCount(d.desc) > 0) t.pushUnknown();
            return tracing ? "invokedynamic" : null;
        }
        if (op == Opcodes.MULTIANEWARRAY) {
            int dims = ((MultiANewArrayInsnNode) insn).dims;
            if (!t.popValues(dims)) {
                return tracing ? "** 建模失败：栈不够，已 clearStack" : null;
            }
            t.pushUnknown();
            return tracing ? "multianewarray dims=" + dims : null;
        }
        if (op == Opcodes.ATHROW) {
            t.popValues(1);
            t.clearStack();
            return tracing ? "athrow" : null;
        }
        int eff = stackEffect(op);
        if (eff < 0) {
            t.clearStack();
            return tracing ? "clearStack（未建模 op=" + op + "）" : null;
        }
        if (!t.popValues(eff / 10)) {
            return tracing ? "** 建模失败：栈不够，已 clearStack" : null;
        }
        for (int i = 0; i < eff % 10; i++) t.pushUnknown();
        return tracing ? "popValues(" + (eff / 10) + ")" : null;
    }

    /** trace 用：把一条指令渲染成人能看的样子。 */
    private static String describe(AbstractInsnNode insn) {
        int op = insn.getOpcode();
        if (op < 0) return "LINE/FRAME";
        if (insn instanceof VarInsnNode) return "op" + op + " var=" + ((VarInsnNode) insn).var;
        if (insn instanceof TypeInsnNode) return "op" + op + " " + ((TypeInsnNode) insn).desc;
        if (insn instanceof MethodInsnNode) {
            MethodInsnNode mi = (MethodInsnNode) insn;
            return "op" + op + " " + mi.owner + "." + mi.name + mi.desc;
        }
        if (insn instanceof JumpInsnNode) return "op" + op + " -> " + ((JumpInsnNode) insn).label;
        return "op" + op;
    }

    /**
     * 保证 {@code cls} 声明 {@code <init>(desc)}；缺则沿父类链逐级补。
     *
     * <p>接口不补（接口不能有 {@code <init>}）。
     *
     * @return 本次**新增**的构造器个数
     */
    private static int ensureCtor(Map<String, ClassNode> classes, String cls,
            String desc, int depth) {
        if (depth > 32) return 0;                       // 继承链异常深，放弃
        ClassNode cn = classes.get(cls);
        if (cn == null) return 0;                       // 不在本 jar（JDK/库类）→ 假定已有
        if ((cn.access & Opcodes.ACC_INTERFACE) != 0) return 0;
        if (declaredMethod(cn, "<init>", desc) != null) return 0;   // 已有
        String sup = cn.superName;
        if (sup == null) return 0;                      // 没有父类可委托
        int n = ensureCtor(classes, sup, desc, depth + 1);
        cn.methods.add(delegatingCtor(desc, sup));
        return n + 1;
    }

    /**
     * 判断 {@code owner} 是不是 {@code from} 的祖先（沿 {@code superName} 上溯）。
     *
     * <p>上溯**走出本 jar**（JDK/库类）时返回 {@code true} —— 无法证伪就假定它是祖先；
     * 只有在本 jar 内一路走到 {@code java/lang/Object} 仍未命中，才判定「不是祖先」。
     * 这样 {@code aa extends wa}（{@code wa} 在 jar 里，再往上是 JDK 的
     * {@code java/lang/Enum}）这类跨 jar 的祖孙关系不会被误判。
     */
    private static boolean isAncestorOrUnknown(Map<String, ClassNode> classes,
            String from, String owner) {
        String cur = from;
        for (int i = 0; i < 64 && cur != null; i++) {
            if (cur.equals(owner)) return true;
            ClassNode cn = classes.get(cur);
            if (cn == null) return true;                // 出 jar：无法证伪
            cur = cn.superName;
        }
        return false;
    }

    /** 造一个「原样转发给直接父类」的构造器：`aload_0; <load args>; invokespecial sup.<init>(desc); return`。 */
    private static MethodNode delegatingCtor(String desc, String superName) {
        MethodNode mn = new MethodNode(Opcodes.ACC_PUBLIC, "<init>", desc, null, null);
        mn.instructions.add(new VarInsnNode(Opcodes.ALOAD, 0));
        int slot = 1;
        for (Type t : Type.getArgumentTypes(desc)) {
            mn.instructions.add(loadLocal(t, slot));
            slot += t.getSize();
        }
        mn.instructions.add(new MethodInsnNode(
            Opcodes.INVOKESPECIAL, superName, "<init>", desc, false));
        mn.instructions.add(new InsnNode(Opcodes.RETURN));
        int slots = 1 + argSlotsOf(desc);
        mn.maxStack = slots;
        mn.maxLocals = slots;
        return mn;
    }

    /** 按类型从局部槽位装载参数。 */
    private static AbstractInsnNode loadLocal(Type t, int slot) {
        switch (t.getSort()) {
            case Type.BOOLEAN:
            case Type.BYTE:
            case Type.SHORT:
            case Type.CHAR:
            case Type.INT:
                return new VarInsnNode(Opcodes.ILOAD, slot);
            case Type.FLOAT:
                return new VarInsnNode(Opcodes.FLOAD, slot);
            case Type.LONG:
                return new VarInsnNode(Opcodes.LLOAD, slot);
            case Type.DOUBLE:
                return new VarInsnNode(Opcodes.DLOAD, slot);
            default:
                return new VarInsnNode(Opcodes.ALOAD, slot);
        }
    }

    /** 方法描述符的参数槽位数（long/double 占 2）。仅用于合成构造器。 */
    private static int argSlotsOf(String desc) {
        int n = 0;
        for (Type t : Type.getArgumentTypes(desc)) {
            n += t.getSize();
        }
        return n;
    }

    /** 方法描述符的参数**个数**（操作数栈按值计数，long/double 也算 1）。 */
    private static int argCount(String desc) {
        return Type.getArgumentTypes(desc).length;
    }

    /** 返回值的**值**个数（void 为 0，其余为 1）。 */
    private static int retCount(String desc) {
        return Type.getReturnType(desc).getSort() == Type.VOID ? 0 : 1;
    }

    /**
     * 指令对操作数栈的净效果，编码为 {@code pop * 10 + push}（**按值**计数，
     * long/double 也算 1 个值）；返回 {@code -1} 表示未建模 —— 调用方应清栈。
     *
     * <p>只求「不误丢状态」：push 一律记为「未知值」。我们唯一关心的是未初始化引用，
     * 而它只由 {@code NEW} 产生，{@code NEW} / {@code DUP*} / {@code xSTORE} /
     * {@code ALOAD} / {@code INVOKESPECIAL} 在主循环里单独处理，不走这张表。
     */
    private static int stackEffect(int op) {
        // *const / bipush / sipush / ldc：压 1 个值
        if (op >= Opcodes.ICONST_M1 && op <= Opcodes.DCONST_1) return 1;
        if (op == Opcodes.BIPUSH || op == Opcodes.SIPUSH || op == Opcodes.LDC) return 1;
        // xLOAD：压 1 个值（槽位里的未初始化引用由 ALOAD 单独处理）
        if (op >= Opcodes.ILOAD && op <= Opcodes.ALOAD) return 1;
        // xALOAD：弹 2（数组引用 + 下标）压 1
        if (op >= Opcodes.IALOAD && op <= Opcodes.SALOAD) return 21;
        // xASTORE：弹 3（数组引用 + 下标 + 值）
        if (op >= Opcodes.IASTORE && op <= Opcodes.SASTORE) return 30;
        switch (op) {
            case Opcodes.NOP:
            case Opcodes.IINC:
            case Opcodes.GOTO:
                return 0;
            case Opcodes.IRETURN: case Opcodes.LRETURN: case Opcodes.FRETURN:
            case Opcodes.DRETURN: case Opcodes.ARETURN:
                return 10;
            case Opcodes.RETURN:
                return 0;
            case Opcodes.GETSTATIC:
                return 1;
            case Opcodes.PUTSTATIC:
            case Opcodes.MONITORENTER:
            case Opcodes.MONITOREXIT:
                return 10;
            case Opcodes.GETFIELD:
            case Opcodes.CHECKCAST:
            case Opcodes.INSTANCEOF:
            case Opcodes.ARRAYLENGTH:
            case Opcodes.NEWARRAY:
            case Opcodes.ANEWARRAY:
                return 11;
            case Opcodes.PUTFIELD:
            case Opcodes.IF_ICMPEQ: case Opcodes.IF_ICMPNE: case Opcodes.IF_ICMPLT:
            case Opcodes.IF_ICMPGE: case Opcodes.IF_ICMPGT: case Opcodes.IF_ICMPLE:
            case Opcodes.IF_ACMPEQ: case Opcodes.IF_ACMPNE:
                return 20;
            case Opcodes.IFEQ: case Opcodes.IFNE: case Opcodes.IFLT:
            case Opcodes.IFGE: case Opcodes.IFGT: case Opcodes.IFLE:
            case Opcodes.IFNULL: case Opcodes.IFNONNULL:
            case Opcodes.TABLESWITCH: case Opcodes.LOOKUPSWITCH:
                return 10;
            default:
                break;
        }
        // 算术 / 移位 / 比较：弹 2 压 1
        if (op >= Opcodes.IADD && op <= Opcodes.DREM) return 21;
        if (op >= Opcodes.ISHL && op <= Opcodes.LXOR) return 21;
        if (op >= Opcodes.LCMP && op <= Opcodes.DCMPG) return 21;
        // 取负 / 类型转换：弹 1 压 1
        if (op >= Opcodes.INEG && op <= Opcodes.DNEG) return 11;
        if (op >= Opcodes.I2L && op <= Opcodes.I2S) return 11;
        return -1;                                      // JSR/RET/DUP2*/DUP_X2 等：未建模
    }

    /**
     * **真正的**控制流汇合点：跳转目标、switch 目标、方法首指令。
     *
     * <p>只有这些 Label 才需要丢操作数栈 —— 汇合点上的栈形状取决于走哪条路。
     *
     * <p>⚠️ <b>try-catch 的 {@code start}/{@code end} 不算汇合点</b>（它们只是区间标记，
     * 没有任何跳转落在上面）。这一条曾经写错，代价极大：enjarify 会把 dex 的**每个**
     * try 区间翻译成一个 try-catch 块（实测 {@code Djuu.playerContent} 一个方法 29 个），
     * 于是「每条指令前都有一个汇合点 Label」→ 追踪器每步清栈 →
     * {@code new X; astore N; aload N; invokespecial} 这种 4 条指令的窗口都撑不过去，
     * 修复实际是 no-op。定位工具：{@code TrackProbe}。
     */
    private static Set<AbstractInsnNode> mergeLabels(MethodNode m) {
        Set<AbstractInsnNode> out = new HashSet<>();
        if (m.instructions != null && m.instructions.size() > 0) {
            out.add(m.instructions.getFirst());
        }
        for (AbstractInsnNode insn : m.instructions.toArray()) {
            if (insn instanceof JumpInsnNode) {
                out.add(((JumpInsnNode) insn).label);
            } else if (insn instanceof TableSwitchInsnNode) {
                TableSwitchInsnNode t = (TableSwitchInsnNode) insn;
                out.add(t.dflt);
                out.addAll(t.labels);
            } else if (insn instanceof LookupSwitchInsnNode) {
                LookupSwitchInsnNode t = (LookupSwitchInsnNode) insn;
                out.add(t.dflt);
                out.addAll(t.labels);
            }
        }
        return out;
    }

    /**
     * 异常处理器入口 Label。进入这里时操作数栈被重置为**恰好一个**异常对象
     * （与正常路径汇合时栈形状不同，所以单独处理，不能简单清空）。
     */
    private static Set<AbstractInsnNode> handlerLabels(MethodNode m) {
        Set<AbstractInsnNode> out = new HashSet<>();
        if (m.tryCatchBlocks != null) {
            for (TryCatchBlockNode t : m.tryCatchBlocks) {
                if (t.handler != null) out.add(t.handler);
            }
        }
        return out;
    }

    // ---- ASM：invoke-super owner 修正 ----------------------------------------

    /**
     * 修正 enjarify 对 dex {@code invoke-super} 的错误翻译。
     *
     * <p><b>症状</b>（2026-10-05，12 个站点 {@code create} 直接失败）：
     *
     * <pre>
     * java.lang.StackOverflowError
     *     at com.github.catvod.spider.Pan.init(Unknown Source)   ← 自己调自己
     *     ...
     * </pre>
     *
     * 宿主侧只看到 {@code 加载 jar 失败: null} —— 因为 {@code StackOverflowError}
     * 的 {@code getMessage()} 就是 null，而 {@code Pan.init} 的 try/catch 只捕
     * {@code java.lang.Exception}（{@code Error} 不是 {@code Exception}），
     * 所以它一路冒到 {@code SpiderBridge.create}。查这类「message 为 null 的失败」
     * 必须先拿到 remote stack（见 spider_runtime_factory.dart 的同名注释）。
     *
     * <p><b>成因</b>：dex 的 {@code invoke-super} 语义是「从**直接父类**开始解析」，
     * JVM 上的对应写法是 {@code invokespecial <直接父类>.<m>}。enjarify 却**原样照抄
     * dex method_id 里的 class**：当 R8 把该 method_id 的 class 写成**当前类**时，
     * 产物就是
     *
     * <pre>
     * invokespecial &lt;当前类&gt;.&lt;m&gt;      // Pan.init → invokespecial Pan.init
     * </pre>
     *
     * JVM 解析时先在当前类命中 m（本类确实声明了它），于是变成无限自递归。
     * 实测这是 **enjarify 自身的语义缺陷**，不是本管线引入的 —— 裸 enjarify 产物
     * （未过我们任何一道工序）字节码一模一样。
     *
     * <p><b>判据</b>（只用 class 文件即可判定，不需要 dex）：dex 规定
     * {@code invoke-direct} **只能**用于 private 方法与构造器，所以
     * {@code invokespecial C0.m}（m != {@code <init>}，C0 == 当前类）只有三种可能：
     * <ul>
     *   <li>C0 声明了 m 且 m 是 private → {@code invoke-direct}，**正确**，不动；</li>
     *   <li>C0 声明了 m 且 m 不是 private → 只可能是 {@code invoke-super}，
     *       owner 应为 {@code C0.superName}，**改写**；</li>
     *   <li>C0 没声明 m → JVM 会沿父类链上溯找第一个声明，与 dex
     *       {@code invoke-super} 的解析结果一致，**无害**，不动。</li>
     * </ul>
     *
     * <p><b>为什么改写成「直接父类」是对的</b>：dex {@code invoke-super} 的定义就是
     * 「从直接父类开始解析」；而 JVM 的 ACC_SUPER 规则规定，当
     * {@code invokespecial} 的 owner 是当前类的父类时，解析从**直接父类**开始 ——
     * 两者等价。父类自己没声明 m 时，JVM 会继续上溯到祖父类，结果依然正确。
     *
     * <p><b>实测规模</b>：本 jar（spider.jar, md5 c1ed419a…）里
     * {@code invokespecial <当前类>.m} 共 4999 个调用点，其中 4998 个是私有方法调用
     * （正确），**只有 1 个错** —— {@code com.github.catvod.spider.Pan.init}。
     * 但 {@code Pan} 是所有网盘蜘蛛的基类（{@code AiPan}/{@code PanAli}/
     * {@code PanQuark}/{@code PanWebShare}/{@code Pan123}…），凡是 init 委派到
     * {@code Pan.init} 的类 **100%** StackOverflow —— 一处改动救回 12 个站点。
     */
    private void fixSuperCalls(File inJar, File outJar) throws IOException {
        Map<String, ClassNode> classes = new LinkedHashMap<>();
        try (JarFile jf = new JarFile(inJar)) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                if (!e.getName().endsWith(".class")) continue;
                byte[] bytes;
                try (InputStream is = jf.getInputStream(e)) {
                    bytes = readAll(is);
                }
                ClassNode cn = new ClassNode();
                new ClassReader(bytes).accept(cn, 0);
                classes.put(cn.name, cn);
            }
        }

        int fixed = 0;
        int touched = 0;
        List<String> samples = new ArrayList<>();
        for (ClassNode cn : classes.values()) {
            if (cn.superName == null) continue;
            int before = fixed;
            for (MethodNode m : cn.methods) {
                if (m.instructions == null) continue;
                for (AbstractInsnNode insn : m.instructions.toArray()) {
                    if (insn.getOpcode() != Opcodes.INVOKESPECIAL) continue;
                    MethodInsnNode mi = (MethodInsnNode) insn;
                    if (mi.name.equals("<init>")) continue;
                    if (!mi.owner.equals(cn.name)) continue;
                    MethodNode decl = declaredMethod(cn, mi.name, mi.desc);
                    if (decl == null) continue;                        // 未声明 → 无害
                    if ((decl.access & Opcodes.ACC_PRIVATE) != 0) continue;  // 私有 → 正确
                    mi.owner = cn.superName;
                    fixed++;
                    if (samples.size() < 5) {
                        samples.add(cn.name + "." + mi.name + " → " + cn.superName);
                    }
                }
            }
            if (fixed > before) touched++;
        }

        writeJar(inJar, outJar, classes);
        if (fixed > 0) {
            System.err.println("[jvm] invoke-super owner 修正 " + fixed
                + " 处（涉及 " + touched + " 个类）: "
                + String.join(", ", samples));
        }
    }

    /** 在类**自身**声明的方法里按 name+desc 查找（不含继承）。 */
    private static MethodNode declaredMethod(ClassNode cn, String name, String desc) {
        for (MethodNode m : cn.methods) {
            if (m.name.equals(name) && m.desc.equals(desc)) return m;
        }
        return null;
    }

    // ---- ASM：注解拷贝 --------------------------------------------------------

    /**
     * 把供体 jar（dex2jar 产物）里的**注解与泛型签名**拷到目标 jar（enjarify 产物）。
     *
     * enjarify 丢两类元数据，而这两类都会让蜘蛛在运行期炸掉：
     *
     * 1. **注解**：{@code @SerializedName} 决定 Gson 的 JSON 字段名。
     * 2. **泛型签名（Signature 属性）**：2026-10-04 才补上。enjarify 产出的类丢掉
     *    {@code Signature}，于是 {@code class c$a extends TypeToken} 变成**裸类型**。
     *    Gson 2.9 起 {@code TypeToken} 会做
     *    {@code getTypeTokenTypeArgument()} 校验，裸类型直接抛
     *    {@code IllegalStateException: TypeToken must be created with a type argument}，
     *    整条取数链失败。实测 {@code com.github.catvod.spider.Gulu} 就死在这里，
     *    而 dex2jar 的同一类**带着完整签名**（
     *    {@code TypeToken<LinkedHashMap<String,List<c.b>>>}）—— 拷回来即可，
     *    **不必降 Gson 版本**（2.8.9 才没有该校验，降到那儿是治标）。
     *
     * 按 name+desc 匹配类/字段/方法，源没有或目标已有则不覆盖。
     */
    private void copyAnnotations(File donorJar, File inJar, File outJar) throws IOException {
        Map<String, ClassNode> src = new HashMap<>();
        try (JarFile jf = new JarFile(donorJar)) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                if (!e.getName().endsWith(".class")) continue;
                byte[] b;
                try (InputStream is = jf.getInputStream(e)) {
                    b = readAll(is);
                }
                ClassNode cn = new ClassNode();
                try {
                    new ClassReader(b).accept(cn, 0);
                } catch (Exception ex) {
                    continue;
                }
                src.put(cn.name, cn);
            }
        }

        Map<String, ClassNode> dst = new LinkedHashMap<>();
        try (JarFile jf = new JarFile(inJar)) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                if (!e.getName().endsWith(".class")) continue;
                byte[] b;
                try (InputStream is = jf.getInputStream(e)) {
                    b = readAll(is);
                }
                ClassNode cn = new ClassNode();
                try {
                    new ClassReader(b).accept(cn, 0);
                } catch (Exception ex) {
                    continue;
                }
                ClassNode s = src.get(cn.name);
                if (s != null) {
                    if (s.visibleAnnotations != null && cn.visibleAnnotations == null) {
                        cn.visibleAnnotations = s.visibleAnnotations;
                    }
                    if (s.invisibleAnnotations != null && cn.invisibleAnnotations == null) {
                        cn.invisibleAnnotations = s.invisibleAnnotations;
                    }
                    // 泛型签名：enjarify 会丢，缺了 Gson 的 TypeToken 校验就炸（见方法注释）
                    if (s.signature != null && cn.signature == null) {
                        cn.signature = s.signature;
                    }
                    Map<String, FieldNode> srcFields = new HashMap<>();
                    for (FieldNode f : s.fields) srcFields.put(f.name + f.desc, f);
                    for (FieldNode f : cn.fields) {
                        FieldNode sf = srcFields.get(f.name + f.desc);
                        if (sf == null) continue;
                        if (sf.visibleAnnotations != null && f.visibleAnnotations == null) {
                            f.visibleAnnotations = sf.visibleAnnotations;
                        }
                        if (sf.invisibleAnnotations != null && f.invisibleAnnotations == null) {
                            f.invisibleAnnotations = sf.invisibleAnnotations;
                        }
                        if (sf.signature != null && f.signature == null) {
                            f.signature = sf.signature;
                        }
                    }
                    Map<String, MethodNode> srcMethods = new HashMap<>();
                    for (MethodNode m : s.methods) srcMethods.put(m.name + m.desc, m);
                    for (MethodNode m : cn.methods) {
                        MethodNode sm = srcMethods.get(m.name + m.desc);
                        if (sm == null) continue;
                        if (sm.visibleAnnotations != null && m.visibleAnnotations == null) {
                            m.visibleAnnotations = sm.visibleAnnotations;
                        }
                        if (sm.invisibleAnnotations != null && m.invisibleAnnotations == null) {
                            m.invisibleAnnotations = sm.invisibleAnnotations;
                        }
                        if (sm.signature != null && m.signature == null) {
                            m.signature = sm.signature;
                        }
                    }
                }
                dst.put(cn.name, cn);
            }
        }

        writeJar(inJar, outJar, dst);
    }

    // ---- 转换产物的合法性修补 ---------------------------------------------------

    /** Java 8 的 class 版本号。低于它的接口不允许 default / static / bridge 方法。 */
    private static final int V1_8 = Opcodes.V1_8;

    /**
     * 修补 enjarify 产物里两类**会被 JVM 直接拒掉**的问题。
     *
     * <p>两类都是「链接期」失败：类根本没被加载起来，蜘蛛一用到就整体取数失败，
     * 而且宿主看到的只有一句 {@code spider.xxx 执行失败: null}，真因藏在
     * {@code error.data.stack} 的 {@code Caused by} 里。所以修在转换环节最省事 ——
     * 后面所有蜘蛛都受益，也不用每个调用点去兜。
     *
     * <p><b>问题一：接口方法在 v49 下非法</b>（见 {@link #normalizeInterface}）。
     * 实测一个真实 {@code spider.jar}：<b>386 / 4023 个类</b>因此无法链接。
     *
     * <p><b>问题二：{@code maxLocals} / {@code maxStack} 写小了</b>。enjarify 对
     * 一批无参构造写成了 {@code maxLocals=0 maxStack=0}，而方法体其实是
     * {@code aload_0; invokespecial super.<init>()V; return}（3 条指令）。HotSpot
     * 的 class 文件解析器一看 {@code max_locals < 参数槽数} 就抛：
     *
     * <pre>
     * ClassFormatError: Arguments can't fit into locals in class file
     *   com/github/catvod/spider/merge/A0/rp
     * </pre>
     *
     * 实测 **52 个方法 / 52 个类**，全是 {@code <init>()V}，方法体都是好的。
     * 所以不用动字节码，**用 ASM 的 {@code COMPUTE_MAXS} 重算这两个计数**即可
     * （{@code COMPUTE_MAXS} 只看指令流，不需要类加载器，比 {@code COMPUTE_FRAMES} 安全得多）。
     */
    private void normalizeConvertedClasses(File inJar, File outJar) throws IOException {
        Map<String, ClassNode> dst = new LinkedHashMap<>();
        Set<String> computeMaxs = new LinkedHashSet<>();
        int ifaceFixed = 0;
        int ifaceSkipped = 0;
        int maxsFixed = 0;
        try (JarFile jf = new JarFile(inJar)) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                if (!e.getName().endsWith(".class")) continue;
                byte[] b;
                try (InputStream is = jf.getInputStream(e)) {
                    b = readAll(is);
                }
                ClassNode cn = new ClassNode();
                try {
                    new ClassReader(b).accept(cn, 0);
                } catch (Exception ex) {
                    continue; // 坏类留给后续环节，别在这里把整个转换搞挂
                }
                Boolean r = normalizeInterface(cn);
                if (r == null) {
                    ifaceSkipped++;
                } else if (r) {
                    ifaceFixed++;
                }
                if (needsMaxsRecompute(cn)) {
                    computeMaxs.add(cn.name);
                    maxsFixed++;
                }
                dst.put(cn.name, cn);
            }
        }
        writeJar(inJar, outJar, dst, computeMaxs);
        if (ifaceFixed > 0 || ifaceSkipped > 0 || maxsFixed > 0) {
            System.err.println("[jvm] 转换产物修补: 接口方法规范化 " + ifaceFixed
                + " 个类（跳过 " + ifaceSkipped + " 个带分支的）; maxStack/maxLocals 重算 "
                + maxsFixed + " 个类");
        }
    }

    /**
     * 规范化单个类里的接口方法。
     *
     * <p><b>症状</b>：enjarify 产出的类**大多是 major 49（Java 5）**。JVMS 规定
     * major &lt; 52 时接口方法必须是 {@code PUBLIC|ABSTRACT} —— 不允许 default
     * 方法、不允许 {@code ACC_BRIDGE}、不允许 {@code ACC_STATIC}。而 dex 里协变
     * 返回值的桥接方法会被原样翻成「带 Code 的 BRIDGE 方法」，于是 HotSpot 解析时抛：
     *
     * <pre>
     * ClassFormatError: Method getDefaultInstanceForType in class
     *   com/google/protobuf/MessageOrBuilder has illegal modifiers: 0x1041
     * </pre>
     *
     * <p><b>为什么影响面巨大</b>：这是**链接期**错误，而且报的是接口自己的名字。
     * 任何实现了该接口的类在被链接时都要先解析接口 → 全部一起失败（protobuf 全家
     * + quickjs 的 JSObject + catvod 的部分 merge 类）。
     *
     * <p><b>修法</b>：把这类接口的 class 版本提到 52，必要时给方法补
     * {@code ACC_PUBLIC}。**不删方法** —— 删掉会改变语义（可能有调用点），提版本不会：
     * 版本 ≥ 52 后带 Code 的接口方法就是合法的 default 方法，语义与 dex 一致。
     * （实测这 25 个方法**没有任何调用点**，所以两种修法都不会改变行为，但提版本更保守。）
     *
     * <p><b>前提</b>（必须满足，否则会改报 {@code Expecting a stackmap frame}）：
     * 版本 ≥ 50 的方法**只要有分支或异常表就必须带 StackMapTable**，而 enjarify 不产帧。
     * 所以只对「所有带 Code 的方法都无分支、无异常表」的接口提版本；不满足的类**原样
     * 放过**并记一行日志 —— 宁可保持现状，也不要引入新的验证错误。
     * 实测该前提在真实产物上成立：25 个非法方法全部无分支。
     *
     * @return {@code null} = 需要修但**不能**安全地修（含分支，提版本会缺 StackMapTable）；
     *         {@code true} = 已修改；{@code false} = 无需修改。
     */
    private static Boolean normalizeInterface(ClassNode cn) {
        if ((cn.access & Opcodes.ACC_INTERFACE) == 0) return false;

        boolean needsFix = false;
        boolean codeWithBranch = false;
        for (MethodNode m : cn.methods) {
            // `static abstract` 是自相矛盾的组合（静态方法必须有方法体），任何版本都非法。
            // 实测 `com/whl/quickjs/wrapper/JSObject.a` 就是这种「脱糖残留」：无 Code。
            // 修法是**摘掉 STATIC**（保留 ABSTRACT）—— 这是「没有方法体」最诚实的表达，
            // 不凭空造行为。若有 invokestatic 调用点，那它今天本来也因类加载失败而不可用。
            if ((m.access & Opcodes.ACC_STATIC) != 0
                    && (m.access & Opcodes.ACC_ABSTRACT) != 0) {
                m.access &= ~Opcodes.ACC_STATIC;
                needsFix = true;
                if ((m.access & (Opcodes.ACC_PUBLIC | Opcodes.ACC_PRIVATE)) == 0) {
                    m.access |= Opcodes.ACC_PUBLIC;
                }
            }
            if (!hasCode(m)) continue;
            if (cn.version >= V1_8) {
                // v52 下带 Code 的接口方法合法；只要保证是 public 或 private。
                if ((m.access & (Opcodes.ACC_PUBLIC | Opcodes.ACC_PRIVATE)) == 0) {
                    needsFix = true;
                }
                continue;
            }
            // v < 52：任何带 Code 的接口方法都非法
            needsFix = true;
            if (hasBranchOrHandler(m)) codeWithBranch = true;
        }
        if (!needsFix) return false;
        if (cn.version < V1_8 && codeWithBranch) return null;
        if (cn.version < V1_8) cn.version = V1_8;
        for (MethodNode m : cn.methods) {
            if (!hasCode(m)) continue;
            if ((m.access & (Opcodes.ACC_PUBLIC | Opcodes.ACC_PRIVATE)) == 0) {
                m.access |= Opcodes.ACC_PUBLIC;
            }
        }
        return true;
    }

    /**
     * 这个类有没有「计数写小了」的方法 —— 有就该用 {@code COMPUTE_MAXS} 重写。
     *
     * <p>判据：方法有真实指令，但 {@code maxLocals} 连参数槽都装不下
     * （→ {@code ClassFormatError: Arguments can't fit into locals}），
     * 或者 {@code maxStack} 为 0（连一条 {@code aload_0} 都放不下）。
     */
    private static boolean needsMaxsRecompute(ClassNode cn) {
        for (MethodNode m : cn.methods) {
            if (!hasCode(m)) continue;
            if (m.maxLocals < argSlots(m)) return true;
            if (m.maxStack < 1) return true;
        }
        return false;
    }

    /** 方法有没有真正的操作码（Label/LineNumber/Frame 这些伪节点不算）。 */
    private static boolean hasCode(MethodNode m) {
        if (m.instructions == null) return false;
        for (AbstractInsnNode insn : m.instructions) {
            if (insn.getOpcode() >= 0) return true;
        }
        return false;
    }

    /** 参数占用的局部变量槽数（long/double 占 2 槽；实例方法多一个 this）。 */
    private static int argSlots(MethodNode m) {
        int slots = (m.access & Opcodes.ACC_STATIC) != 0 ? 0 : 1;
        for (Type t : Type.getArgumentTypes(m.desc)) {
            slots += t.getSize();
        }
        return slots;
    }

    /** 方法体里有没有跳转指令或异常表 —— 决定 v≥52 时是否必须带 StackMapTable。 */
    private static boolean hasBranchOrHandler(MethodNode m) {
        if (m.tryCatchBlocks != null && !m.tryCatchBlocks.isEmpty()) return true;
        if (m.instructions == null) return false;
        for (AbstractInsnNode insn : m.instructions) {
            int op = insn.getOpcode();
            if (op >= Opcodes.IFEQ && op <= Opcodes.GOTO) return true;
            if (op >= Opcodes.TABLESWITCH && op <= Opcodes.LOOKUPSWITCH) return true;
        }
        return false;
    }

    // ---- 通用 jar 读写 ---------------------------------------------------------

    /** 从 jar 里提取单个 entry 到文件。 */
    private static void extractEntry(File jarFile, String name, File out) throws IOException {
        try (JarFile jf = new JarFile(jarFile)) {
            JarEntry e = jf.getJarEntry(name);
            if (e == null) throw new IOException("jar 中缺少 " + name);
            try (InputStream is = jf.getInputStream(e);
                    FileOutputStream fos = new FileOutputStream(out)) {
                byte[] buf = new byte[8192];
                int n;
                while ((n = is.read(buf)) > 0) fos.write(buf, 0, n);
            }
        }
    }

    /** 用给定 classes 重写 inJar，其余 entry 原样透传。ClassWriter 保留原帧。 */
    private static void writeJar(File inJar, File outJar, Map<String, ClassNode> classes)
            throws IOException {
        writeJar(inJar, outJar, classes, Collections.emptySet());
    }

    /**
     * 同上，但 {@code computeMaxs} 里的类用 {@code COMPUTE_MAXS} 重算
     * {@code maxStack} / {@code maxLocals}。
     *
     * <p>只对**确实写小了计数**的类用 —— {@code COMPUTE_MAXS} 会按指令流重算，
     * 对正常类没必要动（保留原值最不容易出意外）。它**不需要类加载器**
     * （{@code COMPUTE_FRAMES} 才需要），所以对这批 obfuscated 类也能用。
     */
    private static void writeJar(File inJar, File outJar, Map<String, ClassNode> classes,
            Set<String> computeMaxs) throws IOException {
        try (JarFile jf = new JarFile(inJar);
                JarOutputStream jos = new JarOutputStream(new FileOutputStream(outJar))) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                String name = e.getName();
                if (name.endsWith(".class")) {
                    ClassNode cn = classes.get(name.substring(0, name.length() - 6));
                    if (cn != null) {
                        ClassWriter cw = computeMaxs.contains(cn.name)
                                ? new ClassWriter(ClassWriter.COMPUTE_MAXS)
                                : new ClassWriter(0);
                        cn.accept(cw);
                        jos.putNextEntry(new JarEntry(name));
                        jos.write(cw.toByteArray());
                        jos.closeEntry();
                        continue;
                    }
                }
                byte[] data;
                try (InputStream is = jf.getInputStream(e)) {
                    data = readAll(is);
                }
                jos.putNextEntry(new JarEntry(name));
                jos.write(data);
                jos.closeEntry();
            }
        }
    }

    private static byte[] readAll(InputStream in) throws IOException {
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        return out.toByteArray();
    }

    /** 跑子进程并收集输出。 */
    private static String runSubprocess(List<String> cmd) throws IOException {
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.redirectErrorStream(true);
        Process proc = pb.start();
        StringBuilder sb = new StringBuilder();
        byte[] buf = new byte[8192];
        int n;
        try (InputStream is = proc.getInputStream()) {
            while ((n = is.read(buf)) > 0) {
                sb.append(new String(buf, 0, n, java.nio.charset.StandardCharsets.UTF_8));
            }
        }
        try {
            int code = proc.waitFor();
            if (code != 0) {
                throw new IOException("子进程退出码 " + code + ": " + sb.toString().trim());
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("子进程被中断", e);
        }
        return sb.toString();
    }

    /** 从 java.class.path 挑选 dex2jar 相关库。 */
    private String buildDex2jarClasspath() {
        StringBuilder sb = new StringBuilder();
        String cp = System.getProperty("java.class.path", "");
        for (String entry : cp.split(java.io.File.pathSeparator)) {
            if (entry.isEmpty()) continue;
            String name = new File(entry).getName();
            if (isDex2jarLib(name) || isThirdPartyLib(name)) {
                if (sb.length() > 0) sb.append(java.io.File.pathSeparator);
                sb.append(entry);
            }
        }
        return sb.toString();
    }

    private static boolean isDex2jarLib(String name) {
        if (!name.endsWith(".jar")) return false;
        return name.startsWith("dex-")
            || name.startsWith("d2j-")
            || name.equals("antlr-3.5.2.jar")
            || name.equals("antlr-runtime-3.5.2.jar")
            || name.equals("antlr4-4.9.3.jar")
            || name.equals("antlr4-runtime-4.9.3.jar")
            || name.equals("asm-9.5.jar")
            || name.equals("asm-analysis-9.5.jar")
            || name.equals("asm-commons-9.5.jar")
            || name.equals("asm-tree-9.5.jar")
            || name.equals("asm-util-9.5.jar")
            || name.equals("dx-30.0.2.jar")
            || name.equals("icu4j-69.1.jar")
            || name.equals("javax.json-1.0.4.jar")
            || name.equals("org.abego.treelayout.core-1.0.3.jar")
            || name.equals("ST4-4.3.1.jar");
    }

    private static boolean isThirdPartyLib(String name) {
        if (!name.endsWith(".jar")) return false;
        return name.startsWith("okhttp")
            || name.startsWith("okio")
            || name.startsWith("json-")
            || name.startsWith("gson-")
            || name.startsWith("zxing")
            || name.startsWith("slf4j")
            || name.startsWith("kotlin-")
            || name.startsWith("annotations-");
    }

    private static void deleteQuietly(File f) {
        if (f == null || !f.exists()) return;
        if (f.isDirectory()) {
            try (var stream = Files.walk(f.toPath())) {
                stream.sorted(Comparator.reverseOrder()).forEach(p -> {
                    try {
                        Files.deleteIfExists(p);
                    } catch (IOException ignored) {
                    }
                });
            } catch (IOException ignored) {
            }
        } else {
            f.delete();
        }
    }
}