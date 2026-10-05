package android.content;

import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * {@link SharedPreferences} 的内存实现 —— 进程生命周期内有效，不落盘。
 *
 * <p>拆出来单独一个类是因为 {@link SharedPreferences} 必须保持 interface
 * （见那边的注释）：接口里放不了实例状态。
 *
 * <p>语义刻意对齐 Android 的几个容易踩的点：
 * <ul>
 *   <li>{@code commit()} 才真正写入；{@code apply()} 等价于同步 {@code commit()}
 *       （Android 是异步落盘，这里没有盘，同步最不容易出意外）。</li>
 *   <li>写入 {@code null} 值等于删除该 key（Android 的 {@code putString(k, null)}
 *       就是这么定义的），所以内部用 {@code remove} 而不是存 null。</li>
 *   <li>{@code clear()} 之后再 {@code put*} 是「先清后写」，顺序不能反。</li>
 * </ul>
 */
final class SharedPreferencesImpl implements SharedPreferences {

    private final Map<String, Object> data = new ConcurrentHashMap<>();

    private final CopyOnWriteArrayList<OnSharedPreferenceChangeListener> listeners =
            new CopyOnWriteArrayList<>();

    @Override
    public Map<String, ?> getAll() {
        return Collections.unmodifiableMap(new HashMap<>(data));
    }

    @Override
    public String getString(String key, String defValue) {
        Object v = data.get(key);
        return v instanceof String ? (String) v : defValue;
    }

    @Override
    @SuppressWarnings("unchecked")
    public Set<String> getStringSet(String key, Set<String> defValues) {
        Object v = data.get(key);
        if (!(v instanceof Set)) return defValues;
        return new LinkedHashSet<>((Set<String>) v);
    }

    @Override
    public int getInt(String key, int defValue) {
        Object v = data.get(key);
        return v instanceof Integer ? (Integer) v : defValue;
    }

    @Override
    public long getLong(String key, long defValue) {
        Object v = data.get(key);
        return v instanceof Long ? (Long) v : defValue;
    }

    @Override
    public float getFloat(String key, float defValue) {
        Object v = data.get(key);
        return v instanceof Float ? (Float) v : defValue;
    }

    @Override
    public boolean getBoolean(String key, boolean defValue) {
        Object v = data.get(key);
        return v instanceof Boolean ? (Boolean) v : defValue;
    }

    @Override
    public boolean contains(String key) {
        return data.containsKey(key);
    }

    @Override
    public Editor edit() {
        return new EditorImpl();
    }

    @Override
    public void registerOnSharedPreferenceChangeListener(
            OnSharedPreferenceChangeListener listener) {
        if (listener != null) listeners.addIfAbsent(listener);
    }

    @Override
    public void unregisterOnSharedPreferenceChangeListener(
            OnSharedPreferenceChangeListener listener) {
        listeners.remove(listener);
    }

    /** 编辑器实现：改动先攒在 pending 里，commit 时一次性落地。 */
    private final class EditorImpl implements Editor {

        private final Map<String, Object> pending = new ConcurrentHashMap<>();

        private final Set<String> removed = ConcurrentHashMap.newKeySet();

        private boolean clearRequested;

        private Editor put(String key, Object value) {
            if (key == null) return this;
            if (value == null) return remove(key);
            removed.remove(key);
            pending.put(key, value);
            return this;
        }

        @Override
        public Editor putString(String key, String value) {
            return put(key, value);
        }

        @Override
        public Editor putStringSet(String key, Set<String> values) {
            return put(key, values == null ? null : new HashSet<>(values));
        }

        @Override
        public Editor putInt(String key, int value) {
            return put(key, value);
        }

        @Override
        public Editor putLong(String key, long value) {
            return put(key, value);
        }

        @Override
        public Editor putFloat(String key, float value) {
            return put(key, value);
        }

        @Override
        public Editor putBoolean(String key, boolean value) {
            return put(key, value);
        }

        @Override
        public Editor remove(String key) {
            if (key == null) return this;
            pending.remove(key);
            removed.add(key);
            return this;
        }

        @Override
        public Editor clear() {
            clearRequested = true;
            return this;
        }

        @Override
        public boolean commit() {
            if (clearRequested) {
                data.clear();
                clearRequested = false;
            }
            data.keySet().removeAll(removed);
            removed.clear();
            data.putAll(pending);
            final Set<String> touched = new HashSet<>(pending.keySet());
            pending.clear();
            for (OnSharedPreferenceChangeListener listener : listeners) {
                for (String key : touched) {
                    listener.onSharedPreferenceChanged(SharedPreferencesImpl.this, key);
                }
            }
            return true;
        }

        @Override
        public void apply() {
            commit();
        }
    }
}
