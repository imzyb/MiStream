package android.content.pm;

import android.os.Bundle;

/**
 * android.content.pm.ProviderInfo 的最小兼容 shim。
 *
 * <p>源用它读「某个 content provider 的 authority 与 meta-data」。无头运行时里
 * 没有 provider，所以 {@code metaData} 是一个**空的、非 null** 的 Bundle ——
 * 源里几乎都是 {@code info.metaData.getString("key")}，空 Bundle 会返回 null
 * 让源走兜底分支；而 {@code metaData} 本身为 null 会直接 NPE。
 */
public class ProviderInfo extends PackageItemInfo {

    /** provider 的 authority。 */
    public String authority;
    /** 是否被导出。 */
    public boolean exported;
    /** 是否授予 uri 权限。 */
    public boolean grantUriPermissions;
    /** 元数据（恒为空 Bundle，但非 null）。 */
    public Bundle metaData = new Bundle();

    public ProviderInfo() {
    }

    @Override
    public String toString() {
        return "ProviderInfo{" + authority + "}";
    }
}
