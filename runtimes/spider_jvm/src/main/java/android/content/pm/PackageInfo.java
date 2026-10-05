package android.content.pm;

/**
 * android.content.pm.PackageInfo 的最小兼容 shim。
 *
 * <p>源用它读版本号（{@code versionName} / {@code versionCode}）与签名。
 * 版本号是真实存在的语义需求 —— 源常把 versionName 塞进请求头让服务端判断
 * 客户端版本。这里给一组固定的、看起来正常的版本值，而不是 null。
 */
public class PackageInfo {

    /** 取签名标志（旧）。 */
    public static final int GET_SIGNATURES = 0x00000040;
    /** 取签名标志（新）。 */
    public static final int GET_SIGNING_CERTIFICATES = 0x08000000;

    /** 包名。 */
    public String packageName;
    /** 版本名。 */
    public String versionName;
    /** 版本号。 */
    public int versionCode;
    /** 首次安装时间（毫秒）。 */
    public long firstInstallTime;
    /** 最后更新时间（毫秒）。 */
    public long lastUpdateTime;
    /** 签名数组（旧字段）。 */
    public Signature[] signatures;
    /** 应用信息。 */
    public ApplicationInfo applicationInfo;

    public PackageInfo() {
        this.packageName = "io.mistream";
        this.versionName = "1.0.0";
        this.versionCode = 1;
        this.signatures = new Signature[] {Signature.placeholder()};
        this.applicationInfo = new ApplicationInfo();
    }
}
