package android.os;

import java.io.File;

/**
 * android.os.Environment 的最小兼容 shim。
 *
 * <p>源用它拿「外部存储」目录来缓存下载/播放列表。无头运行时里映射到
 * {@code java.io.tmpdir} 下的固定子目录，保证：
 * <ul>
 *   <li>返回的目录**一定存在且可写**（源常直接 {@code new File(dir, name)} 后写文件，
 *       如果父目录不存在就抛 IOException）；</li>
 *   <li>不污染用户真实的家目录 / 桌面。</li>
 * </ul>
 */
public final class Environment {

    /** 存储状态：已挂载。 */
    public static final String MEDIA_MOUNTED = "mounted";
    /** 存储状态：只读。 */
    public static final String MEDIA_MOUNTED_READ_ONLY = "mounted_ro";
    /** 存储状态：未挂载。 */
    public static final String MEDIA_UNMOUNTED = "unmounted";

    /** 外部存储根目录（进程内唯一）。 */
    private static final File EXTERNAL = ensure(new File(
            System.getProperty("java.io.tmpdir"), "mistream-jvm/external"));

    private Environment() {
    }

    /** 外部存储根目录。 */
    public static File getExternalStorageDirectory() {
        return EXTERNAL;
    }

    /** 外部存储下的公共目录（如 Pictures / Download / Music）。 */
    public static File getExternalStoragePublicDirectory(String type) {
        String sub = (type == null || type.isEmpty()) ? "public" : type;
        return ensure(new File(EXTERNAL, sub));
    }

    /**
     * 是否已获得「所有文件访问」权限。
     *
     * <p>恒为 false：源拿到 false 会走「用应用私有目录」的保守分支，
     * 那个分支在我们的 shim 里一定能用。
     */
    public static boolean isExternalStorageManager() {
        return false;
    }

    /** 外部存储状态（恒报已挂载）。 */
    public static String getExternalStorageState() {
        return MEDIA_MOUNTED;
    }

    /** 目录不存在就建，建不出来也把路径返回出去（让调用方自己抛，便于定位）。 */
    private static File ensure(File dir) {
        if (!dir.exists() && !dir.mkdirs() && !dir.exists()) {
            System.err.println("[Env] 无法创建目录: " + dir.getAbsolutePath());
        }
        return dir;
    }
}
