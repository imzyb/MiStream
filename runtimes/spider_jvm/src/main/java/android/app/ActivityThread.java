package android.app;

import java.util.Collections;
import java.util.Map;

/**
 * android.app.ActivityThread 的最小兼容 shim。
 *
 * Init.getActivity 用反射调用 currentActivityThread() 并读取 mActivities 字段，
 * 迭代其中未暂停的 Activity。空 Map 使循环不执行，getActivity 返回 null，
 * 从而 checkPermission 直接返回。
 */
public class ActivityThread {

    /** mActivities（占位，空集合使 Init.getActivity 返回 null）。 */
    public final Map<Object, Object> mActivities = Collections.emptyMap();

    /** 当前线程（占位）。 */
    public static ActivityThread currentActivityThread() {
        return new ActivityThread();
    }
}