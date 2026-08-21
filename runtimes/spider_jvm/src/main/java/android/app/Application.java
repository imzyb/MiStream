package android.app;

import android.content.Context;

/**
 * android.app.Application 的最小兼容 shim。
 *
 * Init 持有 Application 字段并传给 merge 网络层。这里提供最小实现。
 */
public class Application extends Context {

    public Application() {
    }
}