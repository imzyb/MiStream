package android.util;

/**
 * android.util.DisplayMetrics 的最小兼容 shim。
 *
 * <p>源用它做 dp/px 换算与屏幕尺寸判断。这里固定报一块 1080x1920 的 mdpi 屏幕
 * （{@code density = 1.0}），使 {@code applyDimension} 的换算保持恒等 —— 源算出来的
 * 像素值就是它写的 dp 值，不会因为密度不对而算出离谱尺寸。
 */
public class DisplayMetrics {

    /** 密度标识：低。 */
    public static final int DENSITY_LOW = 120;
    /** 密度标识：中。 */
    public static final int DENSITY_MEDIUM = 160;
    /** 密度标识：高。 */
    public static final int DENSITY_HIGH = 240;
    /** 密度标识：超高。 */
    public static final int DENSITY_XHIGH = 320;
    /** 密度标识：默认。 */
    public static final int DENSITY_DEFAULT = DENSITY_MEDIUM;

    /** 密度系数。 */
    public float density = 1.0f;
    /** 字体缩放后的密度。 */
    public float scaledDensity = 1.0f;
    /** 密度 dpi。 */
    public int densityDpi = DENSITY_MEDIUM;
    /** 宽（px）。 */
    public int widthPixels = 1080;
    /** 高（px）。 */
    public int heightPixels = 1920;
    /** x 轴物理 dpi。 */
    public float xdpi = 160f;
    /** y 轴物理 dpi。 */
    public float ydpi = 160f;

    public DisplayMetrics() {
    }

    /** 拷贝另一个指标对象。 */
    public void setTo(DisplayMetrics other) {
        if (other == null) return;
        this.density = other.density;
        this.scaledDensity = other.scaledDensity;
        this.densityDpi = other.densityDpi;
        this.widthPixels = other.widthPixels;
        this.heightPixels = other.heightPixels;
        this.xdpi = other.xdpi;
        this.ydpi = other.ydpi;
    }
}
