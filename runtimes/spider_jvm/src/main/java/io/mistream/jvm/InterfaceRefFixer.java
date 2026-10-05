package io.mistream.jvm;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.AbstractInsnNode;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.MethodInsnNode;
import org.objectweb.asm.tree.MethodNode;

/**
 * 修 constant pool 里「接口方法被当成类方法引用」的问题。
 *
 * <h3>症状</h3>
 * <pre>
 * java.lang.IncompatibleClassChangeError: Method 'java.util.Comparator
 *     java.util.Comparator.comparingInt(java.util.function.ToIntFunction)'
 *     must be InterfaceMethodref constant
 *     at com.github.catvod.spider.merge.A0.ps.i
 * </pre>
 * 取数链直接断掉（实测 {@code csp_Djuu} 的 home/category/search 全挂在这里）。
 *
 * <h3>成因</h3>
 * dex 的 {@code invoke-static} / {@code invoke-direct} / {@code invoke-virtual}
 * **不区分**目标是类还是接口 —— 那是由目标 {@code class_def} 的 access_flags 决定的。
 * enjarify 只对 dex 的 {@code invoke-interface} 置 {@code itf=true}，其余一律
 * {@code itf=false}。于是当 {@code invoke-static} 的目标其实是**接口的静态方法**
 * （{@code Comparator.comparingInt} / {@code Comparator.reverseOrder} /
 * {@code Map.Entry.comparingByKey} …）时，产物里就是 {@code Methodref}，JVM 解析时
 * 发现 owner 是接口，抛 {@code IncompatibleClassChangeError}。
 *
 * <p>目标不在 dex 里（JDK / 依赖库）时 enjarify **无从判断**，所以这类错必然出现。
 * 实测本 jar 集中在 {@code merge/A0/ps}（R8 把 Jackson/JsonPath 里那些
 * {@code Comparator} 辅助方法都合并到了这个类）。
 *
 * <h3>判据</h3>
 * 目标到底是不是 interface：先查 jar 自身的 {@code ACC_INTERFACE}（不必加载，
 * 避开「加载即校验」的连锁失败），查不到再反射查 JDK / 依赖库。
 *
 * <h3>修法</h3>
 * <ul>
 *   <li>{@code invokeinterface} → {@code itf} 恒为 true；</li>
 *   <li>{@code invokevirtual} 但 owner 是接口 → 改成 {@code invokeinterface}；
 *       （dex 正常不会这么编，但改了才是合法字节码）</li>
 *   <li>{@code invokestatic} / {@code invokespecial} → {@code itf} 跟 owner 的
 *       「是不是接口」一致。Java 8+ 允许 {@code invokestatic}/{@code invokespecial}
 *       引用 InterfaceMethodref（接口静态方法 / default / private 方法）。</li>
 * </ul>
 *
 * <h3>⚠️ 光改 itf 还不够：必须同时把类文件版本提到 52</h3>
 * enjarify 产出的类是 **major 49（Java 5）**。JVMS §4.4.2 规定
 * InterfaceMethodref 只有 {@code invokeinterface} 能引用；用
 * {@code invokestatic}/{@code invokespecial} 引用它**要求类文件版本 ≥ 52**。
 * 实测（{@code IfaceStaticProbe}）在 49 的类里把 itf 改成 true，JVM 报
 * <pre>
 * VerifyError: (class: .../ps, method: h) Illegal type in constant pool
 * </pre>
 * 所以对这些类要**同时**把 {@code version} 提到 52。而版本 ≥ 50 又要求
 * StackMapTable，因此这些类必须用 {@code COMPUTE_FRAMES} 重新写一遍
 * （见 {@link #frameWriter}）。
 *
 * <p>为什么敢用 {@code COMPUTE_FRAMES}：只对**真正需要升级的那几个类**用（实测本 jar
 * 只有 6 个），而且 {@code getCommonSuperClass} 换成「先查 jar 自身继承信息、再反射」，
 * 不依赖把整个 jar 塞进 ClassLoader。这是本项目唯一使用 {@code COMPUTE_FRAMES} 的地方 ——
 * 别的地方仍然坚持 {@code COMPUTE_MAXS} 或原样保留。
 */
public final class InterfaceRefFixer {

    private InterfaceRefFixer() {
    }

