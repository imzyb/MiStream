/// QuickJS C API 的 dart:ffi 绑定。
///
/// 在 Windows 上使用 MSVC 编译的 wrapper DLL（quickjs_wrapper.dll）来避免
/// MinGW/Dart FFI 之间的 Windows x64 ABI 不兼容问题。
/// wrapper DLL 动态加载 MinGW 编译的 libquickjs.dll 并封装函数调用。
/// wrapper 的 C 源码与构建脚本在 `runtimes/spider_js/native/`，产物不入库。
///
/// 在 Linux/macOS 上直接使用 QuickJS 共享库。
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ---- C 类型定义 ----

/// JS 上下文（不透明句柄）。
final class JSContext extends Opaque {}

/// JS 运行时（不透明句柄）。
final class JSRuntime extends Opaque {}

// ---- Wrapper DLL 函数类型 ----

/// `qs_init(dll_path) -> int`（1 = 成功，0 = 失败）的 C 签名。
typedef QsInitC = Int32 Function(Pointer<Utf8> dllPath);

/// [QsInitC] 的 Dart 签名。
typedef QsInitDart = int Function(Pointer<Utf8> dllPath);

/// `qs_new_runtime() -> void*` 的 C 签名。
typedef QsNewRuntimeC = Pointer<Void> Function();

/// [QsNewRuntimeC] 的 Dart 签名。
typedef QsNewRuntimeDart = Pointer<Void> Function();

/// `qs_free_runtime(rt)` 的 C 签名。
typedef QsFreeRuntimeC = Void Function(Pointer<Void> rt);

/// [QsFreeRuntimeC] 的 Dart 签名。
typedef QsFreeRuntimeDart = void Function(Pointer<Void> rt);

/// `qs_new_context(rt) -> void*` 的 C 签名。
typedef QsNewContextC = Pointer<Void> Function(Pointer<Void> rt);

/// [QsNewContextC] 的 Dart 签名。
typedef QsNewContextDart = Pointer<Void> Function(Pointer<Void> rt);

/// `qs_free_context(ctx)` 的 C 签名。
typedef QsFreeContextC = Void Function(Pointer<Void> ctx);

/// [QsFreeContextC] 的 Dart 签名。
typedef QsFreeContextDart = void Function(Pointer<Void> ctx);

/// `qs_eval(ctx, input, input_len, filename, flags, &tag, &u) -> int` 的 C 签名。
typedef QsEvalC =
    Int32 Function(
      Pointer<Void> ctx,
      Pointer<Utf8> input,
      Int32 inputLen,
      Pointer<Utf8> filename,
      Int32 flags,
      Pointer<Int64> resultTag,
      Pointer<Uint64> resultU,
    );

/// [QsEvalC] 的 Dart 签名。
typedef QsEvalDart =
    int Function(
      Pointer<Void> ctx,
      Pointer<Utf8> input,
      int inputLen,
      Pointer<Utf8> filename,
      int flags,
      Pointer<Int64> resultTag,
      Pointer<Uint64> resultU,
    );

/// `qs_to_cstring(ctx, val_tag, val_u) -> const char*` 的 C 签名。
typedef QsToCStringC =
    Pointer<Utf8> Function(Pointer<Void> ctx, Int64 valTag, Uint64 valU);

/// [QsToCStringC] 的 Dart 签名。
typedef QsToCStringDart =
    Pointer<Utf8> Function(Pointer<Void> ctx, int valTag, int valU);

/// `qs_free_cstring(ctx, str)` 的 C 签名。
typedef QsFreeCStringC = Void Function(Pointer<Void> ctx, Pointer<Utf8> str);

/// [QsFreeCStringC] 的 Dart 签名。
typedef QsFreeCStringDart = void Function(Pointer<Void> ctx, Pointer<Utf8> str);

/// `qs_free_value(ctx, val_tag, val_u)` 的 C 签名。
typedef QsFreeValueC =
    Void Function(Pointer<Void> ctx, Int64 valTag, Uint64 valU);

/// [QsFreeValueC] 的 Dart 签名。
typedef QsFreeValueDart =
    void Function(Pointer<Void> ctx, int valTag, int valU);

// ---- 全局标记 ----

/// 全局 eval 标记（`JS_EVAL_TYPE_GLOBAL`）。
const int jsEvalTypeGlobal = 0;

/// 模块 eval 标记（`JS_EVAL_TYPE_MODULE`）。
const int jsEvalTypeModule = 1;

