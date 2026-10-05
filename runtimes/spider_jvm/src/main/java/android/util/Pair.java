package android.util;

import java.util.Objects;

/**
 * android.util.Pair 的最小兼容 shim。
 *
 * <p>与真实 Android 一致：字段是 {@code public final}，直接读不经过 getter。
 * 源里常见写法是 {@code for (Pair<String,String> p : list) use(p.first, p.second);}。
 */
public class Pair<F, S> {

    /** 第一个元素。 */
    public final F first;
    /** 第二个元素。 */
    public final S second;

    public Pair(F first, S second) {
        this.first = first;
        this.second = second;
    }

    /** 静态工厂，等价于构造器。 */
    public static <A, B> Pair<A, B> create(A a, B b) {
        return new Pair<>(a, b);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Pair)) return false;
        Pair<?, ?> p = (Pair<?, ?>) o;
        return Objects.equals(first, p.first) && Objects.equals(second, p.second);
    }

    @Override
    public int hashCode() {
        return Objects.hashCode(first) ^ Objects.hashCode(second);
    }

    @Override
    public String toString() {
        return "Pair{" + first + ", " + second + "}";
    }
}
