package android.provider;

import android.content.ContentResolver;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

/**
 * android.provider.Settings 的最小兼容 shim。
 *
 * <p>csp_ 源里唯一实际用到的入口是：
 *
 * <pre>
 * Settings.Secure.getString(context.getContentResolver(), "android_id")
 * </pre>
 *
 * <p>拿到设备标识后塞进请求参数（常见 key：{@code androidID} / {@code deviceId}）。
 * 真实 Android 上这个值在同一台设备上稳定、卸载重装才变；这里用一个**进程内稳定**
 * 的假值即可 —— 站点只把它当不透明标识，不会校验它的来源。
 *
 * <p>刻意**不**返回 {@code null}：很多源直接把它丢进 JSON，null 会让服务端判定
 * 参数缺失并返回错误页，比返回一个假值更难排查。
 *
 * <p>另外刻意**不**使用真实 Android 那个著名的全设备默认值
 * （{@code 9774d56d682e549c}）—— 部分站点会把它当异常设备拒绝。
 */
public final class Settings {

    private Settings() {
    }

    /** {@code Settings.Secure} —— 安全相关的系统设置。 */
    public static final class Secure {

        /** 设备标识的设置名。 */
        public static final String ANDROID_ID = "android_id";

        /** 进程内稳定的假设备标识（16 位十六进制，与真实格式一致）。 */
        private static final String FAKE_ANDROID_ID = generateId();

        private Secure() {
        }

        /**
         * 读取 {@code Secure} 设置。
         *
         * @param resolver 内容解析器（本 shim 不读它，允许为 null）
         * @param name     设置名；{@code "android_id"} 返回稳定的假设备标识
         * @return 设置值；未支持的名字返回 {@code null}（与真实 Android 一致）
         */
        public static String getString(ContentResolver resolver, String name) {
            if (ANDROID_ID.equals(name)) return FAKE_ANDROID_ID;
            return null;
        }

        /** 整数版本（当前无源使用，保持与真实 API 同形以便将来接）。 */
        public static int getInt(ContentResolver resolver, String name, int def) {
            return def;
        }

        /** 长整数版本。 */
        public static long getLong(ContentResolver resolver, String name, long def) {
            return def;
        }

        /**
         * 生成一个看起来像真实 android_id 的值。
         *
         * <p>用固定 seed 的 UUID 而不是随机数：进程内稳定，且跨进程也稳定，
         * 避免同一个站点每次启动都被当成新设备而触发风控。
         */
        private static String generateId() {
            UUID u = UUID.nameUUIDFromBytes(
                    "io.mistream.android_id".getBytes(StandardCharsets.UTF_8));
            return u.toString().replace("-", "").substring(0, 16);
        }
    }
}
