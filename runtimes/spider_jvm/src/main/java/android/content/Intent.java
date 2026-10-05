package android.content;

import android.net.Uri;

import java.util.HashMap;
import java.util.Map;

/**
 * android.content.Intent 的最小兼容 shim。
 *
 * <p>多数 csp_ 源不用它；个别（PanQuark / PanUC / Market 等）会构造 Intent
 * 拿 extra 或做「拉起外部 App」的判断。本类按真实 API 的形状补齐成员 ——
 * 链路里这些调用点大多**不会被执行**（无头下没有界面），但只要有源在某个
 * 分支里调到、而方法不存在，就会在调用点抛 NoSuchMethodError。
 *
 * <p>返回值一律 {@code this}（链式调用），与真实 API 一致 —— 源里
 * {@code new Intent().setClassName(a, b).addFlags(FLAG).putExtra(k, v)} 这种
 * 长链非常常见，返回 null 会立刻 NPE。
 */
public class Intent {

    /** 标记：新任务。 */
    public static final int FLAG_ACTIVITY_NEW_TASK = 0x10000000;
    /** 标记：清空顶部。 */
    public static final int FLAG_ACTIVITY_CLEAR_TOP = 0x04000000;
    /** 标记：单顶。 */
    public static final int FLAG_ACTIVITY_SINGLE_TOP = 0x20000000;
    /** 标记：无动画。 */
    public static final int FLAG_ACTIVITY_NO_ANIMATION = 0x00010000;

    /** 动作：查看。 */
    public static final String ACTION_VIEW = "android.intent.action.VIEW";
    /** 动作：发送。 */
    public static final String ACTION_SEND = "android.intent.action.SEND";
    /** 动作：主入口。 */
    public static final String ACTION_MAIN = "android.intent.action.MAIN";

    private String action;
    private Uri data;
    private String type;
    private ComponentName component;
    private int flags;
    private final Map<String, Object> extras = new HashMap<>();

    public Intent() {
    }

    public Intent(String action) {
        this.action = action;
    }

    /** 动作 + 数据。 */
    public Intent(String action, Uri data) {
        this.action = action;
        this.data = data;
    }

    public Intent setAction(String action) {
        this.action = action;
        return this;
    }

    public String getAction() {
        return action;
    }

    /** 设置数据（android 语义：Uri）。 */
    public Intent setData(Uri data) {
        this.data = data;
        this.type = null;
        return this;
    }

    /**
     * 设置数据（字符串重载）。
     *
     * <p>非 android 原生 API，保留是为了兼容既有 shim 的调用方；内部按
     * {@link Uri#parse} 转成 Uri，保证两种入口的状态一致。
     */
    public Intent setData(String data) {
        this.data = data == null ? null : Uri.parse(data);
        this.type = null;
        return this;
    }

    /** 设置数据 + MIME 类型。 */
    public Intent setDataAndType(Uri data, String type) {
        this.data = data;
        this.type = type;
        return this;
    }

    /** 取数据。 */
    public Uri getData() {
        return data;
    }

    /** 取数据串。 */
    public String getDataString() {
        return data == null ? null : data.toString();
    }

    /** MIME 类型。 */
    public String getType() {
        return type;
    }

    /** 设置 MIME 类型。 */
    public Intent setType(String type) {
        this.type = type;
        this.data = null;
        return this;
    }

    /** 加标记。 */
    public Intent addFlags(int flags) {
        this.flags |= flags;
        return this;
    }

    /** 设置标记（覆盖）。 */
    public Intent setFlags(int flags) {
        this.flags = flags;
        return this;
    }

    /** 取标记。 */
    public int getFlags() {
        return flags;
    }

    /** 按「包名 + 类名」指定组件。 */
    public Intent setClassName(String packageName, String className) {
        this.component = new ComponentName(packageName, className);
        return this;
    }

    /** 指定组件。 */
    public Intent setComponent(ComponentName component) {
        this.component = component;
        return this;
    }

    /** 取组件。 */
    public ComponentName getComponent() {
        return component;
    }

    /** 放字符串 extra。 */
    public Intent putExtra(String name, String value) {
        extras.put(name, value);
        return this;
    }

    /** 放布尔 extra。 */
    public Intent putExtra(String name, boolean value) {
        extras.put(name, value);
        return this;
    }

    /** 放整型 extra。 */
    public Intent putExtra(String name, int value) {
        extras.put(name, value);
        return this;
    }

    /** 取字符串 extra。 */
    public String getStringExtra(String name) {
        Object v = extras.get(name);
        return v == null ? null : String.valueOf(v);
    }

    /** 取布尔 extra。 */
    public boolean getBooleanExtra(String name, boolean defaultValue) {
        Object v = extras.get(name);
        return v instanceof Boolean ? (Boolean) v : defaultValue;
    }

    /** 取整型 extra。 */
    public int getIntExtra(String name, int defaultValue) {
        Object v = extras.get(name);
        return v instanceof Integer ? (Integer) v : defaultValue;
    }

    /** 是否带某个 extra。 */
    public boolean hasExtra(String name) {
        return extras.containsKey(name);
    }

    /** 简化的描述串（源有时把它拼进日志/参数）。 */
    public String toUri(int flags) {
        return data == null ? "" : data.toString();
    }

    @Override
    public String toString() {
        return "Intent{action=" + action + ", data=" + data + ", type=" + type + "}";
    }
}
