package android.content;

import java.util.Map;
import java.util.Set;

/**
 * android.content.SharedPreferences 的最小兼容 shim。
 *
 * <p><b>必须是 interface —— 这不是风格问题，是硬约束。</b> Android 上它就是
 * {@code public interface SharedPreferences}，所以 dex→java 转换出来的蜘蛛代码
 * 对它的调用一律编译成 {@code invokeinterface}。若宿主把它声明成 {@code class}，
 * JVM 在解析那条 {@code invokeinterface} 时会抛：
 *
 * <pre>
 * java.lang.IncompatibleClassChangeError:
 *   Found class android.content.SharedPreferences, but interface was expected
 * </pre>
 *
 * <p>2026-10-05 实测：{@code csp_PanWebShare}（八零 • 4K 等 12 个站点）的
 * {@code detailContent} 会走 {@code merge.a.a.saveName → merge.m.l.b}，
 * 即「把剧名存进 SharedPreferences」。于是<b>首页能出、点进详情必炸</b>，
 * 而错误信息只有一句 {@code spider.detail 执行失败: null} —— 真正的原因藏在
 * {@code error.data.stack} 的 {@code Caused by} 里。
 *
 * <p>同理 {@link Editor} 在 Android 上也是嵌套 <b>interface</b>，实现体在
 * {@link SharedPreferencesImpl}。
 */
public interface SharedPreferences {

    /** 编辑器。Android 上是嵌套 interface，调用点同样是 {@code invokeinterface}。 */
    interface Editor {

        /** 写入字符串。 */
        Editor putString(String key, String value);

        /** 写入字符串集合。 */
        Editor putStringSet(String key, Set<String> values);

        /** 写入 int。 */
        Editor putInt(String key, int value);

        /** 写入 long。 */
        Editor putLong(String key, long value);

        /** 写入 float。 */
        Editor putFloat(String key, float value);

        /** 写入 boolean。 */
        Editor putBoolean(String key, boolean value);

        /** 删除 key。 */
        Editor remove(String key);

        /** 清空全部。 */
        Editor clear();

        /** 同步提交，返回是否成功。 */
        boolean commit();

        /** 异步提交（内存实现里等价于 {@link #commit()}）。 */
        void apply();
    }

    /** 偏好变更监听器（Android 上也是嵌套 interface）。 */
    interface OnSharedPreferenceChangeListener {

        /** 某个 key 变化时回调。 */
        void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key);
    }

    /** 全部键值。 */
    Map<String, ?> getAll();

    /** 读取字符串。 */
    String getString(String key, String defValue);

    /** 读取字符串集合。 */
    Set<String> getStringSet(String key, Set<String> defValues);

    /** 读取 int。 */
    int getInt(String key, int defValue);

    /** 读取 long。 */
    long getLong(String key, long defValue);

    /** 读取 float。 */
    float getFloat(String key, float defValue);

    /** 读取 boolean。 */
    boolean getBoolean(String key, boolean defValue);

    /** 是否含 key。 */
    boolean contains(String key);

    /** 获取编辑器。 */
    Editor edit();

    /** 注册变更监听（内存实现里只记录，不回调）。 */
    void registerOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener);

    /** 注销变更监听。 */
    void unregisterOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener);
}
