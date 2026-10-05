package android.net.wifi;

/**
 * android.net.wifi.WifiInfo 的最小兼容 shim。
 *
 * <p>源用它拿本机 IP 当「设备标识」。真实 Android 上 {@link #getIpAddress()}
 * 返回一个**小端序**的 int。这里恒返回 0（"未连接"）—— 让源走「拿不到就换别的
 * 标识」的兜底分支，比编造一个 IP 更安全（编造的 IP 有可能撞上真实网段，
 * 让站点把它当成内网请求而拒绝）。
 */
public class WifiInfo {

    /** 未连接时的 IP 值。 */
    public static final int INVALID_IP = 0;

    public WifiInfo() {
    }

    /** 本机 IP（小端序 int）；无头运行时恒为「未连接」。 */
    public int getIpAddress() {
        return INVALID_IP;
    }

    /** SSID（占位）。 */
    public String getSSID() {
        return null;
    }

    /** BSSID（占位）。 */
    public String getBSSID() {
        return null;
    }

    /** MAC 地址（占位）。Android 6 之后本来就恒返回 02:00:00:00:00:00。 */
    public String getMacAddress() {
        return "02:00:00:00:00:00";
    }

    /** 链路速率（Mbps）。 */
    public int getLinkSpeed() {
        return 0;
    }

    /** 网络 id。 */
    public int getNetworkId() {
        return -1;
    }
}
