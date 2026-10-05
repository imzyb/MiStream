package android.content.pm;

/**
 * android.content.pm.ResolveInfo 的最小兼容 shim。
 *
 * <p>源用它判断「某个 Intent 有没有 App 能处理」（例如判断设备上装没装某个
 * 视频客户端）。无头运行时里没有 App，所以 {@code resolveActivity} 会返回
 * {@code null} —— 那是真实语义里的「没有匹配项」，源会走兜底分支。
 *
 * <p>本类只在源**真的拿到了**一个 ResolveInfo（比如自己 new 出来的）时才被实例化，
 * 所以字段要齐、不要为 null。
 */
public class ResolveInfo {

    /** 匹配到的 Activity 信息。 */
    public ActivityInfo activityInfo;
    /** 匹配到的 Service 信息（占位）。 */
    public ServiceInfo serviceInfo;
    /** 匹配到的 provider 信息。 */
    public ProviderInfo providerInfo;
    /** 优先级。 */
    public int priority;
    /** 是否默认。 */
    public boolean isDefault;
    /** 匹配到的过滤器。 */
    public IntentFilter filter;

    public ResolveInfo() {
    }

    /** 取标签。 */
    public CharSequence loadLabel(PackageManager pm) {
        if (activityInfo != null) return activityInfo.loadLabel(pm);
        if (providerInfo != null) return providerInfo.loadLabel(pm);
        return "";
    }

    /** Activity 信息（占位）。 */
    public static class ActivityInfo extends PackageItemInfo {
        /** 主题资源 id。 */
        public int theme;
        /** 是否可导出。 */
        public boolean exported;
    }

    /** Service 信息（占位）。 */
    public static class ServiceInfo extends PackageItemInfo {
    }

    /** Intent 过滤器（占位）。 */
    public static class IntentFilter {
    }
}
