package android.net;

import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * android.net.Uri 的最小兼容 shim。
 *
 * 真实 jar 里的源（Bili/PanWebShare 等）用 Uri.parse / getLastPathSegment /
 * getQueryParameter / getPath / getHost 等。手写解析以保留 android 的宽松语义
 * （android 的 Uri 容错远强于 java.net.URI）。
 */
public class Uri {

    private final String scheme;
    private final String host;
    private final String path;
    private final String query;
    private final String fragment;
    private final String authority;
    private final String original;

    private Uri(String original) {
        this.original = original;
        String s = original;
        int fragIdx = s.indexOf('#');
        if (fragIdx >= 0) {
            fragment = s.substring(fragIdx + 1);
            s = s.substring(0, fragIdx);
        } else {
            fragment = null;
        }
        int schemeIdx = s.indexOf(':');
        String rest;
        if (schemeIdx > 0 && isAlpha(s.charAt(0))) {
            boolean schemeValid = true;
            for (int i = 1; i < schemeIdx; i++) {
                char c = s.charAt(i);
                if (!(isAlpha(c) || isDigit(c) || c == '+' || c == '-' || c == '.')) {
                    schemeValid = false;
                    break;
                }
            }
            if (schemeValid) {
                scheme = s.substring(0, schemeIdx);
                rest = s.substring(schemeIdx + 1);
            } else {
                scheme = null;
                rest = s;
            }
        } else {
            scheme = null;
            rest = s;
        }

        if (rest.startsWith("//")) {
            int authEnd = rest.indexOf('/', 2);
            if (authEnd < 0) authEnd = rest.length();
            authority = rest.substring(2, authEnd);
            int atIdx = authority.lastIndexOf('@');
            String hostPort = atIdx >= 0 ? authority.substring(atIdx + 1) : authority;
            if (hostPort.startsWith("[")) {
                int close = hostPort.indexOf(']');
                host = close >= 0 ? hostPort.substring(0, close + 1) : hostPort;
            } else {
                int portIdx = hostPort.lastIndexOf(':');
                host = portIdx > 0 ? hostPort.substring(0, portIdx) : hostPort;
            }
            rest = authEnd < rest.length() ? rest.substring(authEnd) : "";
        } else {
            authority = null;
            host = null;
        }

        int qIdx = rest.indexOf('?');
        if (qIdx >= 0) {
            path = rest.substring(0, qIdx);
            query = rest.substring(qIdx + 1);
        } else {
            path = rest;
            query = null;
        }
    }

    private static boolean isAlpha(char c) {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
    }

    private static boolean isDigit(char c) {
        return c >= '0' && c <= '9';
    }

    /** 解析 uri 字符串。 */
    public static Uri parse(String uriString) {
        return new Uri(uriString == null ? "" : uriString);
    }

    /** 从文件构建。 */
    public static Uri fromFile(java.io.File file) {
        return parse("file://" + file.getAbsolutePath());
    }

    /** 当前 uri 的字符串形式。 */
    public String toString() {
        return original;
    }

    /** scheme，无则 null。 */
    public String getScheme() {
        return scheme;
    }

    /** host，无则 null。 */
    public String getHost() {
        return host;
    }

    /** authority（host:port），无则 null。 */
    public String getAuthority() {
        return authority;
    }

    /** path 部分。 */
    public String getPath() {
        return path == null || path.isEmpty() ? null : path;
    }

    /** query 部分（不含 ?）。 */
    public String getQuery() {
        return query;
    }

    /** fragment（不含 #）。 */
    public String getFragment() {
        return fragment;
    }

    /** path 的最后一段（已解码）。 */
    public String getLastPathSegment() {
        if (path == null || path.isEmpty()) return null;
        int lastSlash = path.lastIndexOf('/');
        String seg = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
        return decode(seg);
    }

    /** 是否绝对（有 scheme）。 */
    public boolean isAbsolute() {
        return scheme != null;
    }

    /** 查询参数值（按第一个出现），无则 null。 */
    public String getQueryParameter(String key) {
        if (query == null) return null;
        for (String pair : query.split("&")) {
            int eq = pair.indexOf('=');
            String k = eq >= 0 ? pair.substring(0, eq) : pair;
            if (k.equals(key)) {
                String v = eq >= 0 ? pair.substring(eq + 1) : "";
                return decode(v);
            }
        }
        return null;
    }

    /** 全部查询参数。 */
    public Map<String, List<String>> getQueryParameters() {
        Map<String, List<String>> map = new LinkedHashMap<>();
        if (query == null) return map;
        for (String pair : query.split("&")) {
            int eq = pair.indexOf('=');
            String k = decode(eq >= 0 ? pair.substring(0, eq) : pair);
            String v = eq >= 0 ? decode(pair.substring(eq + 1)) : null;
            map.computeIfAbsent(k, x -> new ArrayList<>()).add(v);
        }
        return map;
    }

    /** 构建 uri 的 Builder。 */
    public static final class Builder {
        private String scheme;
        private String authority;
        private String path = "";
        private String query;
        private String fragment;

        public Builder() {
        }

        public Builder scheme(String s) {
            this.scheme = s;
            return this;
        }

        public Builder authority(String a) {
            this.authority = a;
            return this;
        }

        public Builder path(String p) {
            this.path = p;
            return this;
        }

        public Builder appendPath(String p) {
            if (!path.endsWith("/")) path += "/";
            path += p;
            return this;
        }

        public Builder query(String q) {
            this.query = q;
            return this;
        }

        public Builder fragment(String f) {
            this.fragment = f;
            return this;
        }

        public Uri build() {
            StringBuilder sb = new StringBuilder();
            if (scheme != null) sb.append(scheme).append(':');
            if (authority != null) sb.append("//").append(authority);
            if (path != null) sb.append(path);
            if (query != null) sb.append('?').append(query);
            if (fragment != null) sb.append('#').append(fragment);
            return parse(sb.toString());
        }
    }

    /** 返回可修改副本。 */
    public Builder buildUpon() {
        Builder b = new Builder();
        b.scheme = scheme;
        b.authority = authority;
        b.path = path == null ? "" : path;
        b.query = query;
        b.fragment = fragment;
        return b;
    }

    /** URL 编码。 */
    public static String encode(String s) {
        try {
            return URLEncoder.encode(s == null ? "" : s, "UTF-8").replace("+", "%20");
        } catch (UnsupportedEncodingException e) {
            return s;
        }
    }

    /** URL 解码。 */
    public static String decode(String s) {
        if (s == null) return null;
        try {
            return URLDecoder.decode(s, "UTF-8");
        } catch (Exception e) {
            return s;
        }
    }
}