    /** 一次扫描的结果。 */
    public static final class Report {
        /** 残留（或「本可修」）的问题描述，一行一处。 */
        public final List<String> problems = new ArrayList<>();
        /** 修好了多少处（audit 模式恒为 0）。 */
        public int fixed;
        /** 因为要引用 InterfaceMethodref 而被迫升到 major 52 的类。 */
        public final List<String> upgraded = new ArrayList<>();

        public boolean isClean() {
            return problems.isEmpty();
        }
    }

    /**
     * 只读自检：报告 jar 里 {@code itf} 标记与 owner 实际种类不符的调用点。
     *
     * @param classpath 依赖 jar（用来反射判定 okhttp/gson 之类库接口）；可为空
     */
    public static Report audit(File jar, List<File> classpath) throws IOException {
        return run(jar, null, classpath);
    }

    /**
     * 就地修：把 {@code itf} 标记改对（必要时升级类文件版本 + 重算帧）。
     */
    public static Report fix(File inJar, File outJar, List<File> classpath) throws IOException {
        return run(inJar, outJar, classpath);
    }

    private static Report run(File inJar, File outJar, List<File> classpath)
            throws IOException {
        Map<String, ClassNode> classes = new LinkedHashMap<>();
        try (JarFile jf = new JarFile(inJar)) {
            Enumeration<JarEntry> en = jf.entries();
            while (en.hasMoreElements()) {
                JarEntry e = en.nextElement();
                if (!e.getName().endsWith(".class")) continue;
                byte[] b;
                try (InputStream is = jf.getInputStream(e)) {
                    b = is.readAllBytes();
                }
                ClassNode cn = new ClassNode();
                try {
                    new ClassReader(b).accept(cn, 0);
                } catch (Throwable t) {
                    continue;
                }
                classes.put(cn.name, cn);
            }
        }

        // jar 自身的 interface 标记：直接读 access_flags，不加载类
        Map<String, Boolean> selfIface = new HashMap<>();
        for (ClassNode cn : classes.values()) {
            selfIface.put(cn.name, (cn.access & Opcodes.ACC_INTERFACE) != 0);
        }
        ClassLoader loader = buildLoader(classpath);

        Report rep = new Report();
        java.util.Set<String> needUpgrade = new java.util.HashSet<>();
        for (ClassNode cn : classes.values()) {
            for (MethodNode m : cn.methods) {
                if (m.instructions == null) continue;
                for (AbstractInsnNode insn : m.instructions.toArray()) {
                    if (!(insn instanceof MethodInsnNode)) continue;
                    MethodInsnNode mi = (MethodInsnNode) insn;
                    Boolean ownerIsIface = resolve(selfIface, mi.owner, loader);
                    if (ownerIsIface == null) continue;      // 查不到 → 不猜，不动
                    boolean wantItf = ownerIsIface;
                    int op = mi.getOpcode();
                    if (op == Opcodes.INVOKEINTERFACE) {
                        // invokeinterface 要求 owner 是接口。owner 是类的话属于
                        // 「类/接口定义不对」（见 InterfaceMismatchScan），不硬改。
                        if (!wantItf) {
                            rep.problems.add(describe(cn, m, mi)
                                + "  [invokeinterface 但 owner 是类，需查定义]");
                        }
                        continue;
                    }
                    if (op == Opcodes.INVOKEVIRTUAL && wantItf) {
                        // invokevirtual 打在接口上 → 必须换成 invokeinterface
                        if (outJar != null) mi.setOpcode(Opcodes.INVOKEINTERFACE);
                        mi.itf = true;
                        rep.fixed++;
                        rep.problems.add(describe(cn, m, mi)
                            + "  [invokevirtual→invokeinterface]");
                        continue;
                    }
                    if (mi.itf != wantItf) {
                        if (outJar != null) mi.itf = wantItf;
                        rep.fixed++;
                        rep.problems.add(describe(cn, m, mi)
                            + "  itf " + mi.itf + "→" + wantItf);
                        // 用 InterfaceMethodref 引接口静态/default 方法 → 类文件必须 ≥ 52
                        if (wantItf) needUpgrade.add(cn.name);
                    }
                }
            }
        }

        if (outJar != null) {
            for (String n : needUpgrade) {
                ClassNode cn = classes.get(n);
                if (cn == null || cn.version >= Opcodes.V1_8) continue;
                cn.version = Opcodes.V1_8;
                rep.upgraded.add(n);
            }
            try (JarFile jf = new JarFile(inJar);
                    java.util.jar.JarOutputStream jos =
                        new java.util.jar.JarOutputStream(new java.io.FileOutputStream(outJar))) {
                Enumeration<JarEntry> en = jf.entries();
                while (en.hasMoreElements()) {
                    JarEntry e = en.nextElement();
                    String name = e.getName();
                    ClassNode cn = name.endsWith(".class")
                        ? classes.get(name.substring(0, name.length() - 6)) : null;
                    byte[] data;
                    if (cn != null) {
                        data = writeClass(cn, needUpgrade.contains(cn.name), classes, loader);
                    } else {
                        try (InputStream is = jf.getInputStream(e)) {
                            data = is.readAllBytes();
                        }
                    }
                    jos.putNextEntry(new JarEntry(name));
                    jos.write(data);
                    jos.closeEntry();
                }
            }
        }
        return rep;
    }

