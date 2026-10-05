package android.os;

/**
 * android.os.Process 的最小兼容 shim。
 *
 * <p>{@link #myPid()} 返回真实 pid（源常把它当请求参数里的「客户端标识」，
 * 真实值比假值更不容易被风控盯上）；{@link #killProcess} 是无操作 ——
 * 源里用它是为了「自杀重启」，无头运行时里自杀等于把整条 RPC 管道干掉，
 * 所以必须吞掉。
 */
public final class Process {

    /** 无优先级。 */
    public static final int THREAD_PRIORITY_DEFAULT = 0;

    private Process() {
    }

    /** 当前进程 pid。 */
    public static int myPid() {
        return (int) ProcessHandle.current().pid();
    }

    /** 当前进程 tid（无头运行时按 pid 报）。 */
    public static int myTid() {
        return myPid();
    }

    /** 当前线程 uid。 */
    public static int myUid() {
        return 0;
    }

    /**
     * 杀进程 —— 无操作。
     *
     * <p>源用它做「异常时重启自己」。在无头 RPC 运行时里，退出进程会连带
     * 杀掉承载管道的 JVM，表现为整站「无响应」。吞掉后源会继续往下走，
     * 后续异常由外层捕获并如实上报。
     */
    public static void killProcess(int pid) {
        // no-op：见上面的注释
    }
}
