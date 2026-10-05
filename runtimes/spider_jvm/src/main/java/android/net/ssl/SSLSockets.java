package android.net.ssl;

import javax.net.ssl.SSLSocket;

/**
 * android.net.ssl.SSLSockets 的最小兼容 shim。
 *
 * <p>源（okhttp 的新版本会走这条）用它做两个「平台能力协商」：
 * <ul>
 *   <li>{@link #isSupportedSocket} —— 这个 SSLSocket 支不支持 TLS 1.3 之类的新特性。
 *       恒报 {@code true}，让源走「现代路径」。</li>
 *   <li>{@link #setUseSessionTickets} —— 开/关会话票据复用。JDK 的 SSLSocket 默认
 *       就支持会话复用，不需要额外动作，所以这里是空实现。</li>
 * </ul>
 *
 * <p>两个方法都是**静态**的，与真实 API 同形 —— 如果写成实例方法，调用点会直接
 * 报 IncompatibleClassChangeError。
 */
public final class SSLSockets {

    private SSLSockets() {
    }

    /** 是否支持这些 SSL 参数 —— 恒 true。 */
    public static boolean isSupportedSocket(SSLSocket socket) {
        return socket != null;
    }

    /** 设置是否使用会话票据 —— JDK 无需干预，空实现。 */
    public static void setUseSessionTickets(SSLSocket socket, boolean useSessionTickets) {
        // no-op：JDK 的 SSLSocket 自行管理会话复用
    }
}
