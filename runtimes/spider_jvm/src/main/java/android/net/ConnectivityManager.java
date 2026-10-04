package android.net;

/**
 * android.net.ConnectivityManager 的最小兼容 shim。
 *
 * Init 用 getActiveNetworkInfo 判断网络。JVM 直连场景下默认返回"已连接"。
 */
public class ConnectivityManager {

    public static final String CONNECTIVITY_ACTION = "android.net.conn.CONNECTIVITY_CHANGE";

    public ConnectivityManager() {
    }

    /** 活跃网络信息（默认视为已连接）。 */
    public NetworkInfo getActiveNetworkInfo() {
        return new NetworkInfo();
    }
}