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

/// `qs_get_exception(ctx, &tag, &u) -> int` 的 C 签名。
typedef QsGetExceptionC =
    Int32 Function(
      Pointer<Void> ctx,
      Pointer<Int64> outTag,
      Pointer<Uint64> outU,
    );

/// [QsGetExceptionC] 的 Dart 签名。
typedef QsGetExceptionDart =
    int Function(
      Pointer<Void> ctx,
      Pointer<Int64> outTag,
      Pointer<Uint64> outU,
    );

/// `qs_get_prop_str(ctx, tag, u, prop, &tag, &u) -> int` 的 C 签名。
typedef QsGetPropStrC =
    Int32 Function(
      Pointer<Void> ctx,
      Int64 valTag,
      Uint64 valU,
      Pointer<Utf8> prop,
      Pointer<Int64> outTag,
      Pointer<Uint64> outU,
    );

/// [QsGetPropStrC] 的 Dart 签名。
typedef QsGetPropStrDart =
    int Function(
      Pointer<Void> ctx,
      int valTag,
      int valU,
      Pointer<Utf8> prop,
      Pointer<Int64> outTag,
      Pointer<Uint64> outU,
    );

/// `const char* dispatch(const char* name, const char* argsJson)` 的 C 签名。
///
/// 返回的指针由 native 侧拷进 JS 字符串后立刻交回 [HostReleaseC] 释放。
typedef HostDispatchC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

/// `void release(const char*)` 的 C 签名。
typedef HostReleaseC = Void Function(Pointer<Utf8>);

/// `qs_register_host(ctx, dispatch, release) -> int` 的 C 签名。
typedef QsRegisterHostC =
    Int32 Function(
      Pointer<Void> ctx,
      Pointer<NativeFunction<HostDispatchC>> dispatch,
      Pointer<NativeFunction<HostReleaseC>> release,
    );

/// [QsRegisterHostC] 的 Dart 签名。
typedef QsRegisterHostDart =
    int Function(
      Pointer<Void> ctx,
      Pointer<NativeFunction<HostDispatchC>> dispatch,
      Pointer<NativeFunction<HostReleaseC>> release,
    );

// ---- 全局标记 ----

/// 全局 eval 标记（`JS_EVAL_TYPE_GLOBAL`）。
const int jsEvalTypeGlobal = 0;

/// 模块 eval 标记（`JS_EVAL_TYPE_MODULE`）。
const int jsEvalTypeModule = 1;

