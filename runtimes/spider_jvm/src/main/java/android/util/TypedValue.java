package android.util;

/**
 * android.util.TypedValue 的最小兼容 shim。
 *
 * <p>只实现源真正用到的 {@link #applyDimension}：把 dp/sp/pt/in/mm 换算成 px。
 * 换算公式与真实 Android 完全一致 —— 这类数值计算如果算错，源的 UI 尺寸分支
 * 会走偏，比直接报错更难查。
 */
public class TypedValue {

    /** 单位：原始像素。 */
    public static final int COMPLEX_UNIT_PX = 0;
    /** 单位：dp（dip）。 */
    public static final int COMPLEX_UNIT_DIP = 1;
    /** 单位：sp。 */
    public static final int COMPLEX_UNIT_SP = 2;
    /** 单位：pt。 */
    public static final int COMPLEX_UNIT_PT = 3;
    /** 单位：in。 */
    public static final int COMPLEX_UNIT_IN = 4;
    /** 单位：mm。 */
    public static final int COMPLEX_UNIT_MM = 5;

    /** 1 英寸 = 72 磅。 */
    private static final float PT_PER_INCH = 72f;
    /** 1 英寸 = 25.4 毫米。 */
    private static final float MM_PER_INCH = 25.4f;

    public TypedValue() {
    }

    /**
     * 把带单位的值换算成像素。
     *
     * @param unit    单位常量（{@code COMPLEX_UNIT_*}）
     * @param value   数值
     * @param metrics 显示指标；为 null 时退化成 1.0 密度
     * @return 像素值
     */
    public static float applyDimension(int unit, float value, DisplayMetrics metrics) {
        if (metrics == null) metrics = new DisplayMetrics();
        switch (unit) {
            case COMPLEX_UNIT_PX:
                return value;
            case COMPLEX_UNIT_DIP:
                return value * metrics.density;
            case COMPLEX_UNIT_SP:
                return value * metrics.scaledDensity;
            case COMPLEX_UNIT_PT:
                return value * metrics.xdpi * (1f / PT_PER_INCH);
            case COMPLEX_UNIT_IN:
                return value * metrics.xdpi;
            case COMPLEX_UNIT_MM:
                return value * metrics.xdpi * (1f / MM_PER_INCH);
            default:
                return value;
        }
    }
}
