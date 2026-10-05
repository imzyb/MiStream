package android.util;

/**
 * android.util.Log 的最小兼容 shim。
 *
 * 真实 jar 里 csp_ 类用 Log.d/e/i/w/v 打日志。这里映射到 stderr，与
 * SpiderDebug 一致（stdout 是 RPC 信道）。
 */
public final class Log {

    private Log() {
    }

    /** verbose。 */
    public static int v(String tag, String msg) {
        return log(tag, msg);
    }

    /** debug。 */
    public static int d(String tag, String msg) {
        return log(tag, msg);
    }

    /** info。 */
    public static int i(String tag, String msg) {
        return log(tag, msg);
    }

    /** warn。 */
    public static int w(String tag, String msg) {
        return log(tag, msg);
    }

    /** error。 */
    public static int e(String tag, String msg) {
        return log(tag, msg);
    }

    /** error + 异常。 */
    public static int e(String tag, String msg, Throwable tr) {
        System.err.println("[Log:" + tag + "] " + msg);
        if (tr != null) tr.printStackTrace(System.err);
        return 1;
    }

    /**
     * 按优先级打日志。
     *
     * <p>这是 android.util.Log 的**底层入口** —— 真实 Android 上 {@code d/i/w/e}
     * 内部就是调它。很多源（以及 okhttp 的 android 平台适配层）会直接调
     * {@code println}，缺了它会在调用点抛 NoSuchMethodError。
     *
     * @param priority 优先级（见 {@code Log.VERBOSE..ASSERT}）
     */
    public static int println(int priority, String tag, String msg) {
        System.err.println("[" + priorityName(priority) + ":" + tag + "] "
                + (msg == null ? "" : msg));
        return 1;
    }

    /** 判断某优先级是否会被输出 —— 恒 true，保证源的调试分支能跑到。 */
    public static boolean isLoggable(String tag, int level) {
        return true;
    }

    /** 取优先级名。 */
    public static String getStackTraceString(Throwable tr) {
        if (tr == null) return "";
        java.io.StringWriter sw = new java.io.StringWriter();
        tr.printStackTrace(new java.io.PrintWriter(sw));
        return sw.toString();
    }

    private static String priorityName(int priority) {
        switch (priority) {
            case 2: return "V";
            case 3: return "D";
            case 4: return "I";
            case 5: return "W";
            case 6: return "E";
            case 7: return "A";
            default: return String.valueOf(priority);
        }
    }

    private static int log(String tag, String msg) {
        System.err.println("[Log:" + tag + "] " + (msg == null ? "" : msg));
        return 1;
    }
}