package android.app;

import android.content.ComponentName;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;

/**
 * android.app.Activity 的最小兼容 shim。
 *
 * Init 用 Activity.getComponentName / finish / checkSelfPermission /
 * requestPermissions。继承 Context 提供其余能力。
 */
public class Activity extends Context {

    public Activity() {
    }

    /** 组件名（占位）。 */
    public ComponentName getComponentName() {
        return new ComponentName(getPackageName(), getClass().getName());
    }

    /** 关闭页面（无操作）。 */
    public void finish() {
        // no-op
    }

    /** 检查权限（默认视为已授予）。 */
    public int checkSelfPermission(String permission) {
        return 0; // PERMISSION_GRANTED
    }

    /** 请求权限（无操作）。 */
    public void requestPermissions(String[] permissions, int requestCode) {
        // no-op
    }

    @Override
    public PackageManager getPackageManager() {
        return new PackageManager();
    }

    @Override
    public ApplicationInfo getApplicationInfo() {
        return new ApplicationInfo();
    }

    /** 当前 Activity（占位，无真实界面）。 */
    public static Activity getActivity() {
        return null;
    }
}