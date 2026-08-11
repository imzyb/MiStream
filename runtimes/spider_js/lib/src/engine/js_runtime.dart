/// QuickJS 运行时包装 —— 基于 dart:ffi 的 JS 执行引擎。
///
/// 当 native QuickJS 库可用时，直接通过 FFI 调用；不可用时提供降级提示。
library;

import 'dart:ffi';

import 'package:spider_js/src/engine/quickjs_bindings.dart' as qjs;

/// QuickJS 运行时状态。
enum JsRuntimeStatus {
  /// 可用（native 库已加载）。
  available,

  /// 不可用（native 库未找到）。
  unavailable,
}

/// QuickJS 运行时。
///
/// 每个源独立实例，提供 JS 执行能力。
class JsRuntime {
  Pointer<Void>? _rt;
  Pointer<Void>? _ctx;
  JsRuntimeStatus _status = JsRuntimeStatus.unavailable;

  /// 当前状态。
  JsRuntimeStatus get status => _status;

  /// 是否可用。
  bool get isAvailable => _status == JsRuntimeStatus.available;

  /// 初始化 QuickJS 引擎。
  ///
  /// [dllPath] 是 libquickjs.dll 的完整路径（仅 Windows 需要）。
  /// 返回 true 表示成功，false 表示 native 库不可用。
  bool init([String? dllPath]) {
    if (_rt != null) return true;

    if (!qjs.isQuickJSAvailable) {
      _status = JsRuntimeStatus.unavailable;
      return false;
    }

    // wrapper 侧的 qs_init 自身幂等（已加载则直接返回 1），所以这里不再用
    // 静态标志去重——那样第二个实例会跳过初始化，反而在 wrapper 尚未加载
    // 成功时留下一个「以为初始化过了」的坏状态。
    if (dllPath != null && !qjs.initQuickJS(dllPath)) {
      _status = JsRuntimeStatus.unavailable;
      return false;
    }

    final rt = qjs.newRuntime();
    if (rt == null) return false;

    final ctx = qjs.newContext(rt);
    if (ctx == null) {
      qjs.freeRuntime(rt);
      return false;
    }

    _rt = rt;
    _ctx = ctx;
    _status = JsRuntimeStatus.available;
    return true;
  }

  /// 执行 JS 代码。
  ///
  /// 返回 JSON 字符串结果，失败返回 null。
  String? eval(String code) {
    final ctx = _ctx;
    if (ctx == null || !isAvailable) return null;
    return qjs.eval(ctx, code);
  }

  /// 释放资源。
  void dispose() {
    final ctx = _ctx;
    if (ctx != null) {
      qjs.freeContext(ctx);
      _ctx = null;
    }
    final rt = _rt;
    if (rt != null) {
      qjs.freeRuntime(rt);
      _rt = null;
    }
    _status = JsRuntimeStatus.unavailable;
  }
}
