package io.mistream.jvm;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.util.ArrayList;
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
import org.objectweb.asm.tree.LabelNode;
import org.objectweb.asm.tree.MethodInsnNode;
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
    private static final String CACHE_PREFIX = "converted-v2-";

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
     * → 修 init owner → 从 dex2jar 拷贝注解 → 缓存。
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
        File tmp = new File(cacheDir, CACHE_PREFIX + digest + ".tmp");
        File tmpStubbed = new File(cacheDir, CACHE_PREFIX + digest + ".tmp2");
        try {
            extractEntry(dexJar, DEX_ENTRY, classesDex);
            runEnjarify(classesDex, enjarifyRaw);
            runDex2jar(dexJar, dex2jarRaw);
            // 修 init owner 后再拷贝注解（注解来自 dex2jar 产物，其注解与 fix 前一致）
            fixInitOwner(enjarifyRaw, enjarifyFixed);
            copyAnnotations(dex2jarRaw, enjarifyFixed, tmp);
            // R8 合并类残留引用：为缺失类合成 stub（见 addMissingStubs 注释）
            addMissingStubs(tmp, tmpStubbed);
            if (!tmpStubbed.renameTo(out)) {
                Files.move(tmpStubbed.toPath(), out.toPath(), StandardCopyOption.REPLACE_EXISTING);
            }
            return out;
        } finally {
            deleteQuietly(work);
            deleteQuietly(tmp);
            deleteQuietly(tmpStubbed);
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

    /** 一个 `new X; invokespecial Y.<init>` 且 Y != X 的调用点。 */
    private static final class InitCallSite {
        final String newCls;
        final String initOwner;
        final String desc;

        InitCallSite(String n, String o, String d) {
            newCls = n;
            initOwner = o;
            desc = d;
        }
    }

    /**
     * 修 enjarify 产物里的 init owner 不匹配。
     *
     * DEX 里 R8 把平凡构造器内联成 `new-instance X; invoke-direct Object.<init>()V`，
     * enjarify 原样转出 `new X; invokespecial Object.<init>()V`，JVM 严格验证拒绝
     * （"Call to wrong initialization method"）。仅当 initOwner 是 Object 或 X 的
     * 直接父类时改写为 X.<init>，并合成缺失的 <init>。其余"无关"调用点保留
     * （qist 蜘蛛烟测通过，不代表其他蜘蛛，见 B2 记录）。
     */
    private void fixInitOwner(File inJar, File outJar) throws IOException {
        Map<String, ClassNode> classes = new LinkedHashMap<>();
        List<InitCallSite> sites = new ArrayList<>();
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
                scanInitMis(cn, sites);
            }
        }

        // 只改写 initOwner == Object 或 initOwner == X.superName 的调用点
        Map<String, Set<String>> needsCtor = new HashMap<>();
        List<InitCallSite> fixable = new ArrayList<>();
        for (InitCallSite s : sites) {
            ClassNode x = classes.get(s.newCls);
            String superName = x != null ? x.superName : "java/lang/Object";
            if (s.initOwner.equals("java/lang/Object") || s.initOwner.equals(superName)) {
                fixable.add(s);
                needsCtor.computeIfAbsent(s.newCls, k -> new LinkedHashSet<>()).add(s.desc);
            }
        }

        // 合成缺失的 <init>(desc)，委托给 Object.<init>(desc)
        for (Map.Entry<String, Set<String>> me : needsCtor.entrySet()) {
            ClassNode cn = classes.get(me.getKey());
            if (cn == null) continue;
            for (String desc : me.getValue()) {
                boolean has = false;
                for (MethodNode mn : cn.methods) {
                    if (mn.name.equals("<init>") && mn.desc.equals(desc)) {
                        has = true;
                        break;
                    }
                }
                if (has) continue;
                MethodNode mn = new MethodNode(Opcodes.ACC_PUBLIC, "<init>", desc, null, null);
                mn.instructions.add(new VarInsnNode(Opcodes.ALOAD, 0));
                for (Type t : Type.getArgumentTypes(desc)) {
                    mn.instructions.add(loadDefault(t));
                }
                mn.instructions.add(new MethodInsnNode(
                    Opcodes.INVOKESPECIAL, "java/lang/Object", "<init>", desc, false));
                mn.instructions.add(new InsnNode(Opcodes.RETURN));
                cn.methods.add(mn);
            }
        }

        // 改写可修调用点：new 出来的对象其 <init> owner 换成 newCls
        for (InitCallSite s : fixable) {
            ClassNode owner = classes.get(s.newCls);
            if (owner == null) continue;
            for (MethodNode m : owner.methods) {
                if (m.instructions == null) continue;
                Map<Integer, String> slot2new = new HashMap<>();
                String pending = null;
                for (AbstractInsnNode insn : m.instructions.toArray()) {
                    int op = insn.getOpcode();
                    if (insn instanceof LabelNode) {
                        slot2new.clear();
                        pending = null;
                    } else if (op == Opcodes.NEW) {
                        pending = ((TypeInsnNode) insn).desc;
                    } else if (isStore(op)) {
                        VarInsnNode v = (VarInsnNode) insn;
                        if (pending != null) {
                            slot2new.put(v.var, pending);
                            pending = null;
                        } else {
                            slot2new.remove(v.var);
                        }
                    } else if (op == Opcodes.INVOKESPECIAL) {
                        MethodInsnNode mi = (MethodInsnNode) insn;
                        if (!mi.name.equals("<init>")) {
                            pending = null;
                            continue;
                        }
                        AbstractInsnNode cur = insn.getPrevious();
                        Integer slot = null;
                        if (cur != null && cur.getOpcode() == Opcodes.ALOAD) {
                            slot = ((VarInsnNode) cur).var;
                        }
                        if (slot != null && s.newCls.equals(slot2new.get(slot))
                                && s.initOwner.equals(mi.owner) && s.desc.equals(mi.desc)) {
                            mi.owner = s.newCls;
                        }
                        pending = null;
                    } else if (op != Opcodes.DUP && op != Opcodes.SWAP && op != Opcodes.POP) {
                        pending = null;
                    }
                }
            }
        }

        writeJar(inJar, outJar, classes);
    }

    /** 扫描一个类里的 `new X; ... invokespecial Y.<init>`（Y != X）调用点。 */
    private static void scanInitMis(ClassNode cn, List<InitCallSite> sites) {
        for (MethodNode m : cn.methods) {
            if (m.instructions == null) continue;
            Map<Integer, String> slot2new = new HashMap<>();
            String pending = null;
            for (AbstractInsnNode insn : m.instructions.toArray()) {
                int op = insn.getOpcode();
                if (insn instanceof LabelNode) {
                    slot2new.clear();
                    pending = null;
                } else if (op == Opcodes.NEW) {
                    pending = ((TypeInsnNode) insn).desc;
                } else if (isStore(op)) {
                    VarInsnNode v = (VarInsnNode) insn;
                    if (pending != null) {
                        slot2new.put(v.var, pending);
                        pending = null;
                    } else {
                        slot2new.remove(v.var);
                    }
                } else if (op == Opcodes.INVOKESPECIAL) {
                    MethodInsnNode mi = (MethodInsnNode) insn;
                    if (!mi.name.equals("<init>")) {
                        pending = null;
                        continue;
                    }
                    AbstractInsnNode cur = insn.getPrevious();
                    Integer slot = null;
                    if (cur != null && cur.getOpcode() == Opcodes.ALOAD) {
                        slot = ((VarInsnNode) cur).var;
                    }
                    if (slot != null && slot2new.containsKey(slot)
                            && !mi.owner.equals(slot2new.get(slot))) {
                        sites.add(new InitCallSite(slot2new.get(slot), mi.owner, mi.desc));
                    }
                    pending = null;
                } else if (op != Opcodes.DUP && op != Opcodes.SWAP && op != Opcodes.POP) {
                    pending = null;
                }
            }
        }
    }

    private static boolean isStore(int op) {
        return (op >= Opcodes.ISTORE && op <= Opcodes.ASTORE)      // 54..58
            || (op >= 59 && op <= 78);                              // ISTORE_0..ASTORE_3
    }

    private static AbstractInsnNode loadDefault(Type t) {
        switch (t.getSort()) {
            case Type.BOOLEAN:
            case Type.BYTE:
            case Type.SHORT:
            case Type.CHAR:
            case Type.INT:
                return new InsnNode(Opcodes.ICONST_0);
            case Type.FLOAT:
                return new InsnNode(Opcodes.FCONST_0);
            case Type.LONG:
                return new InsnNode(Opcodes.LCONST_0);
            case Type.DOUBLE:
                return new InsnNode(Opcodes.DCONST_0);
            default:
                return new InsnNode(Opcodes.ACONST_NULL);
        }
    }

    // ---- ASM：注解拷贝 --------------------------------------------------------

    /**
     * 把供体 jar（dex2jar 产物）里的注解拷到目标 jar（enjarify 产物）。
     * enjarify 丢弃全部注解，而 @SerializedName 决定 Gson 的 JSON 字段名。
     * 按 name+desc 匹配类/字段/方法，源没有则不覆盖。
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
                    Map<String, FieldNode> srcFields = new HashMap<>();
                    for (FieldNode f : s.fields) srcFields.put(f.name + f.desc, f);
                    for (FieldNode f : cn.fields) {
                        FieldNode sf = srcFields.get(f.name + f.desc);
                        if (sf != null && sf.visibleAnnotations != null
                                && f.visibleAnnotations == null) {
                            f.visibleAnnotations = sf.visibleAnnotations;
                        }
                        if (sf != null && sf.invisibleAnnotations != null
                                && f.invisibleAnnotations == null) {
                            f.invisibleAnnotations = sf.invisibleAnnotations;
                        }
                    }
                    Map<String, MethodNode> srcMethods = new HashMap<>();
                    for (MethodNode m : s.methods) srcMethods.put(m.name + m.desc, m);
                    for (MethodNode m : cn.methods) {
                        MethodNode sm = srcMethods.get(m.name + m.desc);
                        if (sm != null && sm.visibleAnnotations != null
                                && m.visibleAnnotations == null) {
                            m.visibleAnnotations = sm.visibleAnnotations;
                        }
                        if (sm != null && sm.invisibleAnnotations != null
                                && m.invisibleAnnotations == null) {
                            m.invisibleAnnotations = sm.invisibleAnnotations;
                        }
                    }
                }
                dst.put(cn.name, cn);
            }
        }

        writeJar(inJar, outJar, dst);
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
        try (JarFile jf = new JarFile(inJar);
                JarOutputStream jos = new JarOutputStream(new FileOutputStream(outJar))) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                String name = e.getName();
                if (name.endsWith(".class")) {
                    ClassNode cn = classes.get(name.substring(0, name.length() - 6));
                    if (cn != null) {
                        ClassWriter cw = new ClassWriter(0);
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