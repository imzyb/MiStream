package android.net;

/**
 * android.net.NetworkInfo 的最小兼容 shim。
 */
public class NetworkInfo {

    public static final int TYPE_WIFI = 1;
    public static final int TYPE_MOBILE = 0;

    private boolean connected = true;

    public NetworkInfo() {
    }

    /** 是否已连接（默认 true）。 */
    public boolean isConnected() {
        return connected;
    }

    public boolean isConnectedOrConnecting() {
        return connected;
    }

    public int getType() {
        return TYPE_WIFI;
    }
}