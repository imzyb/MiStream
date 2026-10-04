package android.os;

/**
 * android.os.Looper 的最小兼容 shim。
 *
 * 个别源（含 Handler 逻辑的）会拿主 Looper。这里提供进程级单例。
 */
public final class Looper {

    private static final Looper MAIN = new Looper();
    private static final ThreadLocal<Looper> TLS = new ThreadLocal<>();

    private Looper() {
    }

    /** 主 Looper。 */
    public static Looper getMainLooper() {
        return MAIN;
    }

    /** 当前线程的 Looper，无则 null。 */
    public static Looper myLooper() {
        return TLS.get();
    }

    /** 准备当前线程的 Looper。 */
    public static void prepare() {
        TLS.set(new Looper());
    }

    /** 进入消息循环（无操作，占位）。 */
    public void loop() {
        // no-op
    }

    /** 当前线程是否为主线程。 */
    public static boolean isMainThread() {
        return TLS.get() == MAIN;
    }
}