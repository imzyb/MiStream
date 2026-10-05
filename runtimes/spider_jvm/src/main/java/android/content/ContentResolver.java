package android.content;

/**
 * android.content.ContentResolver 的最小兼容 shim。
 *
 * <p>真实 Android 里它是抽象类，通过 {@link Context#getContentResolver()} 拿到，
 * 用来读写 {@code content://} 提供者的数据。csp_ 源里最常见的用法只有一个：
 *
 * <pre>
 * String androidId = Settings.Secure.getString(
 *         Init.context().getContentResolver(), "android_id");
 * </pre>
 *
 * <p>本 shim 只当一个不透明的句柄（给 {@code android.provider.Settings.Secure}
 * 用），不实现任何 provider 访问。如果将来某个源真的要查 content:// 数据，
 * 应该在这里加白名单实现，而不是让调用方拿到 null —— 拿到 null 会变成
 * NullPointerException，比 NoSuchMethodError 更难定位。
 */
public class ContentResolver {

    private final Context context;

    public ContentResolver(Context context) {
        this.context = context;
    }

    /** 反查创建它的 Context。 */
    public Context getContext() {
        return context;
    }
}
