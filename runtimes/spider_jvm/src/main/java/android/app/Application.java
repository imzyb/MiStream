package android.app;

import android.content.Context;
import android.os.Bundle;

import java.util.concurrent.CopyOnWriteArrayList;

/**
 * android.app.Application 的最小兼容 shim。
 *
 * <p>Init 持有 Application 字段并传给 merge 网络层。本类继承 {@link Context}
 * 拿到目录/包名等能力，另外补上 {@link #registerActivityLifecycleCallbacks}
 * —— 这是本次按 {@code ShimGapScan} 补的缺口，被 5 个源引用。
 */
public class Application extends Context {

    /** 已注册的生命周期回调（无头运行时不会被触发，但要能注册成功）。 */
    private final CopyOnWriteArrayList<ActivityLifecycleCallbacks> callbacks =
            new CopyOnWriteArrayList<>();

    public Application() {
    }

    /**
     * 注册 Activity 生命周期回调 —— 只记录，不触发。
     *
     * <p>无头运行时里没有 Activity 生命周期，所以回调永远不会被调用。但方法
     * 本身必须存在且不抛异常：源通常在 {@code onCreate} 里注册，缺了它整个
     * 源的初始化就会中断。
     */
    public void registerActivityLifecycleCallbacks(ActivityLifecycleCallbacks callback) {
        if (callback != null) callbacks.addIfAbsent(callback);
    }

    /** 反注册。 */
    public void unregisterActivityLifecycleCallbacks(ActivityLifecycleCallbacks callback) {
        callbacks.remove(callback);
    }

    /**
     * Activity 生命周期回调接口。
     *
     * <p>方法集合按 API 33 的完整定义给全，包括 {@code pre*} / {@code post*}
     * 那批 **default** 方法。原因：jar 里的实现类是按真实 Android SDK 编译的，
     * 如果它只实现了 7 个基础方法、而某个 pre/post 方法在本接口里不是 default，
     * 那个类就会被判定成抽象类，实例化时抛 InstantiationError。
     * 声明成 default 是唯一两头都安全的选择。
     */
    public interface ActivityLifecycleCallbacks {

        /** Activity 创建。 */
        void onActivityCreated(Activity activity, Bundle savedInstanceState);

        /** Activity 启动。 */
        void onActivityStarted(Activity activity);

        /** Activity 可见。 */
        void onActivityResumed(Activity activity);

        /** Activity 失去焦点。 */
        void onActivityPaused(Activity activity);

        /** Activity 停止。 */
        void onActivityStopped(Activity activity);

        /** 保存状态。 */
        void onActivitySaveInstanceState(Activity activity, Bundle outState);

        /** Activity 销毁。 */
        void onActivityDestroyed(Activity activity);

        /** 创建前（API 29+，default）。 */
        default void onActivityPreCreated(Activity activity, Bundle savedInstanceState) {
        }

        /** 创建后（API 29+，default）。 */
        default void onActivityPostCreated(Activity activity, Bundle savedInstanceState) {
        }

        /** 启动前（API 29+，default）。 */
        default void onActivityPreStarted(Activity activity) {
        }

        /** 启动后（API 29+，default）。 */
        default void onActivityPostStarted(Activity activity) {
        }

        /** 可见前（API 29+，default）。 */
        default void onActivityPreResumed(Activity activity) {
        }

        /** 可见后（API 29+，default）。 */
        default void onActivityPostResumed(Activity activity) {
        }

        /** 暂停前（API 29+，default）。 */
        default void onActivityPrePaused(Activity activity) {
        }

        /** 暂停后（API 29+，default）。 */
        default void onActivityPostPaused(Activity activity) {
        }

        /** 停止前（API 29+，default）。 */
        default void onActivityPreStopped(Activity activity) {
        }

        /** 停止后（API 29+，default）。 */
        default void onActivityPostStopped(Activity activity) {
        }

        /** 保存状态前（API 29+，default）。 */
        default void onActivityPreSaveInstanceState(Activity activity, Bundle outState) {
        }

        /** 保存状态后（API 29+，default）。 */
        default void onActivityPostSaveInstanceState(Activity activity, Bundle outState) {
        }

        /** 销毁前（API 29+，default）。 */
        default void onActivityPreDestroyed(Activity activity) {
        }

        /** 销毁后（API 29+，default）。 */
        default void onActivityPostDestroyed(Activity activity) {
        }
    }
}
