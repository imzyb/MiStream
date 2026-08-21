package io.mistream.jvm;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Spider JVM 运行时子进程主循环。
 *
 * 与 spider_js 的 runtime_child.dart 对齐：单线程同步循环、LSP 分帧、JSON-RPC
 * 2.0。支持 docs/08 的管理方法（handshake/ping/shutdown/stats）与 spider 调用
 * （create/destroy/home/category/detail/search/play/action）。
 *
 * JSON 编解码用 gson（在运行时 classpath）。错误码对齐 docs/08 §7：
 * -32000 以下运行时层，-32100 以下 spider 层。
 */
public final class Main {

    /** 协议版本（docs/08 §8）。 */
    static final int PROTOCOL_VERSION = 1;

    /** 运行时版本。 */
    static final String RUNTIME_VERSION = "0.1.0";

    /** 上报能力位。 */
    static final List<String> FEATURES = List.of("storage");

    private final FrameCodec codec;
    private final Map<String, SpiderBridge.Instance> instances =
        new ConcurrentHashMap<>();
    private final SpiderBridge bridge;

    private long nextOutboundId = 1;
    private int activeRequestId = -1;
    private boolean shuttingDown = false;
    private long startNanos = System.nanoTime();

    Main(FrameCodec codec, SpiderBridge bridge) {
        this.codec = codec;
        this.bridge = bridge;
    }

    /** 主入口。 */
    public static void main(String[] args) {
        java.io.File cacheDir = new java.io.File(
            System.getProperty("java.io.tmpdir"), "mistream-jvm-jars");
        JarLoader loader = new JarLoader(cacheDir, classpathEntries());
        SpiderBridge bridge = new SpiderBridge(loader, new android.content.Context() {
        });
        Main runtime = new Main(new FrameCodec(), bridge);
        try {
            runtime.run();
        } catch (UncheckedIOException e) {
            if (e.getCause() instanceof FrameFormatException) {
                System.err.println("[jvm] 分帧错误，退出: " + e.getCause().getMessage());
            }
            System.exit(1);
        }
    }

    private static List<java.io.File> classpathEntries() {
        List<java.io.File> out = new ArrayList<>();
        for (String entry
                : System.getProperty("java.class.path", "").split(java.io.File.pathSeparator)) {
            if (!entry.isEmpty()) out.add(new java.io.File(entry));
        }
        return out;
    }

    /** 跑主循环，直到 stdin 关闭或收到 runtime.shutdown。 */
    void run() {
        while (!shuttingDown) {
            String raw;
            try {
                raw = codec.readFrame();
            } catch (IOException e) {
                if (e instanceof FrameFormatException) {
                    System.err.println("[jvm] 畸形消息，跳过: " + e.getMessage());
                    continue;
                }
                // 流结束或 IO 错误
                return;
            }
            if (raw == null) return;
            Map<String, Object> msg = decode(raw);
            if (msg == null) continue;
            dispatch(msg);
        }
    }

    private Map<String, Object> decode(String raw) {
        try {
            Object o = new com.google.gson.Gson().fromJson(raw, Object.class);
            if (o instanceof Map) {
                Map<String, Object> out = new LinkedHashMap<>();
                for (Map.Entry<?, ?> e : ((Map<?, ?>) o).entrySet()) {
                    out.put(String.valueOf(e.getKey()), e.getValue());
                }
                return out;
            }
            return null;
        } catch (Exception e) {
            return null;
        }
    }

    private void dispatch(Map<String, Object> msg) {
        Object methodObj = msg.get("method");
        if (!(methodObj instanceof String)) return;
        String method = (String) methodObj;
        Object idObj = msg.get("id");

        @SuppressWarnings("unchecked")
        Map<String, Object> params = msg.get("params") instanceof Map
            ? (Map<String, Object>) msg.get("params")
            : new LinkedHashMap<>();

        if (!(idObj instanceof Number)) {
            // 通知：无响应
            if (method.equals("runtime.shutdown")) shuttingDown = true;
            return;
        }
        int id = ((Number) idObj).intValue();
        activeRequestId = id;
        try {
            Object result = handle(method, params);
            respondResult(id, result);
        } catch (RpcFailure e) {
            respondError(id, e.code, e.getMessage(), e.data);
        } catch (Throwable e) {
            respondError(id, -32603, "运行时内部错误: " + e, null);
        } finally {
            activeRequestId = -1;
        }
    }

