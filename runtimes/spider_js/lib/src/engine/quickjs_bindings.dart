/// QuickJS C API 的 dart:ffi 绑定。
///
/// 当 `quickjs.dll`（Windows）或 `libquickjs.so`（Linux）可用时，
/// 通过 [FFI] 加载并调用。需先编译 QuickJS 源码为共享库。
///
/// 编译 QuickJS（Windows）：
/// ```sh
/// git clone https://github.com/bellard/quickjs
/// cd quickjs
/// cl /LD quickjs.c libbf.c /I. /Fequickjs.dll
/// ```
///
/// 编译 QuickJS（Linux）：
/// ```sh
/// make libquickjs.so
/// ```
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ---- C 类型定义 ----

/// JS 值类型（Opaque handle）。
final class JSValue extends Opaque {}

/// JS 上下文。
final class JSContext extends Opaque {}

/// JS 运行时。
final class JSRuntime extends Opaque {}

/// JS 值（C 结构体，两个指针大小）。
final class JSValueConst extends Struct {
  @IntPtr()
  external int tag;

  @IntPtr()
  external int u;
}

// ---- C 函数声明 ----

/// JS_NewRuntime
typedef JS_NewRuntimeC = Pointer<JSRuntime> Function();
typedef JS_NewRuntimeDart = Pointer<JSRuntime> Function();

/// JS_FreeRuntime
typedef JS_FreeRuntimeC = Void Function(Pointer<JSRuntime> rt);
typedef JS_FreeRuntimeDart = void Function(Pointer<JSRuntime> rt);

/// JS_NewContext
typedef JS_NewContextC = Pointer<JSContext> Function(Pointer<JSRuntime> rt);
typedef JS_NewContextDart = Pointer<JSContext> Function(Pointer<JSRuntime> rt);

/// JS_FreeContext
typedef JS_FreeContextC = Void Function(Pointer<JSContext> ctx);
typedef JS_FreeContextDart = void Function(Pointer<JSContext> ctx);

/// JS_Eval
/// JSValue JS_Eval(JSContext *ctx, const char *input, size_t input_len,
///                  const char *filename, int flags);
typedef JS_EvalC =
    JSValueConst Function(
      Pointer<JSContext> ctx,
      Pointer<Utf8> input,
      Size inputLen,
      Pointer<Utf8> filename,
      Int32 flags,
    );
typedef JS_EvalDart =
    JSValueConst Function(
      Pointer<JSContext> ctx,
      Pointer<Utf8> input,
      int inputLen,
      Pointer<Utf8> filename,
      int flags,
    );

/// 全局 eval 标记。
const int JS_EVAL_TYPE_GLOBAL = 0;

/// 模块 eval 标记。
const int JS_EVAL_TYPE_MODULE = 1;

/// JS_ToCStringLen2
/// const char *JS_ToCStringLen2(JSContext *ctx, size_t *plen, JSValueConst val, int flags);
typedef JS_ToCStringLen2C =
    Pointer<Utf8> Function(
      Pointer<JSContext> ctx,
      Pointer<Size> plen,
      JSValueConst val,
      Int32 flags,
    );
typedef JS_ToCStringLen2Dart =
    Pointer<Utf8> Function(
      Pointer<JSContext> ctx,
      Pointer<Size> plen,
      JSValueConst val,
      int flags,
    );

/// JS_FreeCString
typedef JS_FreeCStringC =
    Void Function(Pointer<JSContext> ctx, Pointer<Utf8> ptr);
typedef JS_FreeCStringDart =
    void Function(Pointer<JSContext> ctx, Pointer<Utf8> ptr);

/// JS_FreeValue
typedef JS_FreeValueC = Void Function(Pointer<JSContext> ctx, JSValueConst v);
typedef JS_FreeValueDart =
    void Function(Pointer<JSContext> ctx, JSValueConst v);

