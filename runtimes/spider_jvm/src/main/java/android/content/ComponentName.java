package android.content;

/**
 * android.content.ComponentName 的最小兼容 shim。
 *
 * Config.init 等会用它做包名校验/查组件。这里提供最简占位，防止
 * NoClassDefFoundError。
 */
public class ComponentName {

    private final String pkg;
    private final String cls;

    public ComponentName(String pkg, String cls) {
        this.pkg = pkg;
        this.cls = cls;
    }

    public String getPackageName() {
        return pkg;
    }

    public String getClassName() {
        return cls;
    }

    @Override
    public String toString() {
        return pkg + "/" + cls;
    }
}