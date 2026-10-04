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
 * getFilesDir。这里提供无副作用的内存实现。
 */
public abstract class Context {

    public static final int MODE_PRIVATE = 0;

    /** 内存共享偏好存储（模拟 SharedPreferences）。 */
    private final Map<String, SharedPreferences> prefs = new HashMap<>();

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
        return prefs.computeIfAbsent(name, k -> new SharedPreferences());
    }

    /** 全局设置，等价于 getSharedPreferences 的一个固定名。 */
    public SharedPreferences getPreferences(int mode) {
        return getSharedPreferences("default", mode);
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