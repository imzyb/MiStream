package android.util;

/**
 * android.util.Base64 的最小兼容 shim。
 *
 * Android 的 Base64 支持 URL-safe、no-wrap、no-padding 等 flag（docs/08 之外的
 * 约定见 android SDK）。jar 里 csp_ 类常用 {@code encodeToString} /
 * {@code decode}，其中 flag 多为 {@code NO_WRAP}。这里用 java.util.Base64
 * 实现，忽略对换行处理的 flag（NO_WRAP 语义一致）。
 */
public final class Base64 {

    /** 不添加任何 flag。 */
    public static final int DEFAULT = 0;

    /** 编码时不在输出中加换行符。 */
    public static final int NO_WRAP = 2;

    /** 编码时使用 URL-safe 字符集。 */
    public static final int URL_SAFE = 8;

    /** 编码时省略末尾的 '=' 填充。 */
    public static final int NO_PADDING = 1;

    private Base64() {
    }

    /** 编码为 String。 */
    public static String encodeToString(byte[] input, int flags) {
        return encodeBytes(input, flags);
    }

    /** 编码为字节数组（Android 返回带行尾的 byte[]，这里返回标准编码字节）。 */
    public static byte[] encode(byte[] input, int flags) {
        return encodeBytes(input, flags).getBytes(java.nio.charset.StandardCharsets.UTF_8);
    }

    /** 解码。 */
    public static byte[] decode(String str, int flags) {
        return decodeBytes(str.getBytes(java.nio.charset.StandardCharsets.UTF_8), flags);
    }

    /** 解码字节数组。 */
    public static byte[] decode(byte[] input, int flags) {
        return decodeBytes(input, flags);
    }

    private static String encodeBytes(byte[] input, int flags) {
        java.util.Base64.Encoder encoder;
        if ((flags & URL_SAFE) != 0) {
            encoder = java.util.Base64.getUrlEncoder();
        } else {
            encoder = java.util.Base64.getEncoder();
        }
        String encoded = encoder.encodeToString(input);
        if ((flags & NO_WRAP) == 0) {
            // Android 默认（DEFAULT）会加 \n 换行（每 76 字符）。模拟之。
            encoded = wrap(encoded);
        }
        if ((flags & NO_PADDING) != 0) {
            int idx = encoded.indexOf('=');
            if (idx >= 0) encoded = encoded.substring(0, idx);
        }
        return encoded;
    }

    private static byte[] decodeBytes(byte[] input, int flags) {
        java.util.Base64.Decoder decoder;
        if ((flags & URL_SAFE) != 0) {
            decoder = java.util.Base64.getUrlDecoder();
        } else {
            decoder = java.util.Base64.getDecoder();
        }
        // 去掉 Android DEFAULT 编码可能带进来的换行
        return decoder.decode(new String(input, java.nio.charset.StandardCharsets.UTF_8)
            .replace("\n", "").replace("\r", ""));
    }

    private static String wrap(String s) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i += 76) {
            if (sb.length() > 0) sb.append('\n');
            sb.append(s, i, Math.min(i + 76, s.length()));
        }
        return sb.toString();
    }
}
