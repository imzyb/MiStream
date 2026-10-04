package android.os;

/**
 * android.os.Bundle 的最小兼容 shim。
 */
public class Bundle {

    private final java.util.Map<String, Object> map = new java.util.HashMap<>();

    /** 构造。 */
    public Bundle() {
    }

    public Bundle(Bundle b) {
        if (b != null) map.putAll(b.map);
    }

    /** 放字符串。 */
    public void putString(String key, String value) {
        map.put(key, value);
    }

    /** 取字符串。 */
    public String getString(String key) {
        Object v = map.get(key);
        return v instanceof String ? (String) v : null;
    }

    /** 取字符串（带默认值）。 */
    public String getString(String key, String defValue) {
        String v = getString(key);
        return v != null ? v : defValue;
    }

    /** 放 int。 */
    public void putInt(String key, int value) {
        map.put(key, value);
    }

    /** 取 int。 */
    public int getInt(String key, int defValue) {
        Object v = map.get(key);
        return v instanceof Integer ? (Integer) v : defValue;
    }

    /** 放 long。 */
    public void putLong(String key, long value) {
        map.put(key, value);
    }

    /** 取 long。 */
    public long getLong(String key, long defValue) {
        Object v = map.get(key);
        return v instanceof Long ? (Long) v : defValue;
    }

    /** 放 boolean。 */
    public void putBoolean(String key, boolean value) {
        map.put(key, value);
    }

    /** 取 boolean。 */
    public boolean getBoolean(String key, boolean defValue) {
        Object v = map.get(key);
        return v instanceof Boolean ? (Boolean) v : defValue;
    }

    /** 是否含 key。 */
    public boolean containsKey(String key) {
        return map.containsKey(key);
    }
}