package io.mistream.jvm;

import android.app.Application;
import android.content.Context;

import com.github.catvod.crawler.Spider;
import com.github.catvod.crawler.SpiderApi;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 反射桥：加载 csp_ 类并调用其 Spider 方法。
 *
 * 真实 jar 里的 csp_ 类继承 com.github.catvod.crawler.Spider（由本运行时提供），
 * 方法返回 JSON 字符串。桥负责：
 * - 用 JarLoader 拿到的 ClassLoader 加载指定类并实例化
 * - 完成 jar 自带 com.github.catvod.spider.Init 的宿主初始化
 *   （注入 Application + 补默认 /config.json）
 * - 调用 init(Context, String) 或 init(Context)
 * - 按名字+参数形态分发 homeContent / categoryContent / detailContent /
 *   searchContent / playerContent / action 等
 *
 * 反射调用失败统一抛 {@link SpiderInvocationException}，由主循环转成
 * JSON-RPC error。
 */
public final class SpiderBridge {

    /** jar 自带的宿主工具类（TVBox 侧 API，蜘蛛大量依赖）。 */
    private static final String INIT_CLASS = "com.github.catvod.spider.Init";

    private final JarLoader jarLoader;
    private final Application context;

    /** 已经补写过默认 config.json 的 jar 路径（同 jar 只写一次）。 */
    private final java.util.Set<String> bootstrapped =
        java.util.concurrent.ConcurrentHashMap.newKeySet();

    SpiderBridge(JarLoader jarLoader, Application context) {
        this.jarLoader = jarLoader;
        this.context = context;
    }

    /**
     * 创建一个蜘蛛实例。
     *
     * @param jarPath   jar 路径（dex 或 java）
     * @param className csp_ 类全名（如 com.github.catvod.spider.App3Q）
     * @param extend    init(Context, String) 的第二个参数（ext 配置）
     * @return 实例
     */
    Instance create(String jarPath, String className, String extend)
            throws Exception {
        ClassLoader loader = jarLoader.loadJar(jarPath);
        initHost(loader, jarPath);
        Class<?> clazz = Class.forName(className, true, loader);
        Object spider = clazz.getDeclaredConstructor().newInstance();

        // 优先 init(Context, String)，回退 init(Context)
        Method init2 = findMethod(clazz, "init", Context.class, String.class);
        if (init2 != null) {
            init2.invoke(spider, context, extend == null ? "" : extend);
        } else {
            Method init1 = findMethod(clazz, "init", Context.class);
            if (init1 != null) {
                init1.invoke(spider, context);
            }
        }
        // 注入 SpiderApi 句柄（TVBox 宿主行为；部分蜘蛛在 initApi 里读端口/地址）
        Method initApi = findMethod(clazz, "initApi", SpiderApi.class);
        if (initApi != null) {
            initApi.invoke(spider, new SpiderApi());
        }
        return new Instance(spider);
    }