    private Object handle(String method, Map<String, Object> params) throws RpcFailure {
        switch (method) {
            case "runtime.handshake":
                return handshake(params);
            case "runtime.ping":
                return Map.of("ts", System.currentTimeMillis());
            case "runtime.shutdown":
                shuttingDown = true;
                return Map.of();
            case "runtime.stats":
                return Map.of(
                    "rssBytes", 0,
                    "contexts", instances.size(),
                    "pendingCalls", 0,
                    "uptimeMs", (System.nanoTime() - startNanos) / 1_000_000L);
            case "spider.create":
                return create(params);
            case "spider.destroy":
                return destroy(params);
            case "$/cancelRequest":
                return Map.of();
            default:
                if (method.startsWith("spider.")) {
                    return invoke(method.substring("spider.".length()), params);
                }
                throw new RpcFailure(-32601, "未知方法: " + method, null);
        }
    }

    private Map<String, Object> handshake(Map<String, Object> params) {
        return Map.of(
            "protocolVersion", PROTOCOL_VERSION,
            "runtimeVersion", RUNTIME_VERSION,
            "features", FEATURES);
    }

    private Map<String, Object> create(Map<String, Object> params) throws RpcFailure {
        String instanceId = requireString(params, "instanceId");
        String jarPath = requireString(params, "jarPath");
        String className = requireString(params, "className");
        Object extendObj = params.get("extend");

        instances.remove(instanceId);
        try {
            SpiderBridge.Instance inst = bridge.create(
                jarPath, className, extendObj == null ? null : String.valueOf(extendObj));
            instances.put(instanceId, inst);
            return Map.of("capabilities", bridge.capabilities(inst));
        } catch (Exception e) {
            throw new RpcFailure(-32100, "加载 jar 失败: " + e.getMessage(),
                Map.of("stack", stackOf(e)));
        }
    }

    private Map<String, Object> destroy(Map<String, Object> params) throws RpcFailure {
        String instanceId = requireString(params, "instanceId");
        instances.remove(instanceId);
        return Map.of();
    }

    private Object invoke(String name, Map<String, Object> params) throws RpcFailure {
        String instanceId = requireString(params, "instanceId");
        SpiderBridge.Instance inst = instances.get(instanceId);
        if (inst == null) {
            throw new RpcFailure(-32003, "实例不存在: " + instanceId, null);
        }
        Object argsObj = params.get("args");
        List<Object> args = new ArrayList<>();
        if (argsObj instanceof List) {
            args.addAll((List<?>) argsObj);
        }
        // 协议约定（与 JS 运行时对齐）：spider.detail 带 [tid, page] 是分类列表，
        // 路由到 category；[ids] 才是视频详情。
        if (name.equals("detail") && args.size() >= 2) {
            name = "category";
        }
        try {
            return bridge.invoke(inst, name, args);
        } catch (Exception e) {
            throw new RpcFailure(-32101, "spider." + name + " 执行失败: "
                + e.getMessage(), Map.of("stack", stackOf(e)));
        }
    }

    // ---- 收发 ---------------------------------------------------------------

    private void respondResult(int id, Object result) {
        Map<String, Object> msg = new LinkedHashMap<>();
        msg.put("jsonrpc", "2.0");
        msg.put("id", id);
        msg.put("result", result);
        write(msg);
    }

    private void respondError(int id, int code, String message, Map<String, Object> data) {
        Map<String, Object> err = new LinkedHashMap<>();
        err.put("code", code);
        err.put("message", message);
        if (data != null) err.put("data", data);
        Map<String, Object> msg = new LinkedHashMap<>();
        msg.put("jsonrpc", "2.0");
        msg.put("id", id);
        msg.put("error", err);
        write(msg);
    }

    private void write(Map<String, Object> msg) {
        try {
            codec.writeFrame(new com.google.gson.Gson().toJson(msg));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    // ---- 杂项 ---------------------------------------------------------------

    private static String requireString(Map<String, Object> params, String key)
            throws RpcFailure {
        Object v = params.get(key);
        if (v instanceof String && !((String) v).isEmpty()) return (String) v;
        throw new RpcFailure(-32602, "缺少参数: " + key, null);
    }

    private static String stackOf(Throwable e) {
        java.io.StringWriter sw = new java.io.StringWriter();
        e.printStackTrace(new java.io.PrintWriter(sw));
        String s = sw.toString();
        return s.length() > 4000 ? s.substring(0, 4000) : s;
    }

    /** 内部失败信号，dispatch 转成 JSON-RPC error。 */
    static final class RpcFailure extends Exception {
        final int code;
        final Map<String, Object> data;

        RpcFailure(int code, String message, Map<String, Object> data) {
            super(message);
            this.code = code;
            this.data = data;
        }
    }
}