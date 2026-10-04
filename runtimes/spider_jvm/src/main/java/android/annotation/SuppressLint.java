package android.annotation;

import java.lang.annotation.Documented;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;

/**
 * android.annotation.SuppressLint 的最小兼容 shim。
 *
 * jar 里的类常用它标记 lint 豁免。仅运行时反射读取，无实际语义。
 */
@Documented
@Retention(RetentionPolicy.CLASS)
public @interface SuppressLint {
    /** lint 检查名称。 */
    String[] value() default {};
}