/// QuickJS 运行时包装 —— 基于 dart:ffi 的 JS 执行引擎。
///
/// 当 native QuickJS 库可用时，直接通过 FFI 调用；不可用时提供降级提示。
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:spider_js/src/engine/host_bridge.dart';
import 'package:spider_js/src/engine/quickjs_bindings.dart' as qjs;

/// QuickJS 运行时状态。
enum JsRuntimeStatus {
  /// 可用（native 库已加载）。
  available,

  /// 不可用（native 库未找到）。
  unavailable,
}

/// 单个源的资源上限。
///
/// docs/05-Spider引擎.md §3：每源独立 Context，且必须能被单独掐断——一个源的
/// 死循环或内存爆炸不能波及同进程里的其它源。
class JsRuntimeLimits {
  /// 构造上限。默认值按「够跑完一次正常的 search，但拦得住失控脚本」取。
  const JsRuntimeLimits({
    this.evalTimeout = const Duration(seconds: 10),
    this.memoryBytes = 64 * 1024 * 1024,
    this.stackBytes = 1024 * 1024,
  });

  /// 不设任何上限。仅用于压测与对照实验，生产别用。
  const JsRuntimeLimits.unlimited()
    : evalTimeout = Duration.zero,
      memoryBytes = 0,
      stackBytes = 0;

  /// 单次 [JsRuntime.eval] 的墙钟时限；[Duration.zero] 表示不限。
  final Duration evalTimeout;

  /// 堆内存上限（字节）；0 表示不限。
  final int memoryBytes;

  /// JS 栈深度上限（字节）；0 表示不限。
  final int stackBytes;
}

/// 一次求值失败的结构化描述，供源诊断面板展示。
///
/// docs/05-Spider引擎.md 要求脚本异常上抛成带堆栈的 `SCRIPT_RUNTIME_ERROR`；
/// 超时与内存超限各有自己的码，否则面板上分不清「源写错了」和「我们掐了它」。
class JsEvalError {
  /// 构造错误。
  const JsEvalError({required this.code, required this.message, this.stack});

  /// 错误码：`SCRIPT_TIMEOUT` / `MEMORY_LIMIT_EXCEEDED` / `SCRIPT_RUNTIME_ERROR`。
  final ErrorCode code;

  /// 异常文本（JS 侧的 `String(e)`）。
  final String message;

  /// `Error.stack`，非 Error 对象抛出时为 null。
  final String? stack;

  /// 面板与日志用的单串形态：有堆栈就附在消息后面。
  String get display =>
      stack == null || stack!.isEmpty ? message : '$message\n$stack';

  @override
  String toString() => '[${code.name}] $display';
}

/// QuickJS 运行时。
///
/// 每个源独立实例，提供 JS 执行能力。
class JsRuntime {
  /// 构造运行时。[limits] 在 [init] 时施加。
  JsRuntime({this.limits = const JsRuntimeLimits()});

  /// 本实例的资源上限。
  final JsRuntimeLimits limits;

  Pointer<Void>? _rt;
  Pointer<Void>? _ctx;
  JsRuntimeStatus _status = JsRuntimeStatus.unavailable;
  JsEvalError? _lastFailure;
  String? _initError;
  bool _hostBridge = false;
  bool _memoryLimited = false;
  bool _stackLimited = false;

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

  /// 内存上限是否真的施加上了。
  ///
  /// 这份 libquickjs 没导出 `JS_SetMemoryLimit` 时为 false——必须如实报告，
  /// 不能让上层以为脚本被兜住了。
  bool get isMemoryLimited => _memoryLimited;

  /// 栈深度上限是否真的施加上了。
  bool get isStackLimited => _stackLimited;

  /// 最近一次失败；从未失败或已恢复时为 null。
  JsEvalError? get lastFailure => _lastFailure;

  /// 最近一次失败的文本形态；从未失败或已恢复时为 null。
  String? get lastError => _initError ?? _lastFailure?.display;

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

    // 上限要在建 context 之前设：JS_SetMemoryLimit 作用于 runtime，
    // 而 context 的分配本身就要走这套配额。
    _applyLimits(rt);

    final ctx = qjs.newContext(rt);
    if (ctx == null) {
      qjs.freeRuntime(rt);
      return _fail('JS_NewContext 返回空');
    }

