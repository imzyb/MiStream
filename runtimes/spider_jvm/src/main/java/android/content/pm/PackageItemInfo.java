package android.content.pm;

/**
 * android.content.pm.PackageItemInfo 的最小兼容 shim。
 *
 * <p>真实 Android 上它是 {@link ApplicationInfo} / {@code ActivityInfo} /
 * {@link ProviderInfo} 等的公共父类，承载 {@code packageName} 与「取标签/图标」
 * 这类能力。
 *
 * <p>{@link #loadXmlMetaData} 返回 {@code null} 而不是抛异常：源用它读自己
 * manifest 里的 meta-data（通常是 API key），拿不到时几乎都会走「用内置默认值」
 * 的分支。让它抛异常会把一个可恢复的情况变成整站失败。
 */
public class PackageItemInfo {

    /** 所属包名。 */
    public String packageName;
    /** 条目名。 */
    public String name;
    /** 标签资源 id（0 = 无）。 */
    public int labelRes;
    /** 图标资源 id（0 = 无）。 */
    public int icon;
    /** 是否可用。 */
    public boolean enabled = true;

    public PackageItemInfo() {
    }

    /** 取显示标签：没有 packageName 时返回空串，绝不返回 null。 */
    public CharSequence loadLabel(PackageManager pm) {
        return packageName == null ? "" : packageName;
    }

    /** 取图标：无资源表，返回 null。 */
    public android.graphics.drawable.Drawable loadIcon(PackageManager pm) {
        return null;
    }

    /** 读 manifest meta-data：无资源表，恒返回 null。 */
    public android.content.res.XmlResourceParser loadXmlMetaData(PackageManager pm, String name) {
        return null;
    }

    @Override
    public String toString() {
        return getClass().getSimpleName() + "{" + packageName + "/" + name + "}";
    }
}
