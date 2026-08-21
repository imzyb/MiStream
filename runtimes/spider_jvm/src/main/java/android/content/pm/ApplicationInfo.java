package android.content.pm;

/**
 * android.content.pm.ApplicationInfo 的最小兼容 shim。
 *
 * Init 读取 targetSdkVersion 等字段。这里提供常见字段占位。
 */
public class ApplicationInfo {

    public String packageName;
    public int targetSdkVersion;
    public String sourceDir;

    public ApplicationInfo() {
    }

    public CharSequence loadLabel(android.content.pm.PackageManager pm) {
        return packageName == null ? "" : packageName;
    }
}