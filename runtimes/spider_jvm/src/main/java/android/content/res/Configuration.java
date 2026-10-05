package android.content.res;

/**
 * android.content.res.Configuration 的最小兼容 shim。
 *
 * <p>csp_ 源用它判断屏幕方向 / 深色模式做分支。这里固定报「竖屏 + 普通浅色」，
 * 这是无头运行时最中性的取值 —— 很多源的深色分支会去改 UI 配色，无头下没必要走。
 */
public class Configuration {

    /** 竖屏。 */
    public static final int ORIENTATION_PORTRAIT = 1;
    /** 横屏。 */
    public static final int ORIENTATION_LANDSCAPE = 2;
    /** 未定义。 */
    public static final int ORIENTATION_UNDEFINED = 0;

    /** UI 模式：普通。 */
    public static final int UI_MODE_TYPE_NORMAL = 0x01;
    /** UI 模式：浅色。 */
    public static final int UI_MODE_NIGHT_NO = 0x10;
    /** UI 模式：深色。 */
    public static final int UI_MODE_NIGHT_YES = 0x20;
    /** UI 模式：未定义。 */
    public static final int UI_MODE_NIGHT_UNDEFINED = 0x00;

    /** 屏幕方向。 */
    public int orientation = ORIENTATION_PORTRAIT;
    /** UI 模式位。 */
    public int uiMode = UI_MODE_TYPE_NORMAL | UI_MODE_NIGHT_NO;

    /** 屏幕宽度（dp）。 */
    public int screenWidthDp = 411;
    /** 屏幕高度（dp）。 */
    public int screenHeightDp = 869;
    /** 最小宽度（dp）。 */
    public int smallestScreenWidthDp = 411;
    /** 密度 dpi。 */
    public int densityDpi = 160;
    /** 语言/地区。 */
    public java.util.Locale locale = java.util.Locale.CHINA;

    public Configuration() {
    }

    /** 是否深色模式。 */
    public boolean isNightModeActive() {
        return (uiMode & UI_MODE_NIGHT_YES) == UI_MODE_NIGHT_YES;
    }
}
