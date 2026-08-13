/// QuickJS 运行时包装 —— 基于 dart:ffi 的 JS 执行引擎。
///
/// 当 native QuickJS 库可用时，直接通过 FFI 调用；不可用时提供降级提示。
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:spider_js/src/engine/host_bridge.dart';
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
  String? _lastError;
  bool _hostBridge = false;

  /// drpy 宿主 API 桥。暴露出来是为了让上层读 `consoleOutput`（源诊断面板）
  /// 或在测试里追加自定义宿主函数。
  final HostBridge bridge = HostBridge();

  /// 当前状态。
  JsRuntimeStatus get status => _status;

  /// 是否可用。
  bool get isAvailable => _status == JsRuntimeStatus.available;

  /// drpy 宿主 API 是否已注册进 JS 上下文。
  ///
  /// 为 false 时引擎仍能求值，但脚本里调 `pdfh` 之类会报未定义。
  bool get isHostBridgeAvailable => _hostBridge;

  /// 最近一次失败的原因；从未失败或已恢复时为 null。
  String? get lastError => _lastError;

  /// 初始化 QuickJS 引擎。
  ///
  /// [dllPath] 是 libquickjs 本体的完整路径（仅 Windows 需要）。不传则由
  /// [qjs.defaultQuickJSLibraryPath] 自行解析。
  /// 返回 true 表示成功，false 表示不可用，原因见 [lastError]。
  bool init([String? dllPath]) {
    if (_rt != null) return true;

    if (!qjs.isQuickJSAvailable) {
      return _fail('QuickJS wrapper 库未找到');
    }

    // wrapper 必须先把 libquickjs 本体 LoadLibrary 进来才拿得到函数指针。
    // 这一步以前只在调用方显式传 dllPath 时才做，而全仓没有任何调用方传过，
    // 于是 qs_new_runtime() 恒返回 NULL——引擎却仍报告 available。
    if (Platform.isWindows) {
      final path = dllPath ?? qjs.defaultQuickJSLibraryPath();
      if (path == null) {
        return _fail('未找到 libquickjs.dll，可用 QUICKJS_DLL_PATH 指定目录');
      }
      if (!qjs.initQuickJS(path)) {
        return _fail('qs_init 失败：$path 无法加载或缺少必要导出符号');
      }
    }

    final rt = qjs.newRuntime();
    if (rt == null) {
      return _fail('JS_NewRuntime 返回空');
    }

    final ctx = qjs.newContext(rt);
    if (ctx == null) {
      qjs.freeRuntime(rt);
      return _fail('JS_NewContext 返回空');
    }

    _rt = rt;
    _ctx = ctx;
    _status = JsRuntimeStatus.available;
    _lastError = null;
    _installHostBridge(ctx);
    return true;
  }

  /// 装 drpy 宿主 API。装不上不算致命——纯计算脚本仍可跑，只是脚本里没有
  /// `pdfh` / `md5` 这些函数，所以只翻 [isHostBridgeAvailable] 而不动
  /// [lastError]（后者表示「这次调用失败了」，语义不同）。
  void _installHostBridge(Pointer<Void> ctx) {
    if (!bridge.install(ctx)) {
      _hostBridge = false;
      return;
    }
    final outcome = qjs.eval(ctx, _prelude);
    _hostBridge = outcome.error == null;
  }

  /// 执行 JS 代码。
  ///
  /// 返回结果的字符串形式，失败返回 null 并把原因写进 [lastError]。
  String? eval(String code) {
    final ctx = _ctx;
    if (ctx == null || !isAvailable) {
      _lastError = 'JS 运行时不可用';
      return null;
    }

    final outcome = qjs.eval(ctx, _wrap(code));
    if (outcome.error != null) {
      _lastError = outcome.error;
      return null;
    }
    final raw = outcome.value;
    if (raw == null) {
      _lastError = '包装层未返回结果';
      return null;
    }

    final Map<String, Object?> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, Object?>;
    } on Object {
      // 包装层理应恒返回合法 JSON。真出意外就把原文透出去，不要吞掉。
      _lastError = null;
      return raw;
    }

    switch (decoded['k']) {
      case 'e':
        final message = decoded['d'] as String? ?? 'JS 异常';
        final stack = decoded['s'] as String? ?? '';
        _lastError = stack.isEmpty ? message : '$message\n$stack';
        return null;
      case 'u':
        _lastError = null;
        return 'undefined';
      default:
        _lastError = null;
        return decoded['d'] as String?;
    }
  }

  /// 把用户代码包一层，保证**跨 FFI 边界的 JSValue 永远是字符串**。
  ///
  /// 见 `native/quickjs_wrapper.c` 里 `qs_free_value` 的 FIXME：这份
  /// libquickjs.dll 的 JSObject 布局与 mainline 不同，object 的引用计数位置
  /// 无从得知，既不能安全递减也不能直接调 finalizer。对策是让 object 压根不
  /// 跨界——结果与异常都在 JS 侧 stringify，object 留在 JS 内部由 QuickJS 自己
  /// 回收，我们只接手字符串（字符串的布局已实测确认）。
  ///
  /// 内层用**间接 eval**（`(0,eval)`）而不是直接 eval，以保住全局作用域语义：
  /// 函数声明与 var 仍落在 globalThis 上，跨多次 [eval] 调用可见。
  static String _wrap(String code) =>
      '(function(){ '
      'try{ '
      'var __v=(0,eval)(${jsonEncode(code)}); '
      'return JSON.stringify(__v===undefined?{k:"u"}:{k:"v",d:String(__v)}); '
      '}catch(e){ '
      'return JSON.stringify( '
      '{k:"e",d:String(e),s:(e&&e.stack)?String(e.stack):""}); '
      '} })()';

  /// 记录失败原因并归位状态，恒返回 false 以便 `return _fail(...)`。
  bool _fail(String message) {
    _lastError = message;
    _status = JsRuntimeStatus.unavailable;
    return false;
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
    bridge.dispose();
    _hostBridge = false;
    _status = JsRuntimeStatus.unavailable;
  }

  /// 注入 JS 前导：在唯一的 native 入口 `__qs_host` 之上铺出 drpy 的函数面。
  ///
  /// 全部实参与返回值走 JSON，宿主侧报的错在这里变回 JS 异常，脚本因此可以
  /// 用寻常的 try/catch 处理，堆栈也能被 [eval] 的异常分支带出来。
  static const String _prelude = '''
(function (g) {
  function H(name, args) {
    var raw = g.__qs_host(name, JSON.stringify(args));
    if (raw === undefined) throw new Error('host bridge unavailable: ' + name);
    var r = JSON.parse(raw);
    if (r.e !== undefined) throw new Error(r.e);
    return r.v;
  }
  g.__host = H;

  g.pdfh = function (html, rule) { return H('pdfh', [html, rule]); };
  g.pdfa = function (html, rule) { return H('pdfa', [html, rule]); };
  g.pd = function (html, rule, base) { return H('pd', [html, rule, base || '']); };
  g.pdfl = function (html, rule, base) { return H('pdfl', [html, rule, base || '']); };

  g.md5 = function (s) { return H('md5', [s]); };
  g.sha1 = function (s) { return H('sha1', [s]); };
  g.sha256 = function (s) { return H('sha256', [s]); };
  g.hmac256 = function (s, k) { return H('hmac256', [s, k]); };
  g.urlencode = function (s) { return H('urlencode', [s]); };
  g.urldecode = function (s) { return H('urldecode', [s]); };
  g.base64Encode = function (s) { return H('base64Encode', [s]); };
  g.base64Decode = function (s) { return H('base64Decode', [s]); };
  g.joinUrl = function (b, p) { return H('joinUrl', [b, p]); };

  g.aes = function (o) {
    o = o || {};
    return H('aes', [
      !!o.encrypt, o.input, o.key,
      o.iv || null,
      o.mode || 'AES/CBC/PKCS5Padding'
    ]);
  };

  function emit(level) {
    return function () {
      var parts = Array.prototype.slice.call(arguments).map(function (x) {
        return typeof x === 'object' && x !== null ? JSON.stringify(x) : String(x);
      });
      H('console.log', [level].concat(parts));
    };
  }
  g.console = { log: emit('log'), warn: emit('warn'), error: emit('error') };
})(globalThis);
''';
}
