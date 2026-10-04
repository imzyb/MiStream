package android.content.pm;

/**
 * android.content.pm.PackageManager 的最小兼容 shim。
 *
 * Init 用 getApplicationInfo / getApplicationLabel。返回占位值。
 */
public class PackageManager {

    public static final int GET_META_DATA = 0x80;

    public PackageManager() {
    }

    /** 按包名查应用信息（不解析真实系统，返回占位）。 */
    public ApplicationInfo getApplicationInfo(String packageName, int flags) {
        ApplicationInfo info = new ApplicationInfo();
        info.packageName = packageName == null ? "" : packageName;
        info.targetSdkVersion = 33;
        return info;
    }

    /** 应用标签。 */
    public CharSequence getApplicationLabel(ApplicationInfo info) {
        return info == null ? "" : info.packageName;
    }

    /** 应用图标占位（返回空字符串资源名）。 */
    public android.graphics.drawable.Drawable getApplicationIcon(String packageName) {
        return null;
    }
}