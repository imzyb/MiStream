package android.security;

/**
 * android.security.NetworkSecurityPolicy 的最小兼容 shim。
 *
 * <p>源用它判断「能不能走明文 HTTP」。我们的运行时**必须**允许明文 ——
 * 大量采集源的接口就是 http（或者用了自签证书的 https），拒绝明文等于
 * 让这些源直接失效。
 *
 * <p>所以三个入口一律返回 {@code true}。这里不引入任何真实策略逻辑，
 * 因为运行时的网络出口本来就是宿主 Dart 侧统一管的。
 */
public final class NetworkSecurityPolicy {

    private static final NetworkSecurityPolicy INSTANCE = new NetworkSecurityPolicy();

    private NetworkSecurityPolicy() {
    }

    /** 单例。 */
    public static NetworkSecurityPolicy getInstance() {
        return INSTANCE;
    }

    /** 是否允许明文流量 —— 恒允许。 */
    public boolean isCleartextTrafficPermitted() {
        return true;
    }

    /** 指定主机是否允许明文流量 —— 恒允许。 */
    public boolean isCleartextTrafficPermitted(String hostname) {
        return true;
    }
}
