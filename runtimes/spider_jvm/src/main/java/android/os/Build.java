package android.os;

/**
 * android.os.Build 的最小兼容 shim。
 *
 * csp_ 源常用 Build.VERSION.SDK_INT 判断 Android 版本做兼容分支。这里固定报一个
 * 较高的 SDK 值，让源走新路径。
 */
public final class Build {

    private Build() {
    }

    /** 版本信息。 */
    public static final class VERSION {
        /** 模拟 Android 13。 */
        public static final int SDK_INT = 33;
        /** 版本号。 */
        public static final String RELEASE = "13";

        private VERSION() {
        }
    }

    /** 品牌。 */
    public static final String BRAND = "mistream";
    /** 型号。 */
    public static final String MODEL = "PC";
    /** 制造商。 */
    public static final String MANUFACTURER = "mistream";
    /** 设备。 */
    public static final String DEVICE = "x86_64";
    /** 产品。 */
    public static final String PRODUCT = "mistream_pc";
    /** 硬件。 */
    public static final String HARDWARE = "pc";
    /** Android ID。 */
    public static final String FINGERPRINT = "mistream/pc:13/x86_64";
    /** 架构。 */
    public static final String SUPPORTED_ABIS[] = {"x86_64", "x86"};
}