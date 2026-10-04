package android.os;

/**
 * android.os.Handler 的最小兼容 shim。
 *
 * 支持 post/postDelayed（同步立即执行或定时）与 sendEmptyMessage。个别源用
 * Handler 做延迟任务。
 */
public class Handler {

    private final Looper looper;

    public Handler() {
        this.looper = Looper.myLooper();
    }

    public Handler(Looper looper) {
        this.looper = looper;
    }

    /** 提交一个任务到队列（这里同步立即执行）。 */
    public final boolean post(Runnable r) {
        if (r == null) return false;
        r.run();
        return true;
    }

    /** 延迟提交（这里立即执行——运行时无 UI 循环）。 */
    public final boolean postDelayed(Runnable r, long delayMillis) {
        if (r == null) return false;
        r.run();
        return true;
    }

    /** 发送空消息（无操作）。 */
    public final boolean sendEmptyMessage(int what) {
        return true;
    }

    /** 发送消息（无操作）。 */
    public final boolean sendMessage(Message msg) {
        return true;
    }

    /** 移除回调。 */
    public final void removeCallbacks(Runnable r) {
        // no-op
    }
}