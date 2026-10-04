package com.github.catvod.crawler;

/**
 * TVBox 蜘蛛的日志工具（android 侧同名类的最小兼容实现）。
 *
 * 真实 jar 里的 csp_ 类调用 {@code SpiderDebug.log(...)} 打日志。这里输出到
 * stderr——stdout 是 RPC 协议信道，绝不能污染（docs/08 §1）。
 */
public final class SpiderDebug {

    private SpiderDebug() {
    }

    /** 打一条普通日志。 */
    public static void log(String msg) {
        System.err.println("[Spider] " + msg);
    }

    /** 打印异常堆栈。 */
    public static void log(Throwable t) {
        System.err.println("[Spider] exception:");
        t.printStackTrace(System.err);
    }

    /** 打一条错误日志。 */
    public static void error(String msg) {
        System.err.println("[Spider:error] " + msg);
    }
}