/// JS_IsException
/// 内联函数，需要手动实现
bool JS_IsException(JSValueConst v) => v.tag == 0 - 1; // JS_TAG_EXCEPTION

/// 尝试加载 QuickJS 共享库。
DynamicLibrary? loadQuickJS() {
  try {
    if (Platform.isWindows) {
      return DynamicLibrary.open('quickjs.dll');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libquickjs.dylib');
    }
    // Linux
    return DynamicLibrary.open('libquickjs.so');
  } on Object {
    return null;
  }
}

/// 已加载的 QuickJS 绑定。
final DynamicLibrary? _lib = loadQuickJS();

/// 是否可用。
bool get isQuickJSAvailable => _lib != null;

// ---- 绑定的函数 ----

final JS_NewRuntimeDart? _jsNewRuntime = _lib != null
    ? _lib!.lookupFunction<JS_NewRuntimeC, JS_NewRuntimeDart>('JS_NewRuntime')
    : null;

final JS_FreeRuntimeDart? _jsFreeRuntime = _lib != null
    ? _lib!.lookupFunction<JS_FreeRuntimeC, JS_FreeRuntimeDart>(
        'JS_FreeRuntime',
      )
    : null;

final JS_NewContextDart? _jsNewContext = _lib != null
    ? _lib!.lookupFunction<JS_NewContextC, JS_NewContextDart>('JS_NewContext')
    : null;

final JS_FreeContextDart? _jsFreeContext = _lib != null
    ? _lib!.lookupFunction<JS_FreeContextC, JS_FreeContextDart>(
        'JS_FreeContext',
      )
    : null;

final JS_EvalDart? _jsEval = _lib != null
    ? _lib!.lookupFunction<JS_EvalC, JS_EvalDart>('JS_Eval')
    : null;

final JS_ToCStringLen2Dart? _jsToCString = _lib != null
    ? _lib!.lookupFunction<JS_ToCStringLen2C, JS_ToCStringLen2Dart>(
        'JS_ToCStringLen2',
      )
    : null;

final JS_FreeCStringDart? _jsFreeCString = _lib != null
    ? _lib!.lookupFunction<JS_FreeCStringC, JS_FreeCStringDart>(
        'JS_FreeCString',
      )
    : null;

final JS_FreeValueDart? _jsFreeValue = _lib != null
    ? _lib!.lookupFunction<JS_FreeValueC, JS_FreeValueDart>('JS_FreeValue')
    : null;

/// 创建 QuickJS 运行时。
Pointer<JSRuntime>? newRuntime() => _jsNewRuntime?.call();

/// 释放运行时。
void freeRuntime(Pointer<JSRuntime> rt) => _jsFreeRuntime?.call(rt);

/// 创建 JS 上下文。
Pointer<JSContext>? newContext(Pointer<JSRuntime> rt) =>
    _jsNewContext?.call(rt);

/// 释放上下文。
void freeContext(Pointer<JSContext> ctx) => _jsFreeContext?.call(ctx);

/// 执行 JS 代码。返回 JSON 字符串，失败返回 null。
String? eval(Pointer<JSContext> ctx, String code) {
  if (_jsEval == null || _jsToCString == null || _jsFreeCString == null) {
    return null;
  }
  final input = code.toNativeUtf8();
  final filename = 'eval'.toNativeUtf8();
  final result = _jsEval!(
    ctx,
    input,
    code.length,
    filename,
    JS_EVAL_TYPE_GLOBAL,
  );
  calloc.free(input);
  calloc.free(filename);

  if (JS_IsException(result)) {
    final errStr = _jsToCString!(ctx, nullptr, result, 0);
    _jsFreeCString!(ctx, errStr);
    _jsFreeValue!(ctx, result);
    return null;
  }

  final str = _jsToCString!(ctx, nullptr, result, 0);
  final output = str.toDartString();
  _jsFreeCString!(ctx, str);
  _jsFreeValue!(ctx, result);
  return output;
}