    _rt = rt;
    _ctx = ctx;
    _status = JsRuntimeStatus.available;
    _initError = null;
    _lastFailure = null;
    _installHostBridge(ctx);
    return true;
  }

  /// 施加内存与栈上限，并记录它们是否真的生效。
  void _applyLimits(Pointer<Void> rt) {
    _memoryLimited =
        limits.memoryBytes > 0 && qjs.setMemoryLimit(rt, limits.memoryBytes);
    _stackLimited =
        limits.stackBytes > 0 && qjs.setMaxStackSize(rt, limits.stackBytes);
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
  /// 返回结果的字符串形式，失败返回 null 并把结构化原因写进 [lastFailure]。
  String? eval(String code) {
    final ctx = _ctx;
    final rt = _rt;
    if (ctx == null || rt == null || !isAvailable) {
      _initError = 'JS 运行时不可用';
      return null;
    }
    _initError = null;

    final timeoutMs = limits.evalTimeout.inMilliseconds;
    final armed = timeoutMs > 0 && qjs.armDeadline(rt, timeoutMs);

    final qjs.EvalOutcome outcome;
    try {
      outcome = qjs.eval(ctx, _wrap(code));
    } finally {
      // 无论成败都要撤时限，否则下一次求值会带着一个已经过期的 deadline 起跑，
      // 第一条字节码就被掐掉。tripped 标记不受 disarm 影响，下面还要读。
      if (armed) qjs.disarmDeadline(rt);
    }

    if (outcome.error != null) {
      _lastFailure = _classify(rt, outcome.error!, armed: armed);
      return null;
    }
    final raw = outcome.value;
    if (raw == null) {
      _lastFailure = const JsEvalError(
        code: ErrorCode.scriptRuntimeError,
        message: '包装层未返回结果',
      );
      return null;
    }

    final Map<String, Object?> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, Object?>;
    } on Object {
      // 包装层理应恒返回合法 JSON。真出意外就把原文透出去，不要吞掉。
      _lastFailure = null;
      return raw;
    }

    switch (decoded['k']) {
      case 'e':
        _lastFailure = _classify(
          rt,
          decoded['d'] as String? ?? 'JS 异常',
          stack: decoded['s'] as String?,
          armed: armed,
        );
        return null;
      case 'u':
        _lastFailure = null;
        return 'undefined';
      default:
        _lastFailure = null;
        return decoded['d'] as String?;
    }
  }

  /// 把一条失败归到具体错误码。
  ///
  /// 被 interrupt 掐断的脚本抛出来的异常，和脚本自己抛的长得一模一样，只有
  /// native 侧的 tripped 标记能区分——所以先问它，再看文本。
  JsEvalError _classify(
    Pointer<Void> rt,
    String message, {
    required bool armed,
    String? stack,
  }) {
    if (armed && qjs.deadlineTripped(rt)) {
      return JsEvalError(
        code: ErrorCode.scriptTimeout,
        message: '脚本执行超时（${limits.evalTimeout.inMilliseconds}ms）：$message',
        stack: stack,
      );
    }
    // QuickJS 的内存/栈耗尽走的是 InternalError，只能认文本。
    final lower = message.toLowerCase();
    if (lower.contains('out of memory')) {
      return JsEvalError(
        code: ErrorCode.memoryLimitExceeded,
        message: message,
        stack: stack,
      );
    }
    return JsEvalError(
      code: ErrorCode.scriptRuntimeError,
      message: message,
      stack: stack,
    );
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

  /// 记录初始化失败原因并归位状态，恒返回 false 以便 `return _fail(...)`。
  bool _fail(String message) {
    _initError = message;
    _status = JsRuntimeStatus.unavailable;
    return false;
  }

  /// 尽快掐断正在执行的脚本。
  ///
  /// 做法是把时限压到 1ms 而不是新增一个 native 导出——`qs_arm_deadline` 本就
  /// 会重置 tripped 标记并（必要时）装上 interrupt 处理器，压时限等价于「立刻
  /// 到期」。收到 `$/cancelRequest` 时用它。
  ///
  /// 能力边界：interrupt 只在字节码执行时被检查。脚本卡在一次宿主调用的阻塞
  /// 等待里时，要等那次调用返回后才会被掐断。
  void cancel() {
    final rt = _rt;
    if (rt == null) return;
    qjs.armDeadline(rt, 1);
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
    _memoryLimited = false;
    _stackLimited = false;
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

  // req 与 local.* 必须过宿主（ADR-001），只有子进程装了对应的处理器时才可用。
  // 进程内直接用 JsRuntime 时它们会抛「未登记的宿主函数」——这是如实报告，
  // 好过让脚本以为发出去了。
  g.req = function (url, options) { return H('req', [url, options || {}]); };
  g.local = {
    get: function (k) { return H('local.get', [k]); },
    set: function (k, v) { return H('local.set', [k, v]); },
    'delete': function (k) { return H('local.delete', [k]); }
  };

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
