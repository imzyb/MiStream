package android.content;

import java.util.ArrayList;
import java.util.List;

/**
 * android.content.ClipData 的最小兼容 shim。
 *
 * <p>源用它往剪贴板里塞文本（「复制播放地址」之类的功能）。无头运行时里没有
 * 剪贴板，但对象本身要能构造出来 —— 否则调用点抛 NoClassDefFoundError。
 */
public class ClipData {

    /** 一条剪贴项。 */
    public static class Item {
        private final CharSequence text;

        public Item(CharSequence text) {
            this.text = text;
        }

        /** 文本内容。 */
        public CharSequence getText() {
            return text;
        }

        @Override
        public String toString() {
            return text == null ? "" : text.toString();
        }
    }

    private final CharSequence label;
    private final List<Item> items = new ArrayList<>();

    public ClipData(CharSequence label, String[] mimeTypes, Item item) {
        this.label = label;
        if (item != null) items.add(item);
    }

    /** 构造纯文本剪贴项。 */
    public static ClipData newPlainText(CharSequence label, CharSequence text) {
        return new ClipData(label, new String[] {"text/plain"}, new Item(text));
    }

    /** 构造 HTML 剪贴项（退化成纯文本）。 */
    public static ClipData newHtmlText(CharSequence label, CharSequence text, String htmlText) {
        return newPlainText(label, text);
    }

    /** 构造 Intent 剪贴项（无头运行时退化成空项）。 */
    public static ClipData newIntent(CharSequence label, Intent intent) {
        return new ClipData(label, new String[] {"text/uri-list"}, null);
    }

    /** 标签。 */
    public CharSequence getLabel() {
        return label;
    }

    /** 条目数。 */
    public int getItemCount() {
        return items.size();
    }

    /** 取第 i 条。 */
    public Item getItemAt(int index) {
        return items.get(index);
    }

    /** 描述。 */
    public String getDescription() {
        return items.isEmpty() ? "" : String.valueOf(items.get(0));
    }
}
