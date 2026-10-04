package io.mistream.jvm;

import android.content.Context;

import com.github.catvod.crawler.Spider;
import com.github.catvod.crawler.SpiderApi;

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
 * - 调用 init(Context, String) 或 init(Context)
 * - 按名字+参数形态分发 homeContent / categoryContent / detailContent /
 *   searchContent / playerContent / action 等
 *
 * 反射调用失败统一抛 {@link SpiderInvocationException}，由主循环转成
 * JSON-RPC error。
 */
public final class SpiderBridge {

    private final JarLoader jarLoader;
    private final Context context;

    SpiderBridge(JarLoader jarLoader, Context context) {
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