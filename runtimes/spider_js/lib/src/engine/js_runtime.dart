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

  /// 见 [isSealed]。一旦 [park] 过就置位，且不再清除。
  bool _sealed = false;

  /// drpy 宿主 API 桥。暴露出来是为了让上层读 `consoleOutput`（源诊断面板）
  /// 或在测试里追加自定义宿主函数。
  final HostBridge bridge = HostBridge();

  /// 当前 base URL（用于模块解析）。
  String? _baseUrl;

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
  ///
  /// 已经 [park] 过的实例再调本方法时只补一个新 context——runtime 还在，不必
  /// 重建（这正是停放池能复用的原因）。
  bool init([String? dllPath]) {
    if (_rt != null) {
      return _ctx != null || _attachContext();
    }

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
    _rt = rt;

    if (!_attachContext()) {
      qjs.freeRuntime(rt);
      _rt = null;
      return false;
    }
    return true;
  }

  /// 在当前 runtime 上建一个新 context 并装好宿主桥。
  ///
  /// 与 [init] 分开是因为它同时服务两条路径：首次初始化，以及 [park] 之后的
  /// 复用。抽出来的另一个好处是 `_rt` 的赋值时机变得明确——[init] 里必须在
  /// 建 context **之前**赋值，否则建失败时的回滚会漏掉 runtime。
  ///
  /// 新 context 是干净的，所以挂在旧 context 上的全局（`__qs_base_url`、宿主
  /// 函数）都要重铺：宿主函数由 [_installHostBridge] 负责，base URL 由调用方在
  /// [init] 之后调 [setBaseUrl] 补上（`spider.create` 里就是这么排的）。
  bool _attachContext() {
    final rt = _rt;
    if (rt == null) return _fail('runtime 未创建');

    final ctx = qjs.newContext(rt);
    if (ctx == null) {
      return _fail('JS_NewContext 返回空');
    }

    _ctx = ctx;
    _status = JsRuntimeStatus.available;
    _initError = null;
    _lastFailure = null;
    // 复用路径下 limit 本来就还在 runtime 上，重设一次只为让两个标志位如实。
    _applyLimits(rt);
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
  String? eval(String code) => _evalWithTimeout(code, qjs.jsEvalTypeGlobal);

  /// 以 ES 模块模式执行 JS 代码。
  ///
  /// import/export 语句合法，`await` 顶层可用。用于加载 drpy 依赖。
  String? evalModule(String code) =>
      _evalWithTimeout(code, qjs.jsEvalTypeModule);

  String? _evalWithTimeout(String code, int flags) {
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
    // 异步结果没读回来时填原因，供下面 k=="a" 分支如实报错。
    var asyncNote = '';
    try {
      final evalFn = flags == qjs.jsEvalTypeModule ? qjs.evalModule : qjs.eval;
      var step = evalFn(ctx, _wrap(code));

      if (step.error == null) {
        // JS_Eval 只跑脚本的同步部分。Promise 回调是挂在 runtime 队列上的
        // microtask job，没有东西泵它就永远不执行——`p.then(cb)` 不调 cb，
        // `async function f(){...}` 的返回值永远不落地。不泵的后果不是报错而是
        // **静默拿到空值**，最难查，所以这一步是每次求值都要做的常规动作。
        final drained = qjs.drainJobs(rt, ctx);
        if (drained == qjs.drainJobsFailed) {
          step = (
            value: null,
            error: qjs.takeException(ctx) ?? '微任务异常（无文本）',
          );
        } else if (step.value == asyncMarker) {
          if (drained == qjs.drainJobsUnavailable) {
            asyncNote = '本机 libquickjs 未导出 JS_ExecutePendingJob';
          } else {
            // 队列已排空，把暂存区里的结果读回来。仍是 pending 的话读回的
            // 还是待定标记，由下面的 k=="a" 分支报错。
            step = qjs.eval(ctx, _asyncReadback);
          }
        }
      }
      outcome = step;
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
      case 'a':
        // Promise 排空微任务后仍未落定：要么本机缺 job 泵，要么脚本真的挂着
        // （在等一个永远不会到来的事件）。如实报错——把空结果当成功交出去，
        // 表现是源「能打开但没数据」，面板上什么都查不到。
        _lastFailure = JsEvalError(
          code: ErrorCode.scriptRuntimeError,
          message: asyncNote.isEmpty
              ? '脚本返回的 Promise 未落定（微任务排空后仍是 pending）'
              : '脚本返回的 Promise 无法读取：$asyncNote',
        );
        return null;
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

  /// 设置模块解析的 base URL。
  ///
  /// 在 `spider.create` 时由宿主传入，`assets://` 协议相对路径都基于此解析。
  /// 设完后自动注入 JS 全局 `__qs_base_url`。
  ///
  /// 传 null / 空串表示**清空**，会把全局一并删掉。这条必须成立：停放池复用
  /// runtime 时，上一个源的 base URL 若留在新 context 里，新源解析 `assets://`
  /// 就会指到别人的目录，而且不报错。
  void setBaseUrl(String? url) {
    _baseUrl = (url == null || url.isEmpty) ? null : url;
    if (!isAvailable) return;
    final ctx = _ctx!;
    final target = _baseUrl;
    qjs.eval(
      ctx,
      target == null
          ? 'delete globalThis.__qs_base_url;'
          : 'globalThis.__qs_base_url = ${jsonEncode(target)};',
    );
  }

  /// 获取当前 base URL。
  String? get baseUrl => _baseUrl;

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
  /// 见 `native/quickjs_wrapper.c` 里 `qs_free_value` 标注的待修复问题：这份
  /// libquickjs.dll 的 JSObject 布局与 mainline 不同，object 的引用计数位置
  /// 无从得知，既不能安全递减也不能直接调 finalizer。对策是让 object 压根不
  /// 跨界——结果与异常都在 JS 侧 stringify，object 留在 JS 内部由 QuickJS 自己
  /// 回收，我们只接手字符串（字符串的布局已实测确认）。
  ///
  /// 内层用**间接 eval**（`(0,eval)`）而不是直接 eval，以保住全局作用域语义：
  /// 函数声明与 var 仍落在 globalThis 上，跨多次 [eval] 调用可见。
  ///
  /// 返回值是 thenable 时不能直接 `String()`：那样只会得到 `[object Promise]`。
  /// 这种情况挂上 then/catch 把结果暂存到 `__qs_*` 全局，先回 [asyncMarker]；
  /// 调用方排空 microtask 队列后再用 [_asyncReadback] 取回（见
  /// [_evalWithTimeout]）。async 入口的源全靠这条路径，缺了它只会静默拿到空值。
  static String _wrap(String code) =>
      '(function(){ '
      'var __g=globalThis; '
      'try{ '
      'var __v=(0,eval)(${jsonEncode(code)}); '
      'if(__v!==null&&typeof __v==="object"&&typeof __v.then==="function"){ '
      '__g.__qs_a=0;__g.__qs_u=false;__g.__qs_d=undefined;__g.__qs_s=""; '
      '__v.then('
      'function(__r){ '
      'try{__g.__qs_a=1;__g.__qs_u=(__r===undefined);'
      '__g.__qs_d=__g.__qs_u?undefined:String(__r);}'
      'catch(__x){__g.__qs_a=2;__g.__qs_d=String(__x);__g.__qs_s="";}},'
      'function(__e){__g.__qs_a=2;__g.__qs_d=String(__e);'
      '__g.__qs_s=(__e&&__e.stack)?String(__e.stack):"";}); '
      'return ${jsonEncode(asyncMarker)}; '
      '} '
      'return JSON.stringify(__v===undefined?{k:"u"}:{k:"v",d:String(__v)}); '
      '}catch(e){ '
      'return JSON.stringify( '
      '{k:"e",d:String(e),s:(e&&e.stack)?String(e.stack):""}); '
      '} })()';

  /// [_wrap] 用来表示「结果是 thenable，得先排空 microtask」的标记。
  static const String asyncMarker = '{"k":"a"}';

  /// 读回 [_wrap] 暂存的异步结果，并把暂存区复位。
  ///
  /// 只在 [_wrap] 回了 [asyncMarker] 时使用。**每个分支都必须返回字符串**：
  /// 这段代码是裸 `qjs.eval`，不经过 [_wrap] 的 stringify，返回对象会被
  /// `String()` 成 `"[object Object]"` 这种废值悄悄漏出去。
  static const String _asyncReadback =
      '(function(){ '
      'var __g=globalThis; '
      'var __a=__g.__qs_a; '
      '__g.__qs_a=undefined; '
      'if(__a===1){ '
      'return JSON.stringify(__g.__qs_u?{k:"u"}:{k:"v",d:String(__g.__qs_d)}); '
      '} '
      'if(__a===2){ '
      'return JSON.stringify({k:"e",d:String(__g.__qs_d), '
      's:__g.__qs_s?String(__g.__qs_s):""}); '
      '} '
      'return JSON.stringify({k:"a"}); '
      '})()';

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
  ///
  /// 已经被 [park] 过的实例（[isSealed]）**只丢引用，不释放 runtime 壳**——见
  /// [park] 里那份判定证据：这个 build 的 GC/释放路径本身会断言 abort。
  void dispose() {
    final ctx = _ctx;
    if (ctx != null) {
      qjs.freeContext(ctx);
      _ctx = null;
    }
    final rt = _rt;
    if (rt != null) {
      _rt = null;
      if (!_sealed) qjs.freeRuntime(rt);
    }
    bridge.dispose();
    _hostBridge = false;
    _memoryLimited = false;
    _stackLimited = false;
    _status = JsRuntimeStatus.unavailable;
  }

  /// runtime 壳是否已「封存」：不会再被回收，也不会被释放。
  ///
  /// 一旦 [park] 过就是 true，且不可逆。封存的 runtime 只有进程退出才能回收内存。
  bool get isSealed => _sealed;

  /// 结束这个实例，但**不释放 runtime**——留着给下一个源复用，直到进程退出。
  ///
  /// 为什么不直接 [dispose]：手头这份 vendored `libquickjs.dll` 是 assert 版
  /// 定制构建，`JSObject` 布局非 mainline（见 `runtimes/spider_js/README.md`）。
  /// 实测跑完一次真实 drpy2（4 条远程 import + 660KB 依赖 + init + home）之后，
  /// 这个 build 的 GC/释放路径会断言 abort：
  /// `Assertion failed: i != 0, file quickjs.c, line 3394`。
  /// 复现与二分见 `tool/repro_dispose.dart` 与 `tool/probe_real_drpy.dart`。
  ///
  /// 判定要点（都实测过，每组 6 次）：
  /// - **`JS_FreeContext` 永远安全**（6/6 走完）。所以释放 context 照做，
  ///   JS 堆对象不会滞留。
  /// - **崩点是 GC 本身，不是「没回收干净」**：`JS_RunGC` 6 次崩 5 次，
  ///   `JS_FreeRuntime` 同样（它内部也走这套释放路径）。两者是同一个崩点，
  ///   所以「先 GC 再释放」这种组合没有意义。
  /// - 它是**堆布局阈值敏感**的：内存上限 32/128/256/512MB 都不触发，默认的
  ///   64MB 触发；少装一个限值、少求值一步也不触发。也就是说调参数只是换个
  ///   落点，不是修复——所以这里不调参，只把这一步从热路径上摘掉。
  ///
  /// 影响面正是它必须被摘掉的原因：宿主 `_trySites` 每试一个站点就
  /// `runtime.dispose()` 一次，也就是**每次请求都会打死共享的 JS 子进程**，
  /// 顺带把同一进程里其它源的调用一起带走。
  ///
  /// 代价（明确记账）：runtime 壳（atom 表、shape、`gc_obj_list` 残项）封存到
  /// 进程退出，[isSealed] 之后不可回收。context 已释放，JS 堆对象不滞留，剩下
  /// 的很小；`RuntimeChild` 用有上限的停放池兜住它，避免随访问过的源数增长。
  ///
  /// 根治办法见 README「边界约定」：拿到与该 DLL 匹配的 `quickjs.h`、或换一份
  /// 非 assert 构建的 libquickjs，就能恢复正常释放。
  void park() {
    // 幂等：已封存过、或本来就没有 runtime 可留，都直接返回。
    if (_rt == null || _sealed) return;
    final ctx = _ctx;
    if (ctx != null) {
      qjs.freeContext(ctx);
      _ctx = null;
    }
    // 这里**不做** runGc、也不释放 runtime：见上面那份二分结论。
    _sealed = true;
    bridge.dispose();
    _hostBridge = false;
    _memoryLimited = false;
    _stackLimited = false;
    _status = JsRuntimeStatus.unavailable;
  }

  /// 是否已经 [park] 过（context 没了，但 runtime 还留着）。
  bool get isParked => _rt != null && _ctx == null;

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

  // ---- JSON 解析（drpy 的 JSONPath 组）----
  // jsonpath.query 的参数顺序是「对象在前、路径在后」，与参考实现一致。
  // 返回的永远是数组（命中不到就是空数组），负下标不命中。
  g.jsonpath = {
    query: function (jsonObject, path) { return H('jsonpath', [jsonObject, path]); }
  };
  // 取单值。注意假值会被 `|| ''` 吞掉：命中数字 0 得到的是空串。
  // 规则里可以用 `||` 串多条路径做回退。
  g.pjfh = function (json, rule, addUrl) {
    return H('pjfh', [json, rule, addUrl === undefined ? false : addUrl]);
  };
  // 同 pjfh，但恒做 URL 拼接。
  g.pj = function (json, rule) { return H('pj', [json, rule]); };
  // 取数组。
  g.pjfa = function (json, rule) { return H('pjfa', [json, rule]); };

  g.md5 = function (s) { return H('md5', [s]); };
  g.sha1 = function (s) { return H('sha1', [s]); };
  g.sha256 = function (s) { return H('sha256', [s]); };
  g.hmac256 = function (s, k) { return H('hmac256', [s, k]); };
  g.urlencode = function (s) { return H('urlencode', [s]); };
  g.urldecode = function (s) { return H('urldecode', [s]); };
  g.base64Encode = function (s) { return H('base64Encode', [s]); };
  g.base64Decode = function (s) { return H('base64Decode', [s]); };
  // GBK 站点的响应体是裸字节。脚本一般拿 req(url, {buffer: true}) 的 body，
  // 也可能直接喂已经变成字符串的响应。两种形态宿主都接受。
  g.gbkDecode = function (s) { return H('gbkDecode', [s]); };
  // RSA。签名按位置对齐 drpy 的 rsaX(mode, pub, encrypt, input, inBase64, key, outBase64)，
  // 这里只做转调，不给默认值——漏传参数时宿主能如实报错，比猜一个默认值更好排查。
  g.rsaX = function (mode, pub, encrypt, input, inBase64, key, outBase64) {
    return H('rsaX', [mode, pub, encrypt, input, inBase64, key, outBase64]);
  };
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

  g.aes = function (mode, encrypt, input, inBase64, key, iv, outBase64) {
    // 存量源全是按位置传的，签名不能动。但历史上有过一版按对象传的
    // 包装（第一参是对象），本机缓存里的老源可能还带着那种写法，
    // 所以这里留一条兼容分支，把对象摊成位置参数再转调。
    if (mode !== null && typeof mode === 'object') {
      var o = mode;
      return g.aes(
        o.mode || 'AES/CBC/PKCS5Padding',
        !!o.encrypt,
        o.input,
        !!o.inBase64,
        o.key,
        o.iv || '',
        !!o.outBase64
      );
    }
    return H('aes', [mode, encrypt, input, inBase64, key, iv, outBase64]);
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

  // ---- 模块加载 polyfill (drpy2 ES module support) ----
  var __qs_module_cache = {};
  function __qs_require(spec) {
    if (__qs_module_cache[spec]) return __qs_module_cache[spec];

    var baseUrl = g.__qs_base_url || '';
    var url;

    if (spec.indexOf('assets://') === 0) {
      var path = spec.substring('assets://'.length);
      if (baseUrl) {
        var b = baseUrl;
        if (b.charAt(b.length - 1) === '/') b = b.substring(0, b.length - 1);
        url = b + '/' + path;
      } else {
        url = spec;
      }
    } else if (spec.indexOf('http://') === 0 || spec.indexOf('https://') === 0) {
      url = spec;
    } else if (baseUrl) {
      var b = baseUrl;
      var li = b.lastIndexOf('/');
      if (li >= 0) b = b.substring(0, li + 1);
      url = b + spec;
    } else {
      url = spec;
    }

    var resp = req(url, { method: 'GET', timeoutMs: 15000 });
    var code = resp.content || '';

    // 用 Function 包装，把 export xxx = 转为 __m__.xxx =
    var transformed = code
      .replace(/exports+defaults+/g, '__m__.default=')
      .replace(/exports+{([^}]+)}/g, function(_, names) {
        return names.split(',').map(function(n) {
          n = n.trim();
          var parts = n.split(/s+ass+/);
          var local = parts[0].trim();
          var alias = (parts[1] || parts[0]).trim();
          return '__m__.' + alias + '=' + local + ';';
        }).join('');
      })
      .replace(/exports+(?:const|let|var|function)s+/g, '__m__.');

    var mod = {};
    var fn = Function('__m__', 'exports', 'module', 'require', transformed);
    fn(mod, mod, mod, __qs_require);

    __qs_module_cache[spec] = mod;
    return mod;
  }
  g.__qs_require = __qs_require;

})(globalThis);
''';
}