/// 尝试加载 QuickJS wrapper 共享库。
DynamicLibrary? _loadWrapperLibrary() {
  try {
    if (Platform.isWindows) {
      // 在 Windows 上使用 wrapper DLL
      // Platform.script.path 在 Windows 上可能含正斜杠，需要规范化
      var scriptDir = '';
      if (Platform.script.scheme == 'file') {
        scriptDir = Directory(Platform.script.toFilePath()).parent.path;
      }

      final candidates = <String>[
        // 1. 当前工作目录
        'quickjs_wrapper.dll',
        // 2. 可执行文件所在目录
        '${Directory.current.path}\\quickjs_wrapper.dll',
        // 3. 环境变量指定的路径
        if (Platform.environment.containsKey('QUICKJS_DLL_PATH'))
          '${Platform.environment['QUICKJS_DLL_PATH']}\\quickjs_wrapper.dll',
        // 4. 包 lib/src/engine 目录（相对于脚本路径）
        if (scriptDir.isNotEmpty)
          '$scriptDir\\lib\\src\\engine\\quickjs_wrapper.dll',
        // 5. 引擎目录（相对于包根）
        if (scriptDir.isNotEmpty) '$scriptDir\\engine\\quickjs_wrapper.dll',
      ];

      for (final path in candidates) {
        if (File(path).existsSync()) {
          return DynamicLibrary.open(path);
        }
      }

      // 最后尝试直接打开
      return DynamicLibrary.open('quickjs_wrapper.dll');
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

/// 已加载的 wrapper 库。
final DynamicLibrary? _wrapperLib = _loadWrapperLibrary();

/// native QuickJS 库是否已成功加载。
bool get isQuickJSAvailable => _wrapperLib != null;

// ---- Wrapper 绑定的函数 ----

final QsInitDart? _qsInit = _wrapperLib?.lookupFunction<QsInitC, QsInitDart>(
  'qs_init',
);

final QsNewRuntimeDart? _qsNewRuntime = _wrapperLib
    ?.lookupFunction<QsNewRuntimeC, QsNewRuntimeDart>('qs_new_runtime');

final QsFreeRuntimeDart? _qsFreeRuntime = _wrapperLib
    ?.lookupFunction<QsFreeRuntimeC, QsFreeRuntimeDart>('qs_free_runtime');

final QsNewContextDart? _qsNewContext = _wrapperLib
    ?.lookupFunction<QsNewContextC, QsNewContextDart>('qs_new_context');

final QsFreeContextDart? _qsFreeContext = _wrapperLib
    ?.lookupFunction<QsFreeContextC, QsFreeContextDart>('qs_free_context');

final QsEvalDart? _qsEval = _wrapperLib?.lookupFunction<QsEvalC, QsEvalDart>(
  'qs_eval',
);

final QsToCStringDart? _qsToCString = _wrapperLib
    ?.lookupFunction<QsToCStringC, QsToCStringDart>('qs_to_cstring');

final QsFreeCStringDart? _qsFreeCString = _wrapperLib
    ?.lookupFunction<QsFreeCStringC, QsFreeCStringDart>('qs_free_cstring');

final QsFreeValueDart? _qsFreeValue = _wrapperLib
    ?.lookupFunction<QsFreeValueC, QsFreeValueDart>('qs_free_value');

/// 初始化 QuickJS wrapper。必须在使用其他函数之前调用。
///
/// [dllPath] 是 libquickjs.dll 的完整路径。
/// 返回 true 表示初始化成功。wrapper 侧自身幂等，重复调用无害。
bool initQuickJS(String dllPath) {
  final init = _qsInit;
  if (init == null) return false;
  final nativePath = dllPath.toNativeUtf8();
  try {
    return init(nativePath) == 1;
  } finally {
    calloc.free(nativePath);
  }
}

/// 创建 QuickJS 运行时。native 不可用时返回 null。
///
/// 句柄的所有权归调用方——每个 `JsRuntime` 实例各持各的，
/// 这里刻意不留模块级缓存，否则多实例会互相覆盖。
Pointer<Void>? newRuntime() => _qsNewRuntime?.call();

/// 释放运行时。
void freeRuntime(Pointer<Void> rt) => _qsFreeRuntime?.call(rt);

/// 在 [rt] 上创建 JS 上下文。native 不可用时返回 null。
Pointer<Void>? newContext(Pointer<Void> rt) => _qsNewContext?.call(rt);

/// 释放上下文。
void freeContext(Pointer<Void> ctx) => _qsFreeContext?.call(ctx);

/// 在 [ctx] 中执行 JS 代码 [code]。返回结果字符串，失败返回 null。
String? eval(Pointer<Void> ctx, String code) {
  final evalFn = _qsEval;
  final toCString = _qsToCString;
  final freeCString = _qsFreeCString;
  final freeValue = _qsFreeValue;
  if (evalFn == null ||
      toCString == null ||
      freeCString == null ||
      freeValue == null) {
    return null;
  }

  final input = code.toNativeUtf8();
  final filename = 'eval'.toNativeUtf8();
  final resultTag = calloc<Int64>();
  final resultU = calloc<Uint64>();

  try {
    final evalResult = evalFn(
      ctx,
      input,
      code.length,
      filename,
      jsEvalTypeGlobal,
      resultTag,
      resultU,
    );

    if (evalResult == -1) {
      final errStr = toCString(ctx, resultTag.value, resultU.value);
      if (errStr != nullptr) {
        freeCString(ctx, errStr);
      }
      freeValue(ctx, resultTag.value, resultU.value);
      return null;
    }

    final str = toCString(ctx, resultTag.value, resultU.value);
    if (str == nullptr) {
      freeValue(ctx, resultTag.value, resultU.value);
      return null;
    }

    final output = str.toDartString();
    freeCString(ctx, str);
    freeValue(ctx, resultTag.value, resultU.value);
    return output;
  } finally {
    calloc
      ..free(input)
      ..free(filename)
      ..free(resultTag)
      ..free(resultU);
  }
}
