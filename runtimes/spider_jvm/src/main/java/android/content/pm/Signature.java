package android.content.pm;

import java.util.Arrays;

/**
 * android.content.pm.Signature 的最小兼容 shim。
 *
 * <p>源用它读「自己 APK 的签名」，通常做两件事：校验自身是否被二次打包、
 * 或把签名摘要当设备指纹。无头运行时里没有 APK，所以这里持有一段固定字节，
 * 让 {@link #toByteArray()} / {@link #hashCode()} / {@link #equals} 都能正常工作
 * —— 返回 null 会让源的指纹计算直接 NPE。
 */
public class Signature {

    /** 固定占位签名内容（非真实证书，仅保证长度稳定、非 null）。 */
    private static final byte[] PLACEHOLDER = new byte[32];

    private final byte[] signature;

    public Signature(byte[] signature) {
        this.signature = signature == null ? new byte[0] : signature.clone();
    }

    /** 签名原始字节。 */
    public byte[] toByteArray() {
        return signature.clone();
    }

    /** 十六进制摘要形式。 */
    public String toCharsString() {
        StringBuilder sb = new StringBuilder(signature.length * 2);
        for (byte b : signature) {
            sb.append(Character.forDigit((b >> 4) & 0xf, 16));
            sb.append(Character.forDigit(b & 0xf, 16));
        }
        return sb.toString();
    }

    /** 无 APK 时的占位签名。 */
    public static Signature placeholder() {
        return new Signature(PLACEHOLDER);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Signature)) return false;
        return Arrays.equals(signature, ((Signature) o).signature);
    }

    @Override
    public int hashCode() {
        return Arrays.hashCode(signature);
    }
}