/// 在候选目录里找 native 库文件 [name]，返回第一个存在的路径，找不到返回 null。
///
/// wrapper 与 libquickjs 两个 DLL 总是并排放，所以共用同一份候选顺序，只差文件名。
String? findNativeLibrary(String name) {
  var scriptDir = '';
  if (Platform.script.scheme == 'file') {
    try {
      scriptDir = Directory(Platform.script.toFilePath()).parent.path;
    } on Object {
      scriptDir = '';
    }
  }
  final cwd = Directory.current.path;
  final sep = Platform.pathSeparator;
  final engineRel = 'lib${sep}src${sep}engine';
  final envDir = Platform.environment['QUICKJS_DLL_PATH'];

  final candidates = <String>[
    // 1. 裸名与当前目录：打包产物里 DLL 与 exe 并排。
    name,
    '$cwd$sep$name',
    // 2. 环境变量显式指定的目录。
    if (envDir != null && envDir.isNotEmpty) '$envDir$sep$name',
    // 3. 包内引擎目录，相对 cwd——`dart test` 与 `melos exec` 都在包根跑，
    //    只认 Platform.script 的话测试进程里会解析不到。
    '$cwd$sep$engineRel$sep$name',
    // 4. 同上但相对脚本位置（`dart run` 直接跑包内文件时）。
    if (scriptDir.isNotEmpty) '$scriptDir$sep$engineRel$sep$name',
    if (scriptDir.isNotEmpty) '$scriptDir${sep}engine$sep$name',
  ];

  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

/// libquickjs 本体的默认路径。
///
/// Windows 上 wrapper 要靠 [initQuickJS] 把这个路径 `LoadLibrary` 进来才能拿到
/// 函数指针；其它平台直接链接本体，不需要这一步，返回 null。
String? defaultQuickJSLibraryPath() =>
    Platform.isWindows ? findNativeLibrary('libquickjs.dll') : null;

/// 尝试加载 QuickJS wrapper 共享库。
DynamicLibrary? _loadWrapperLibrary() {
  try {
    if (Platform.isWindows) {
      // 找不到就退回裸名，交给系统的 DLL 搜索路径。
      final path = findNativeLibrary('quickjs_wrapper.dll');
      return DynamicLibrary.open(path ?? 'quickjs_wrapper.dll');
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

/// 诊断用符号，旧版 wrapper DLL 上可能不存在——查不到就降级成「异常无文本」，
/// 不能让整个引擎因此不可用。
T? _lookupOptional<T>(T? Function() lookup) {
  try {
    return lookup();
  } on Object {
    return null;
  }
}

final QsGetExceptionDart? _qsGetException = _lookupOptional(
  () => _wrapperLib?.lookupFunction<QsGetExceptionC, QsGetExceptionDart>(
    'qs_get_exception',
  ),
);

final QsGetPropStrDart? _qsGetPropStr = _lookupOptional(
  () => _wrapperLib?.lookupFunction<QsGetPropStrC, QsGetPropStrDart>(
    'qs_get_prop_str',
  ),
);

final QsRegisterHostDart? _qsRegisterHost = _lookupOptional(
  () => _wrapperLib?.lookupFunction<QsRegisterHostC, QsRegisterHostDart>(
    'qs_register_host',
  ),
);

/// 把宿主分发回调装进 [ctx] 的全局对象（JS 侧可见为 `__qs_host`）。
///
/// 返回 false 表示 wrapper 或 libquickjs 缺少必要导出，此时脚本里没有 drpy
/// API，但引擎本身照常可用。
bool registerHost(
  Pointer<Void> ctx,
  Pointer<NativeFunction<HostDispatchC>> dispatch,
  Pointer<NativeFunction<HostReleaseC>> release,
) {
  final register = _qsRegisterHost;
  if (register == null) return false;
  return register(ctx, dispatch, release) == 1;
}

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

/// 创建 QuickJS 运行时。native 不可用或创建失败时返回 null。
///
/// 句柄的所有权归调用方——每个 `JsRuntime` 实例各持各的，
/// 这里刻意不留模块级缓存，否则多实例会互相覆盖。
Pointer<Void>? newRuntime() => _orNull(_qsNewRuntime?.call());

/// 释放运行时。
void freeRuntime(Pointer<Void> rt) => _qsFreeRuntime?.call(rt);

/// 在 [rt] 上创建 JS 上下文。native 不可用或创建失败时返回 null。
Pointer<Void>? newContext(Pointer<Void> rt) => _orNull(_qsNewContext?.call(rt));

/// 把 C 侧的失败值归一成 Dart null。
///
/// C 函数失败返回的是 `NULL`，到 Dart 这边是 `nullptr`——一个地址为 0 的
/// **合法** Pointer，不是 Dart `null`。调用方若写 `ptr == null` 会把失败当成功
/// 放过去，随后所有调用都打在空指针上却毫无征兆（引擎报告 available 而
/// `eval` 恒返回 null）。归一在这里做一次，调用方就只需判 null。
Pointer<Void>? _orNull(Pointer<Void>? ptr) =>
    (ptr == null || ptr == nullptr) ? null : ptr;

/// 释放上下文。
void freeContext(Pointer<Void> ctx) => _qsFreeContext?.call(ctx);

/// 一次 [eval] 的结果：`value` 与 `error` 恰有一个非 null。
typedef EvalOutcome = ({String? value, String? error});

/// 在 [ctx] 中执行 JS 代码 [code]。
///
/// 失败时把 JS 异常文本放进 `error` 一并返回——以前这里取出异常字符串后立刻
/// free 掉就丢弃，失败时连诊断都没有，而 `docs/05-Spider引擎.md` 要求脚本异常
/// 能带信息上抛成 `SCRIPT_RUNTIME_ERROR`。
EvalOutcome eval(Pointer<Void> ctx, String code) {
  final evalFn = _qsEval;
  final toCString = _qsToCString;
  final freeCString = _qsFreeCString;
  final freeValue = _qsFreeValue;
  if (evalFn == null ||
      toCString == null ||
      freeCString == null ||
      freeValue == null) {
    return (value: null, error: 'QuickJS wrapper 未导出所需符号');
  }

  final input = code.toNativeUtf8();
  final filename = 'eval'.toNativeUtf8();
  final resultTag = calloc<Int64>();
  final resultU = calloc<Uint64>();

  try {
    final evalResult = evalFn(
      ctx,
      input,
      // JS_Eval 要的是 UTF-8 字节数，不是 UTF-16 码元数。含中文的脚本按
      // code.length 传会被截断在半个字符上。
      input.length,
      filename,
      jsEvalTypeGlobal,
      resultTag,
      resultU,
    );

    if (evalResult == -1) {
      // 先放掉 JS_EXCEPTION 哨兵本身——它不携带任何信息，真正的 Error 对象
      // 挂在 ctx 上，要单独 claim 回来。
      freeValue(ctx, resultTag.value, resultU.value);
      return (value: null, error: _takeException(ctx) ?? 'JS 异常（无文本）');
    }

    final text = _valueToString(ctx, resultTag.value, resultU.value);
    freeValue(ctx, resultTag.value, resultU.value);
    if (text == null) {
      return (value: null, error: '结果无法转成字符串');
    }
    return (value: text, error: null);
  } finally {
    calloc
      ..free(input)
      ..free(filename)
      ..free(resultTag)
      ..free(resultU);
  }
}

/// 把 JSValue 转成 Dart 字符串，失败返回 null。不释放该 JSValue。
String? _valueToString(Pointer<Void> ctx, int tag, int u) {
  final toCString = _qsToCString;
  final freeCString = _qsFreeCString;
  if (toCString == null || freeCString == null) return null;

  final str = toCString(ctx, tag, u);
  if (str == nullptr) return null;
  final out = str.toDartString();
  freeCString(ctx, str);
  return out;
}

/// 取回并释放挂在 [ctx] 上的待处理异常，尽量拼上 `Error.stack`。
String? _takeException(Pointer<Void> ctx) {
  final getExc = _qsGetException;
  final freeValue = _qsFreeValue;
  if (getExc == null || freeValue == null) return null;

  final tag = calloc<Int64>();
  final u = calloc<Uint64>();
  try {
    if (getExc(ctx, tag, u) != 1) return null;

    final message = _valueToString(ctx, tag.value, u.value);
    final stack = _readStack(ctx, tag.value, u.value);
    freeValue(ctx, tag.value, u.value);

    if (message == null) return stack;
    if (stack == null || stack.isEmpty) return message;
    return '$message\n$stack';
  } finally {
    calloc
      ..free(tag)
      ..free(u);
  }
}

/// 读取 Error 对象的 `stack` 属性，没有则返回 null。
String? _readStack(Pointer<Void> ctx, int tag, int u) {
  final getProp = _qsGetPropStr;
  final freeValue = _qsFreeValue;
  if (getProp == null || freeValue == null) return null;

  final prop = 'stack'.toNativeUtf8();
  final outTag = calloc<Int64>();
  final outU = calloc<Uint64>();
  try {
    if (getProp(ctx, tag, u, prop, outTag, outU) != 1) return null;
    final text = _valueToString(ctx, outTag.value, outU.value);
    freeValue(ctx, outTag.value, outU.value);
    // 非 Error 对象抛出来时 stack 是 undefined，转成字符串没有意义。
    return (text == null || text == 'undefined' || text.isEmpty) ? null : text;
  } finally {
    calloc
      ..free(prop)
      ..free(outTag)
      ..free(outU);
  }
}
