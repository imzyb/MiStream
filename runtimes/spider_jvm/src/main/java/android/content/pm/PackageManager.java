package android.content.pm;

/**
 * android.content.pm.PackageManager 的最小兼容 shim。
 *
 * <p>无头运行时里没有真实的包管理系统，所以「查别的 App」一律返回
 * {@code null}（= 没装），这是真实语义里最保守、也是源能正确处理的取值：
 * 源拿到 null 会走「本机没装这个客户端」的分支，而编造一个假 App 会让它
 * 去拉起一个根本不存在的组件。
 *
 * <p>唯独「查自己」({@link #getPackageInfo}) 返回一个**有内容的**对象 ——
 * 源读自己的版本号/签名塞进请求头是常见刚需。
 */
public class PackageManager {

    /** 取 meta-data。 */
    public static final int GET_META_DATA = 0x80;
    /** 取 Activity 信息。 */
    public static final int GET_ACTIVITIES = 0x00000001;
    /** 取 Service 信息。 */
    public static final int GET_SERVICES = 0x00000004;
    /** 取 Provider 信息。 */
    public static final int GET_PROVIDERS = 0x00000008;
    /** 匹配默认项。 */
    public static final int MATCH_DEFAULT_ONLY = 0x00010000;
    /** 解析所有匹配项。 */
    public static final int MATCH_ALL = 0x00020000;

    /** 本运行时自报的包名。 */
    private static final String SELF_PACKAGE = "io.mistream";

    public PackageManager() {
    }

    /** 按包名查应用信息（恒返回占位，不做真实查询）。 */
    public ApplicationInfo getApplicationInfo(String packageName, int flags) {
        ApplicationInfo info = new ApplicationInfo();
        info.packageName = packageName == null ? "" : packageName;
        return info;
    }

    /** 应用标签。 */
    public CharSequence getApplicationLabel(ApplicationInfo info) {
        return info == null ? "" : info.packageName;
    }

    /** 应用图标（无资源表，返回 null）。 */
    public android.graphics.drawable.Drawable getApplicationIcon(String packageName) {
        return null;
    }

    /**
     * 查包信息。
     *
     * <p>无论查谁都返回一个**有内容**的对象（包名按入参回填）。这样源读
     * {@code versionName} / {@code signatures} 时拿到的是稳定值而不是 NPE。
     */
    public PackageInfo getPackageInfo(String packageName, int flags) {
        PackageInfo info = new PackageInfo();
        info.packageName = (packageName == null || packageName.isEmpty())
                ? SELF_PACKAGE : packageName;
        info.applicationInfo.packageName = info.packageName;
        return info;
    }

    /**
     * 取某包的启动 Intent —— 恒返回 {@code null}。
     *
     * <p>语义 = 「本机没装这个 App」。源拿到 null 会走兜底分支（通常是直接
     * 用内置播放器），比返回一个假 Intent 去拉起不存在的组件安全得多。
     */
    public android.content.Intent getLaunchIntentForPackage(String packageName) {
        return null;
    }

    /**
     * 解析 Intent 的匹配 Activity —— 恒返回 {@code null}（无界面可匹配）。
     */
    public ResolveInfo resolveActivity(android.content.Intent intent, int flags) {
        return null;
    }

    /**
     * 解析 content provider —— 恒返回 {@code null}（无 provider）。
     */
    public ProviderInfo resolveContentProvider(String authority, int flags) {
        return null;
    }

    /**
     * 是否支持某系统特性 —— 恒返回 {@code false}。
     *
     * <p>恒 false 是安全方向：源里 {@code hasSystemFeature("android.hardware.touchscreen")}
     * 之类的判断拿到 false 会走「精简/无头」分支，正好符合我们的运行形态。
     */
    public boolean hasSystemFeature(String name) {
        return false;
    }

    /**
     * 包不存在异常。
     *
     * <p>jar 里大量源写了 {@code catch (NameNotFoundException e)}。异常表里的
     * catch 类型必须在验证期就能解析到，所以这个类**必须存在**，哪怕我们
     * 从不抛它。
     */
    public static class NameNotFoundException extends Exception {
        private static final long serialVersionUID = 1L;

        public NameNotFoundException() {
            super();
        }

        public NameNotFoundException(String name) {
            super(name);
        }
    }
}