    /**
     * 完成 jar 自带的 {@code com.github.catvod.spider.Init} 需要的宿主初始化。
     *
     * <p>背景：这个 jar 是「胖 jar」，除了 csp_ 蜘蛛还打包了 TVBox 宿主侧的
     * {@code Init} 工具类（{@code Init.context()} / {@code get()} / {@code saveConfig()} 等）。
     * 蜘蛛取数时会走它，所以必须由宿主把两件事做掉：
     * <ol>
     *   <li>{@code Init.c}（private android.app.Application）要非 null —— 否则
     *       {@code Init.context()} 返回 null，{@code merge.m.k.d()} 这类
     *       「拼缓存目录」的工具直接 NPE。</li>
     *   <li>默认 {@code /config.json} 要存在 —— Douban 的 {@code homeContent}
     *       第一句就是 {@code new JSONObject(读 /config.json)}，文件不存在时
     *       {@code merge.m.k.a(File)} 返回空串，构造器抛
     *       {@code JSONException: A JSONObject text must begin with '{'}。</li>
     * </ol>
     * 76 个 csp_ 类里有 64 个（覆盖 103 个站点的大半）会传递触达 {@code Init}。
     *
     * <p>为什么不直接调 {@code Init.init(context)}：该方法前三条分支是防二次打包
     * 检查（包名白名单 / 应用名白名单 / 签名黑名单）。我们的包名不在白名单里，
     * 会落到兜底分支，而那个分支会起一个线程，5 秒后执行
     * {@code android.os.Process.killProcess(myPid())} —— 自杀开关。本环境里它之所以
     * 没炸，只是因为运行时没提供 {@code android.os.Process}，被 stub 合成器补成了
     * 空实现，纯属巧合。另一条「检查通过」的分支更不能用：它会跑
     * {@code startFloatBall()} / {@code startGoProxy()} 并起 4 个后台线程，
     * 对一个无界面运行时是纯副作用（还会占本地端口）。
     *
     * <p>所以这里绕开 {@code init}，只做上面两件事：直接反射写 {@code c}，再调
     * {@code saveConfig()}。字段 {@code a}（线程池）与 {@code b}（Handler）由
     * {@code Init} 的构造器初始化，{@code get()} 拿到的单例已经是完整可用的。
     *
     * @param loader  jar 自己的类加载器（Init 由它加载，与运行时不是同一个类）
     * @param jarPath 原始 jar 路径，用于「同 jar 只补一次默认配置」
     */
    private void initHost(ClassLoader loader, String jarPath) {
        Class<?> initCls;
        try {
            initCls = Class.forName(INIT_CLASS, true, loader);
        } catch (ClassNotFoundException e) {
            // 该 jar 不自带 Init，对应蜘蛛也不依赖它
            return;
        } catch (Throwable e) {
            System.err.println("[jvm] 加载 " + INIT_CLASS + " 失败: " + e);
            return;
        }
        injectContext(initCls);
        if (bootstrapped.add(jarPath)) {
            ensureDefaultConfig(initCls);
        }
    }

    /** 把宿主 Application 写进 Init.c（每个 ClassLoader 一份单例，故每次都要写）。 */
    private void injectContext(Class<?> initCls) {
        try {
            Object init = initCls.getMethod("get").invoke(null);
            Field field = initCls.getDeclaredField("c");
            field.setAccessible(true);
            if (field.get(init) == null) {
                field.set(init, context);
            }
        } catch (Throwable e) {
            System.err.println("[jvm] 注入 Init.context 失败: " + e);
        }
    }

    /**
     * 调 jar 自带的 {@code Init.saveConfig()} 补写默认 {@code /config.json}。
     *
     * 该方法会把默认配置里缺失的键合并进现有文件，所以复用它能自动跟随 jar 的
     * 默认值变化，不用在运行时里抄一份字面量。它内部走
     * {@code Init.context().getFilesDir()}，因此必须在 {@link #injectContext} 之后调。
     */
    private void ensureDefaultConfig(Class<?> initCls) {
        Method save;
        try {
            save = initCls.getDeclaredMethod("saveConfig");
        } catch (NoSuchMethodException e) {
            return; // 该版本的 Init 没有这个方法
        }
        try {
            save.setAccessible(true);
            save.invoke(null);
        } catch (Throwable e) {
            System.err.println("[jvm] 补写默认 config.json 失败: " + e);
        }
    }

    /**
     * 一个已创建的蜘蛛实例。
     */
    static final class Instance {
        final Object spider;
        final Class<?> clazz;

        Instance(Object spider) {
            this.spider = spider;
            this.clazz = spider.getClass();
        }
    }