    /**
     * 写一个类：升级过的用 {@code COMPUTE_FRAMES}（版本 ≥ 50 必须有 StackMapTable），
     * 其余原样重写（{@code ClassWriter(0)} 保留原帧）。
     */
    private static byte[] writeClass(ClassNode cn, boolean upgraded,
            Map<String, ClassNode> classes, ClassLoader loader) {
        if (!upgraded) {
            ClassWriter cw = new ClassWriter(0);
            cn.accept(cw);
            return cw.toByteArray();
        }
        ClassWriter cw = frameWriter(classes, loader);
        cn.accept(cw);
        return cw.toByteArray();
    }

    /**
     * {@code COMPUTE_FRAMES} 的 ClassWriter，但 {@code getCommonSuperClass} 先查
     * jar 自身的继承信息 —— ASM 默认实现靠 {@code Class.forName}，而转换产物**不在**
     * 加载器上，直接用它必然 {@code TypeNotPresentException}。
     */
    private static ClassWriter frameWriter(Map<String, ClassNode> classes, ClassLoader loader) {
        return new ClassWriter(ClassWriter.COMPUTE_FRAMES) {
            @Override
            protected String getCommonSuperClass(String t1, String t2) {
                if (t1.equals(t2)) return t1;
                java.util.List<String> chain = new ArrayList<>();
                for (String c = t1; c != null; c = superOf(c, classes, loader)) {
                    chain.add(c);
                    if (c.equals("java/lang/Object")) break;
                }
                for (String c = t2; c != null; c = superOf(c, classes, loader)) {
                    if (chain.contains(c)) return c;
                    if (c.equals("java/lang/Object")) return "java/lang/Object";
                }
                return "java/lang/Object";
            }
        };
    }

    /** 取父类名：先查 jar 自身，再反射；接口/Object 返回 null。 */
    private static String superOf(String name, Map<String, ClassNode> classes, ClassLoader loader) {
        ClassNode cn = classes.get(name);
        if (cn != null) {
            return (cn.access & Opcodes.ACC_INTERFACE) != 0 ? null : cn.superName;
        }
        try {
            Class<?> c = Class.forName(name.replace('/', '.'), false, loader);
            if (c.isInterface() || c.getSuperclass() == null) return null;
            return c.getSuperclass().getName().replace('.', '/');
        } catch (Throwable t) {
            return null;
        }
    }

    private static String describe(ClassNode cn, MethodNode m, MethodInsnNode mi) {
        return cn.name + "." + m.name + m.desc + "  " + mi.owner + "." + mi.name + mi.desc;
    }

    /** owner 是不是接口；查不到返回 null（不猜）。 */
    private static Boolean resolve(Map<String, Boolean> selfIface, String owner,
            ClassLoader loader) {
        Boolean inJar = selfIface.get(owner);
        if (inJar != null) return inJar;
        try {
            Class<?> c = Class.forName(owner.replace('/', '.'), false, loader);
            return c.isInterface();
        } catch (Throwable t) {
            return null;
        }
    }

    private static ClassLoader buildLoader(List<File> classpath) {
        if (classpath == null || classpath.isEmpty()) {
            return InterfaceRefFixer.class.getClassLoader();
        }
        List<URL> urls = new ArrayList<>();
        for (File f : classpath) {
            try {
                urls.add(f.toURI().toURL());
            } catch (Exception ignored) {
            }
        }
        return new URLClassLoader(urls.toArray(new URL[0]),
                InterfaceRefFixer.class.getClassLoader());
    }
}
