package android.text;

import java.util.Iterator;

/**
 * android.text.TextUtils 的最小兼容 shim。
 *
 * 只实现真实 jar 里 csp_ 类用到的静态方法。B1 扫描确认核心源用到：
 * isEmpty / join。其余方法在需要时按 NoClassDefFoundError 驱动补全。
 */
public final class TextUtils {

    private TextUtils() {
    }

    /** 判断 CharSequence 为空或长度为 0。 */
    public static boolean isEmpty(CharSequence str) {
        return str == null || str.length() == 0;
    }

    /** 判断 CharSequence 为 null 或全空白。 */
    public static boolean isBlank(CharSequence str) {
        if (str == null) return true;
        for (int i = 0; i < str.length(); i++) {
            if (!Character.isWhitespace(str.charAt(i))) return false;
        }
        return true;
    }

    /** 用分隔符连接可迭代对象（String 版本）。 */
    public static String join(CharSequence delimiter, Iterable<?> tokens) {
        StringBuilder sb = new StringBuilder();
        Iterator<?> it = tokens.iterator();
        if (it.hasNext()) {
            sb.append(it.next());
            while (it.hasNext()) {
                sb.append(delimiter).append(it.next());
            }
        }
        return sb.toString();
    }

    /** 用分隔符连接对象数组。 */
    public static String join(CharSequence delimiter, Object[] tokens) {
        StringBuilder sb = new StringBuilder();
        if (tokens != null) {
            for (int i = 0; i < tokens.length; i++) {
                if (i > 0) sb.append(delimiter);
                sb.append(tokens[i]);
            }
        }
        return sb.toString();
    }

    /** 字符串值，null 返回 ""。 */
    public static String nullIfEmpty(String str) {
        return isEmpty(str) ? null : str;
    }
}