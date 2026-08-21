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

    private static int log(String tag, String msg) {
        System.err.println("[Log:" + tag + "] " + (msg == null ? "" : msg));
        return 1;
    }
}