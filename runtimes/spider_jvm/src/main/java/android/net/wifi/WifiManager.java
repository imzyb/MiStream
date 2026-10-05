package android.net.wifi;

/**
 * android.net.wifi.WifiManager 的最小兼容 shim。
 *
 * <p>{@link #getConnectionInfo()} 返回一个「未连接」的 {@link WifiInfo}，
 * 而不是 null —— 源里几乎都是 {@code manager.getConnectionInfo().getIpAddress()}
 * 这种链式调用，返回 null 会变成 NPE，比返回一个语义明确的「未连接」对象更难定位。
 */
public class WifiManager {

    /** 系统服务名（{@code Context.getSystemService} 用）。 */
    public static final String WIFI_SERVICE = "wifi";

    /** 恒为「已启用」：源常先判断它再取连接信息。 */
    public static final int WIFI_STATE_ENABLED = 3;

    /** 连接状态：已连接。 */
    public static final int WIFI_STATE_UNKNOWN = 4;

    public WifiManager() {
    }

    /** 当前连接信息（恒为「未连接」）。 */
    public WifiInfo getConnectionInfo() {
        return new WifiInfo();
    }

    /** WiFi 是否启用 —— 恒 true，让源继续走取连接信息的分支。 */
    public boolean isWifiEnabled() {
        return true;
    }

    /** WiFi 状态 —— 恒「已启用」。 */
    public int getWifiState() {
        return WIFI_STATE_ENABLED;
    }
}
