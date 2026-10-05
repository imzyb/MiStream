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

    /**
     * 是否正在销毁 —— 恒 false。
     *
     * <p>源用它在异步回调里判断「界面还在不在，要不要更新 UI」。恒 false
     * 让源继续走正常分支；恒 true 会让它提前 return，把后面的业务逻辑
     * （包括取数据）一起跳过。
     */
    public boolean isDestroyed() {
        return false;
    }

    /**
     * 是否正在结束 —— 恒 false。
     *
     * <p>同 {@link #isDestroyed()}：恒 false 才让源把流程走完。
     */
    public boolean isFinishing() {
        return false;
    }

    /** 是否已暂停 —— 恒 false。 */
    public boolean isPaused() {
        return false;
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