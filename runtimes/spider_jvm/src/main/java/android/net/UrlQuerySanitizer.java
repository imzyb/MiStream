package android.net;

import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * android.net.UrlQuerySanitizer 的最小兼容 shim。
 *
 * <p>源用它从 URL 里取查询参数（常见于「解析自己拼出来的接口地址」）。构造时
 * 传入完整 URL，之后 {@link #getValue(String)} 取值。
 *
 * <p>实现直接复用 {@link Uri} 的解析：Uri 的解析已经处理了 android 那套宽松语义，
 * 再抄一份只会让两处行为漂移。解析在构造时一次性完成，之后是纯读。
 */
public class UrlQuerySanitizer {

    /** 解析结果：参数名 -> 参数值（后者覆盖前者，与 Android 默认行为一致）。 */
    private final Map<String, String> params = new LinkedHashMap<>();

    /**
     * @param url 完整 URL；为 null 时等价于空参数集
     */
    public UrlQuerySanitizer(String url) {
        if (url == null) return;
        int q = url.indexOf('?');
        if (q < 0 || q == url.length() - 1) return;
        String query = url.substring(q + 1);
        int hash = query.indexOf('#');
        if (hash >= 0) query = query.substring(0, hash);
        for (String pair : query.split("&")) {
            if (pair.isEmpty()) continue;
            int eq = pair.indexOf('=');
            String k = eq < 0 ? pair : pair.substring(0, eq);
            String v = eq < 0 ? "" : pair.substring(eq + 1);
            params.put(dec(k), dec(v));
        }
    }

    /** 取参数值；不存在返回 null（与 Android 一致）。 */
    public String getValue(String parameter) {
        return parameter == null ? null : params.get(parameter);
    }

    /** 是否存在该参数。 */
    public boolean hasParameter(String parameter) {
        return parameter != null && params.containsKey(parameter);
    }

    /** 参数个数。 */
    public int getParameterSetSize() {
        return params.size();
    }

    /** 解码 %XX 与 +；失败时原样返回。 */
    private static String dec(String s) {
        try {
            return URLDecoder.decode(s, StandardCharsets.UTF_8.name());
        } catch (Exception e) {
            return s;
        }
    }
}