    /** 调用 spider 方法，返回 JSON 字符串。 */
    String invoke(Instance inst, String method, List<Object> args)
            throws Exception {
        Object result;
        switch (method) {
            case "home": {
                Method m = findMethod(inst.clazz, "homeContent", boolean.class);
                result = m != null
                    ? m.invoke(inst.spider, argBool(args, 0))
                    : "";
                break;
            }
            case "homeVideoContent": {
                Method m = findMethod(inst.clazz, "homeVideoContent");
                result = m != null ? m.invoke(inst.spider) : "";
                break;
            }
            case "category": {
                Method m = findMethod(
                    inst.clazz, "categoryContent",
                    String.class, String.class, boolean.class, HashMap.class);
                result = m != null
                    ? m.invoke(
                        inst.spider,
                        argStr(args, 0), argStr(args, 1), argBool(args, 2),
                        argMap(args, 3))
                    : "";
                break;
            }
            case "detail": {
                Method m = findMethod(inst.clazz, "detailContent", List.class);
                result = m != null
                    ? m.invoke(inst.spider, argStrList(args, 0))
                    : "";
                break;
            }
            case "search": {
                Method m = findMethod(inst.clazz, "searchContent", String.class, boolean.class);
                result = m != null
                    ? m.invoke(inst.spider, argStr(args, 0), argBool(args, 1))
                    : "";
                break;
            }
            case "play": {
                Method m = findMethod(
                    inst.clazz, "playerContent",
                    String.class, String.class, List.class);
                result = m != null
                    ? m.invoke(
                        inst.spider, argStr(args, 0), argStr(args, 1),
                        argStrList(args, 2))
                    : "";
                break;
            }
            case "action": {
                Method m = findMethod(inst.clazz, "action", String.class);
                result = m != null ? m.invoke(inst.spider, argStr(args, 0)) : "";
                break;
            }
            case "isVideoFormat": {
                Method m = findMethod(inst.clazz, "isVideoFormat", String.class);
                result = m != null ? m.invoke(inst.spider, argStr(args, 0)) : "";
                break;
            }
            case "manualVideoCheck": {
                Method m = findMethod(inst.clazz, "manualVideoCheck");
                result = m != null ? m.invoke(inst.spider) : "";
                break;
            }
            default:
                throw new IllegalArgumentException("未知 spider 方法: " + method);
        }
        return result == null ? "" : result.toString();
    }

    /** 探测实例实现了哪些方法（能力位）。 */
    List<String> capabilities(Instance inst) {
        List<String> caps = new ArrayList<>();
        Class<?> c = inst.clazz;
        if (hasMethod(c, "homeContent", boolean.class)) caps.add("home");
        if (hasMethod(c, "homeVideoContent")) caps.add("homeVideoContent");
        if (hasMethod(c, "categoryContent", String.class, String.class,
            boolean.class, HashMap.class)) caps.add("category");
        if (hasMethod(c, "detailContent", List.class)) caps.add("detail");
        if (hasMethod(c, "searchContent", String.class, boolean.class)) {
            caps.add("search");
        }
        if (hasMethod(c, "playerContent", String.class, String.class, List.class)) {
            caps.add("play");
        }
        if (hasMethod(c, "action", String.class)) caps.add("action");
        return caps;
    }

    // ---- 反射辅助 ----------------------------------------------------------

    private static Method findMethod(
            Class<?> clazz, String name, Class<?>... params) {
        try {
            Method m = clazz.getMethod(name, params);
            m.setAccessible(true);
            return m;
        } catch (NoSuchMethodException e) {
            return null;
        }
    }

    private static boolean hasMethod(Class<?> clazz, String name, Class<?>... params) {
        return findMethod(clazz, name, params) != null;
    }

    private static String argStr(List<Object> args, int idx) {
        if (idx >= args.size()) return null;
        Object v = args.get(idx);
        return v == null ? null : v.toString();
    }

    private static boolean argBool(List<Object> args, int idx) {
        if (idx >= args.size()) return false;
        Object v = args.get(idx);
        if (v instanceof Boolean) return (Boolean) v;
        if (v instanceof Number) return ((Number) v).intValue() != 0;
        return v != null && Boolean.parseBoolean(v.toString());
    }

    @SuppressWarnings("unchecked")
    private static HashMap<String, String> argMap(List<Object> args, int idx) {
        if (idx >= args.size() || !(args.get(idx) instanceof Map)) {
            return new HashMap<>();
        }
        HashMap<String, String> out = new HashMap<>();
        for (Map.Entry<Object, Object> e
                : ((Map<Object, Object>) args.get(idx)).entrySet()) {
            out.put(String.valueOf(e.getKey()),
                e.getValue() == null ? null : String.valueOf(e.getValue()));
        }
        return out;
    }

    private static List<String> argStrList(List<Object> args, int idx) {
        List<String> out = new ArrayList<>();
        if (idx >= args.size()) return out;
        Object v = args.get(idx);
        if (v instanceof List) {
            for (Object o : (List<?>) v) {
                out.add(o == null ? null : o.toString());
            }
        } else if (v != null) {
            // 兼容单个字符串
            out.add(v.toString());
        }
        return out;
    }
}