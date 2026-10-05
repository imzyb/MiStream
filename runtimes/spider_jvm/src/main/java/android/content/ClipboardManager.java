package android.content;

/**
 * android.content.ClipboardManager 的最小兼容 shim。
 *
 * <p>无头运行时里没有系统剪贴板，所以写入是空操作、读取返回 null。
 * 保留一个进程内的内存副本，方便源「写进去再读出来」的自洽逻辑跑通。
 */
public class ClipboardManager {

    /** 系统服务名（{@code Context.getSystemService} 用）。 */
    public static final String CLIPBOARD_SERVICE = "clipboard";

    private ClipData clip;

    public ClipboardManager() {
    }

    /** 设置剪贴板内容（只存内存）。 */
    public void setPrimaryClip(ClipData clip) {
        this.clip = clip;
    }

    /** 读取剪贴板内容。 */
    public ClipData getPrimaryClip() {
        return clip;
    }

    /** 是否有内容。 */
    public boolean hasPrimaryClip() {
        return clip != null;
    }

    /** 取纯文本内容。 */
    public CharSequence getText() {
        if (clip == null || clip.getItemCount() == 0) return null;
        return clip.getItemAt(0).getText();
    }

    /** 清空。 */
    public void clearPrimaryClip() {
        clip = null;
    }
}
