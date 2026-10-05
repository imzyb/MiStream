package android.content.res;

import android.util.DisplayMetrics;

/**
 * android.content.res.Resources 的最小兼容 shim。
 *
 * <p>真实 Android 上它负责资源查找（{@code getString(R.string.x)} 等）。
 * 无头运行时没有资源表，所以这里只提供**形状正确**的返回值：
 *
 * <ul>
 *   <li>{@link #getIdentifier} 一律返回 0（"找不到"）—— 这是真实语义里最安全的
 *       取值，源拿到 0 会走「没有这个资源」的分支，而不是拿到一个假 id 去
 *       {@code getString} 然后抛 NotFoundException。</li>
 *   <li>{@link #getConfiguration} / {@link #getDisplayMetrics} 返回固定对象，
 *       让源里读屏幕尺寸的分支能跑通。</li>
 * </ul>
 */
public class Resources {

    private final Configuration configuration = new Configuration();
    private final DisplayMetrics metrics = new DisplayMetrics();

    public Resources() {
    }

    /** 当前配置（固定竖屏浅色）。 */
    public Configuration getConfiguration() {
        return configuration;
    }

    /** 显示指标（固定 1080x1920 mdpi）。 */
    public DisplayMetrics getDisplayMetrics() {
        return metrics;
    }

    /**
     * 按名查资源 id。
     *
     * <p>恒返回 0 = 未找到。真实 Android 找不到时也是 0，所以这是语义正确的。
     */
    public int getIdentifier(String name, String defType, String defPackage) {
        return 0;
    }

    /** 取字符串资源：无资源表，返回 null 让调用方自己兜底。 */
    public String getString(int id) {
        return null;
    }

    /** 取字符串资源（带格式化参数）。 */
    public String getString(int id, Object... formatArgs) {
        return null;
    }

    /** 取尺寸。 */
    public float getDimension(int id) {
        return 0f;
    }

    /** 取像素尺寸。 */
    public int getDimensionPixelSize(int id) {
        return 0;
    }

    /** 取颜色：返回不透明黑，避免 0（全透明）让 UI 分支拿到意外值。 */
    public int getColor(int id) {
        return 0xFF000000;
    }
}
