package android.content;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;

/**
 * android.content.Context 的最小兼容 shim。
 *
 * csp_ 类的 {@code init(Context, String)} 会收到这个实例。jar 里的源通常只用它
 * 做：getApplicationContext / getSharedPreferences / getPackageName /
 * getFilesDir / getContentResolver。
 *
 * <p>补方法的判据是 {@code ShimGapScan}（见 SKILL.md），不要凭印象加。
 */
public abstract class Context {

    public static final int MODE_PRIVATE = 0;

    /** 内存共享偏好存储（模拟 SharedPreferences）。 */
    private final Map<String, SharedPreferences> prefs = new HashMap<>();

    /** 内容解析器（单例，与真实 Android 语义一致：同一个 Context 返回同一个实例）。 */
    private ContentResolver contentResolver;

    /** 资源表（固定值，见 {@link android.content.res.Resources}）。 */
    private android.content.res.Resources resources;

    /** 应用上下文（默认返回自身）。 */
    public Context getApplicationContext() {
        return this;
    }

    /** 包名。 */
    public String getPackageName() {
        return "io.mistream";
    }

    /** 文件目录。 */
    public File getFilesDir() {
        return new File(System.getProperty("java.io.tmpdir"), "mistream-jvm");
    }

    /** 缓存目录。 */
    public File getCacheDir() {
        return getFilesDir();
    }

    /** 读取共享偏好（内存实现）。 */
    public SharedPreferences getSharedPreferences(String name, int mode) {
        // 注意 `SharedPreferences` 是 interface（Android 语义），实例是 Impl。
        return prefs.computeIfAbsent(name, k -> new SharedPreferencesImpl());
    }

    /** 全局设置，等价于 getSharedPreferences 的一个固定名。 */
    public SharedPreferences getPreferences(int mode) {
        return getSharedPreferences("default", mode);
    }

    /**
     * 内容解析器。
     *
     * <p>这是本次补的**最高频**缺口：22 个 csp_ 源引用它，典型用法是
     * {@code Settings.Secure.getString(getContentResolver(), "android_id")}
     * 拿设备标识。缺了它会在调用点抛 NoSuchMethodError，整个源直接失效
     * （csp_AppDrama 就是这样挂的）。
     */
    public ContentResolver getContentResolver() {
        if (contentResolver == null) contentResolver = new ContentResolver(this);
        return contentResolver;
    }

    /**
     * 资源表。
     *
     * <p>返回固定对象而不是 null：源里常见 {@code getResources().getConfiguration()}
     * 这类链式调用，返回 null 会变成 NPE。
     */
    public android.content.res.Resources getResources() {
        if (resources == null) resources = new android.content.res.Resources();
        return resources;
    }

    /**
     * 启动 Activity —— 无操作。
     *
     * <p>源用它「唤起外部播放器」。无头运行时里没有界面可启动，吞掉即可；
     * 抛异常会让「先试着跳转、失败再走内置播放」的源直接断在这里。
     */
    public void startActivity(Intent intent) {
        // no-op
    }

    /** 发送广播（无操作）。 */
    public void sendBroadcast(Intent intent) {
        // no-op
    }

    /** 按名取系统服务（仅支持连接管理/包管理等占位）。 */
    public Object getSystemService(String name) {
        if (name.equals("connectivity")) {
            return new android.net.ConnectivityManager();
        }
        if (name.equals("package")) {
            return getPackageManager();
        }
        return null;
    }

    /** 包管理器。 */
    public PackageManager getPackageManager() {
        return new PackageManager();
    }

    /** 应用信息（占位）。 */
    public ApplicationInfo getApplicationInfo() {
        return new ApplicationInfo();
    }

    /** 权限检查（默认视为已授予）。 */
    public int checkCallingOrSelfPermission(String permission) {
        return 0; // PERMISSION_GRANTED
    }

    /** 权限检查（默认视为已授予）。 */
    public int checkSelfPermission(String permission) {
        return 0; // PERMISSION_GRANTED
    }
}