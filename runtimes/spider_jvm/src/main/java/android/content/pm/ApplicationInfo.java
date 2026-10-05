package android.content.pm;

/**
 * android.content.pm.ApplicationInfo 的最小兼容 shim。
 *
 * <p>与真实 Android 一致，继承 {@link PackageItemInfo}（{@code packageName}、
 * {@code loadLabel}、{@code loadXmlMetaData} 都从父类来）。
 *
 * <p>本类只保留源真正读得到的字段。字段值刻意**非 null / 非 0**：源常把
 * {@code targetSdkVersion} 塞进请求头做版本协商，0 会被服务端当成远古客户端
 * 而返回降级（甚至错误）响应。
 */
public class ApplicationInfo extends PackageItemInfo {

    /** 目标 SDK。报 33（Android 13），与 {@code Build.VERSION.SDK_INT} 保持一致。 */
    public int targetSdkVersion = 33;

    /** 最低 SDK。 */
    public int minSdkVersion = 21;

    /** banner 资源 id（0 = 无；源读它是为了 UI，无头下用不到）。 */
    public int banner;

    /** 应用名资源 id。 */
    public int labelRes;

    /** APK 路径（无 APK，给一个稳定的假路径）。 */
    public String sourceDir = "/data/app/io.mistream/base.apk";

    /** 数据目录。 */
    public String dataDir;

    /** 是否系统应用。 */
    public boolean system;

    /** 是否可调试。 */
    public boolean debuggable;

    public ApplicationInfo() {
        this.packageName = "io.mistream";
    }
}
