package android.content;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * android.content.SharedPreferences 的最小兼容 shim。
 *
 * 内存实现，进程生命周期内有效。真实 jar 里的源可能用它缓存 token/配置。
 */
public class SharedPreferences {

    private final Map<String, Object> data = new ConcurrentHashMap<>();

    /** 读取字符串。 */
    public String getString(String key, String defValue) {
        Object v = data.get(key);
        return v instanceof String ? (String) v : defValue;
    }

    /** 读取 int。 */
    public int getInt(String key, int defValue) {
        Object v = data.get(key);
        return v instanceof Integer ? (Integer) v : defValue;
    }

    /** 读取 long。 */
    public long getLong(String key, long defValue) {
        Object v = data.get(key);
        return v instanceof Long ? (Long) v : defValue;
    }

    /** 读取 boolean。 */
    public boolean getBoolean(String key, boolean defValue) {
        Object v = data.get(key);
        return v instanceof Boolean ? (Boolean) v : defValue;
    }

    /** 是否含 key。 */
    public boolean contains(String key) {
        return data.containsKey(key);
    }

    /** 获取编辑器。 */
    public Editor edit() {
        return new Editor(this);
    }

    /** 编辑器实现。 */
    public static final class Editor {
        private final SharedPreferences prefs;
        private final Map<String, Object> pending = new ConcurrentHashMap<>();

        Editor(SharedPreferences prefs) {
            this.prefs = prefs;
        }

        public Editor putString(String key, String value) {
            pending.put(key, value);
            return this;
        }

        public Editor putInt(String key, int value) {
            pending.put(key, value);
            return this;
        }

        public Editor putLong(String key, long value) {
            pending.put(key, value);
            return this;
        }

        public Editor putBoolean(String key, boolean value) {
            pending.put(key, value);
            return this;
        }

        public Editor remove(String key) {
            pending.put(key, null);
            return this;
        }

        public Editor clear() {
            pending.clear();
            pending.put("__clear__", Boolean.TRUE);
            return this;
        }

        public boolean commit() {
            if (pending.containsKey("__clear__")) {
                prefs.data.clear();
                pending.remove("__clear__");
            }
            prefs.data.putAll(pending);
            pending.clear();
            return true;
        }

        public void apply() {
            commit();
        }
    }
}