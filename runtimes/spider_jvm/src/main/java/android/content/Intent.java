package android.content;

/**
 * android.content.Intent 的最小兼容 shim。
 *
 * 多数 csp_ 源不用它；个别（PanQuark 等）会构造 Intent 拿 extra。这里提供
 * 最简占位，防止 NoClassDefFoundError。
 */
public class Intent {

    private String action;
    private String data;

    public Intent() {
    }

    public Intent(String action) {
        this.action = action;
    }

    public Intent setAction(String action) {
        this.action = action;
        return this;
    }

    public String getAction() {
        return action;
    }

    public Intent setData(String data) {
        this.data = data;
        return this;
    }

    public String getDataString() {
        return data;
    }
}