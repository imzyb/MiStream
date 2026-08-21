package android.os;

/**
 * android.os.SystemClock 的最小兼容 shim。
 */
public final class SystemClock {

    private SystemClock() {
    }

    /** 开机以来毫秒（用 uptime 近似）。 */
    public static long uptimeMillis() {
        return System.currentTimeMillis() - BOOT_EPOCH;
    }

    /** 单调时钟毫秒。 */
    public static long elapsedRealtime() {
        return System.nanoTime() / 1_000_000L;
    }

    /** 挂起。 */
    public static void sleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException ignored) {
            Thread.currentThread().interrupt();
        }
    }

    private static final long BOOT_EPOCH =
        System.currentTimeMillis() - System.nanoTime() / 1_000_000L;
}