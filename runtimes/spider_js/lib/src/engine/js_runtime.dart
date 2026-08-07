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
  Pointer<qjs.JSRuntime>? _rt;
  Pointer<qjs.JSContext>? _ctx;
  JsRuntimeStatus _status = JsRuntimeStatus.unavailable;

  /// 当前状态。
  JsRuntimeStatus get status => _status;

  /// 是否可用。
  bool get isAvailable => _status == JsRuntimeStatus.available;

  /// 初始化 QuickJS 引擎。
  ///
  /// 返回 true 表示成功，false 表示 native 库不可用。
  bool init() {
    if (_rt != null) return true;

    if (!qjs.isQuickJSAvailable) {
      _status = JsRuntimeStatus.unavailable;
      return false;
    }

    _rt = qjs.newRuntime();
    if (_rt == null) return false;

    _ctx = qjs.newContext(_rt!);
    if (_ctx == null) {
      qjs.freeRuntime(_rt!);
      _rt = null;
      return false;
    }

    _status = JsRuntimeStatus.available;
    return true;
  }

  /// 执行 JS 代码。
  ///
  /// 返回 JSON 字符串结果，失败返回 null。
  String? eval(String code) {
    if (_ctx == null || !isAvailable) return null;
    return qjs.eval(_ctx!, code);
  }

  /// 释放资源。
  void dispose() {
    if (_ctx != null) {
      qjs.freeContext(_ctx!);
      _ctx = null;
    }
    if (_rt != null) {
      qjs.freeRuntime(_rt!);
      _rt = null;
    }
    _status = JsRuntimeStatus.unavailable;
  }
}
