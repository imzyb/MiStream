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
    /**
     * 版本标识串。
     *
     * <p>源常把它拼进 User-Agent 或请求参数做设备指纹。必须非 null ——
     * 很多源是 {@code "..." + Build.ID + "..."} 这种直接拼接，null 会拼出
     * 字面量 {@code "null"} 混进参数里，让服务端判定参数非法。
     */
    public static final String ID = "MISTREAM.20240101.001";
    /** 显示名（用户可见的版本串）。 */
    public static final String DISPLAY = ID;
    /** 宿主名。 */
    public static final String HOST = "mistream";
    /** 编译标签。 */
    public static final String TAGS = "release-keys";
    /** 构建类型。 */
    public static final String TYPE = "user";
    /** 启动加载器版本。 */
    public static final String BOOTLOADER = "unknown";
    /** 主板。 */
    public static final String BOARD = "mistream";
    /** 序列号（Android 10+ 已不可读）。 */
    public static final String SERIAL = "unknown";
    /** 架构。 */
    public static final String SUPPORTED_ABIS[] = {"x86_64", "x86"};
    /** 32 位架构。 */
    public static final String SUPPORTED_32_BIT_ABIS[] = {"x86"};
    /** 64 位架构。 */
    public static final String SUPPORTED_64_BIT_ABIS[] = {"x86_64"};
    /** CPU 架构（旧字段）。 */
    public static final String CPU_ABI = "x86_64";
    /** CPU 架构 2（旧字段）。 */
    public static final String CPU_ABI2 = "x86";
}