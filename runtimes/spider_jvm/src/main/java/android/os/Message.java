package android.os;

/**
 * android.os.Message 的最小兼容 shim。
 */
public final class Message {

    /** 消息标识。 */
    public int what;

    /** 整数载荷。 */
    public int arg1;

    /** 整数载荷。 */
    public int arg2;

    /** 对象载荷。 */
    public Object obj;

    private Message() {
    }

    /** 获取消息。 */
    public static Message obtain() {
        return new Message();
    }

    /** 复制载荷。 */
    public Message setData(Bundle data) {
        return this;
    }

    /** 获取载荷（无操作，返回 null）。 */
    public Bundle getData() {
        return null;
    }
}