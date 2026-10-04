/// Spider JS 运行时子进程的**同步**主循环。
///
/// 整个循环刻意不用 async。原因在 `sync_frame_io.dart` 讲过：脚本调 `req` 时
/// C 栈停在 `JS_Eval` 里回调 Dart，Dart 事件循环不转，异步 I/O 的响应永远送不
/// 到。所以宿主往返必须是阻塞的，而阻塞在子进程里完全无害——它整个存在的意义
/// 就是跑完这一次调用（ADR-001）。
///
/// 由此带来的要害是**重入**：`callHost` 写出请求后要继续读，而这期间宿主可能
/// 发来别的消息。分流规则见 `_awaitResponse`。
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:spider_js/src/child/drpy_host_functions.dart';
import 'package:spider_js/src/child/module_loader.dart';
import 'package:spider_js/src/child/sync_frame_io.dart';
import 'package:spider_js/src/drpy/type0_script.dart' show type0Script;
import 'package:spider_js/src/engine/js_runtime.dart';

/// 本子进程实现的协议版本（docs/08 §8）。
const int kProtocolVersion = 1;

/// 上报给宿主的能力位。
const List<String> kRuntimeFeatures = <String>['cancel', 'storage', 'progress'];

/// 宿主调用的返回：`result` 与 `error` 恰有一个非 null。
typedef HostCallOutcome = ({Object? result, Object? error});

/// 一个源实例：独立的 JsRuntime，独立的 Context 与资源上限。
class _Instance {
  _Instance(this.runtime);

  final JsRuntime runtime;
}

/// 管道在等宿主回话时断了。主循环据此干净退出，而不是把异常抛给脚本。
class ChildPipeClosed implements Exception {
  /// 构造。
  const ChildPipeClosed();

  @override
  String toString() => 'ChildPipeClosed: 等宿主回话时 stdin 已关闭';
}

/// 子进程主循环。
class RuntimeChild {
  /// 构造。[codec]、[createRuntime] 与 [installHostFunctions] 可注入，供测试在
  /// 没有真管道、没有 native 的情况下驱动整个循环。
  RuntimeChild({
    SyncFrameCodec? codec,
    JsRuntime Function(JsRuntimeLimits limits)? createRuntime,
    void Function(JsRuntime runtime, String instanceId, RuntimeChild child)?
    installHostFunctions,
  }) : _codec = codec ?? SyncFrameCodec(),
       _createRuntime =
           createRuntime ?? ((limits) => JsRuntime(limits: limits)),
       _installHostFunctionsFn =
           installHostFunctions ?? installDrpyHostFunctions;

  final SyncFrameCodec _codec;
  final JsRuntime Function(JsRuntimeLimits limits) _createRuntime;

  final Map<String, _Instance> _instances = <String, _Instance>{};

  /// 出站请求（Runtime → Host）的 id 空间，与宿主的 id 空间互相独立（docs/08 §2）。
  int _nextOutboundId = 1;

  /// 宿主回调期间收到的、不能就地处理的消息。本次调用返回后再消费。
  final List<Map<String, Object?>> _deferred = <Map<String, Object?>>[];

  /// 当前正在处理的宿主请求 id，用于比对 `$/cancelRequest`。
  int? _activeRequestId;

  bool _shuttingDown = false;

  /// 跑主循环，直到 stdin 关闭或收到 `runtime.shutdown`。
  void run() {
    while (!_shuttingDown) {
      final msg = _nextMessage();
      if (msg == null) return;
      _dispatch(msg);
    }
  }

  /// 取下一条待处理消息：先吃重入期间积压的，再阻塞读。
  ///
  /// 只有**流真的结束**才返回 null。畸形消息按 docs/08 §7.1 跳过而不是当成
  /// EOF——否则宿主发错一条，整个子进程就没了，而它托管着好几个源。
  /// 不回 parse error 是因为畸形消息没有可关联的 id，宿主收到也匹配不上。
  Map<String, Object?>? _nextMessage() {
    if (_deferred.isNotEmpty) return _deferred.removeAt(0);
    for (;;) {
      final raw = _codec.readFrame();
      if (raw == null) return null;
      final msg = _decode(raw);
      if (msg != null) return msg;
    }
  }

  Map<String, Object?>? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  // ---- 出站：宿主 API 调用 ------------------------------------------------

  /// 同步调一次宿主 API，阻塞到回话为止。
  ///
  /// 这是 `req` / `local.*` 的唯一出口。抛 [ChildPipeClosed] 表示管道断了。
  HostCallOutcome callHost(String method, Map<String, Object?> params) {
    final id = _nextOutboundId++;
    _write(<String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });
    return _awaitResponse(id);
  }

  /// 阻塞读到 id 为 [id] 的响应为止，期间按类型分流其它消息。
  ///
  /// - 匹配 id 的响应：就是要等的，返回
  /// - `$/cancelRequest`：**立即处理**。取消是 docs/08 §3.4 的必须项，排队等
  ///   于没有——用户改搜索词时正卡在这条 req 上，等它自然结束就毫无意义
  /// - 其余：入队。此刻 C 栈还停在 JS_Eval 里，就地处理会重入进另一次求值
  HostCallOutcome _awaitResponse(int id) {
    for (;;) {
      final raw = _codec.readFrame();
      if (raw == null) throw const ChildPipeClosed();

      final msg = _decode(raw);
      if (msg == null) continue;

      if (msg['id'] == id &&
          (msg.containsKey('result') || msg.containsKey('error'))) {
        return (result: msg['result'], error: msg['error']);
      }

      if (msg['method'] == r'$/cancelRequest') {
        _handleCancel(msg);
        continue;
      }

      _deferred.add(msg);
    }
  }

  /// 处理取消通知。
  ///
  /// 只在**当前在途请求**被点名时才动手，否则会误伤别的调用。做法是把在跑的
  /// 那个 runtime 的时限压到最小，让 interrupt 处理器尽快掐断脚本。
  ///
  /// 注意能力边界：取消只能在**宿主调用的间隙**被看到——脚本在纯计算死循环里
  /// 时我们根本没在读 stdin，那种情况由 [JsRuntimeLimits.evalTimeout] 兜底。
  void _handleCancel(Map<String, Object?> msg) {
    final params = msg['params'];
    if (params is! Map<String, Object?>) return;
    if (params['id'] != _activeRequestId) return;

    for (final instance in _instances.values) {
      instance.runtime.cancel();
    }
  }

  // ---- 入站：宿主 → 运行时 ------------------------------------------------

  void _dispatch(Map<String, Object?> msg) {
    final method = msg['method'];
    if (method is! String) return; // 响应或畸形消息，子进程不发请求给自己

    final id = msg['id'];
    final params = msg['params'] is Map<String, Object?>
        ? msg['params']! as Map<String, Object?>
        : const <String, Object?>{};

    // 通知没有 id，处理完不回话。
    if (id is! int) {
      if (method == 'runtime.shutdown') _shuttingDown = true;
      return;
    }

    _activeRequestId = id;
    try {
      final result = _handle(method, params);
      _respondResult(id, result);
    } on _RpcFailure catch (e) {
      _respondError(id, e.code, e.message, e.data);
    } on ChildPipeClosed {
      // 管道断了，回话也送不出去，直接让主循环收工。
      _shuttingDown = true;
    } on Object catch (e) {
      _respondError(id, ErrorCode.internalError, '运行时内部错误: $e', null);
    } finally {
      _activeRequestId = null;
    }
  }

  Object? _handle(String method, Map<String, Object?> params) {
    switch (method) {
      case 'runtime.handshake':
        return <String, Object?>{
          'protocolVersion': kProtocolVersion,
          'runtimeVersion': '0.1.0',
          'features': kRuntimeFeatures,
        };
      case 'runtime.ping':
        return <String, Object?>{'ts': 0};
      case 'runtime.shutdown':
        _shuttingDown = true;
        return <String, Object?>{};
      case 'runtime.stats':
        return <String, Object?>{
          'rssBytes': 0,
          'contexts': _instances.length,
          'pendingCalls': _deferred.length,
          'uptimeMs': 0,
        };
      case 'spider.create':
        return _create(params);
      case 'spider.destroy':
        return _destroy(params);
      case 'spider.init':
        return _initInstance(params);
      case 'spider.eval':
        return _evalExpr(params);
      default:
        if (method.startsWith('spider.')) {
          return _invokeSpider(method.substring('spider.'.length), params);
        }
        throw _RpcFailure(ErrorCode.methodNotFound, '未知方法: $method');
    }
  }

  Map<String, Object?> _create(Map<String, Object?> params) {
    final instanceId = _requireString(params, 'instanceId');

    // `builtin: 'type0'` 表示「用内置通用脚本」，此时宿主不传 script——
    // type=0 的 `api` 是站点基础地址而非脚本路径，宿主无从加载脚本。
    // 内置脚本由本运行时持有，所以这个替换只能在子进程侧做。
    final builtin = params['builtin'] as String?;
    final rawScript = params['script'];
    final String script;
    if (rawScript is String && rawScript.isNotEmpty) {
      script = rawScript;
    } else if (builtin == 'type0') {
      script = type0Script;
    } else {
      throw const _RpcFailure(
        ErrorCode.scriptLoadFailed,
        'spider.create 缺少 script（也没给 builtin 兜底）',
      );
    }

    _recycle(_instances.remove(instanceId)?.runtime);

    final limits = _limitsFrom(params['limits']);
    final runtime = _createRuntime(limits);
    if (!runtime.init()) {
      _recycle(runtime);
      throw _RpcFailure(
        ErrorCode.scriptLoadFailed,
        'JS 引擎不可用: ${runtime.lastError}',
      );
    }

    // 宿主函数要在脚本求值**之前**装好：drpy 源常在顶层就调 md5 之类。
    _installHostFunctions(runtime, instanceId);

    // 设置 base URL（用于 assets:// 协议解析）。**无条件**调用：复用停放实例时
    // 必须显式覆盖或清空，否则会沿用上一个源的 base URL。
    runtime.setBaseUrl(params['baseUrl'] as String?);

    // --- 模块加载：解析 import → 预取依赖 → 注入全局 → 清理脚本 ---
    final (deps, rawCleaned) = parseImports(script);
    final cleanedScript = stripExports(rawCleaned);
    final baseUrl = params['baseUrl'] as String?;

    if (deps.isNotEmpty) {
      // 预取所有依赖，注入到 globalThis。任一依赖失败都要**明确报错**：
      // 静默跳过会让主脚本带着缺失的全局跑起来，报出「cheerio is not
      // defined」这种查不出根因的错。
      for (final dep in deps) {
        try {
          final url = resolveModuleUrl(
            dep.specifier,
            baseUrl,
            params['configBaseUrl'] as String?,
          );
          final outcome = callHost('host.fetch', <String, Object?>{
            'instanceId': instanceId,
            'url': url,
            'method': 'GET',
            'timeoutMs': 15000,
          });
          if (outcome.error != null) {
            throw StateError('拉取失败: ${outcome.error}');
          }
          final result = outcome.result;
          final body = result is Map ? (result['body'] ?? '') : '';
          if (body is! String || body.isEmpty) {
            throw StateError('内容为空');
          }

          final loaderCode = generateModuleLoader(
            body,
            dep.varName,
            isDefault: dep.isDefault,
            namedImports: dep.namedImports,
          );
          runtime.eval(loaderCode);
          if (runtime.lastFailure != null) {
            throw StateError(runtime.lastFailure.toString());
          }
        } on Object catch (e) {
          _recycle(runtime);
          throw _RpcFailure(
            ErrorCode.scriptLoadFailed,
            '依赖 ${dep.specifier} 加载失败: $e',
          );
        }
      }

      // 用清理后的脚本（import/export 已移除）
      if (runtime.eval(cleanedScript) == null && runtime.lastFailure != null) {
        final failure = runtime.lastFailure!;
        _recycle(runtime);
        throw _RpcFailure(failure.code, failure.message, <String, Object?>{
          'stack': failure.stack,
        });
      }
    } else {
      // 无 import 语句，直接执行清理后的脚本（stripExports 已剥掉 export ...）。
      if (runtime.eval(cleanedScript) == null && runtime.lastFailure != null) {
        final failure = runtime.lastFailure!;
        _recycle(runtime);
        throw _RpcFailure(failure.code, failure.message, <String, Object?>{
          'stack': failure.stack,
        });
      }
    }

    _instances[instanceId] = _Instance(runtime);

    // 有 init 就调一次，没有也不算错——不是每个源都实现它。
    final config = params['config'];
    if (config != null) {
      // 结果丢弃，但**必须走 async 包装**：`init` 里通常要按 ext 建规则、
      // 发一次探测请求，写成 `async function init` 很常见，顶层 `await`
      // 在脚本 eval 里是语法错误。
      runtime.eval(
        '(async function () { '
        'if (typeof init !== "function") return null; '
        'await init(${jsonEncode(config)}); '
        'return null; '
        '})()',
      );
    }

    return <String, Object?>{'capabilities': _capabilitiesOf(runtime)};
  }

  Map<String, Object?> _destroy(Map<String, Object?> params) {
    _recycle(_instances.remove(_requireString(params, 'instanceId'))?.runtime);
    return <String, Object?>{};
  }

  /// 收一个用完的 runtime：封存（释放 context）后弃用。
  ///
  /// 这是「`spider.destroy` 不再打死子进程」的落点——见 [JsRuntime.park] 里那份
  /// 判定证据。
  ///
  /// **不复用**：实测发现释放过 context 的 runtime 已被污染——再往上挂一个新
  /// context、加载 drpy2 依赖时会撞 `Assertion failed: js_rc(p->shape)->ref_count
  /// == 1, file quickjs.c, line 9235`（shape 是 runtime 级对象，跨 context 共享，
  /// 而这份 build 的引用计数本就不可靠，见 README「边界约定」）。所以每个源一个
  /// 全新 runtime，用完只放 context、把壳弃掉。
  void _recycle(JsRuntime? runtime) {
    if (runtime == null) return;
    runtime.park();
    // 没 init 成功过的实例没有 context 可放，直接丢掉引用即可。
    if (!runtime.isParked) runtime.dispose();
  }

  /// 调用实例的 init() 函数。
  Map<String, Object?> _initInstance(Map<String, Object?> params) {
    final instanceId = _requireString(params, 'instanceId');
    final instance = _instances[instanceId];
    if (instance == null) {
      throw _RpcFailure(ErrorCode.invalidState, '实例不存在: $instanceId');
    }
    final config = params['config'];
    final configArg = config != null ? jsonEncode(config) : 'null';
    final raw = instance.runtime.eval(
      '(async function () { '
      'if (typeof init !== "function") return null; '
      'return JSON.stringify(await init($configArg) ?? null); '
      '})()',
    );
    if (raw == null && instance.runtime.lastFailure != null) {
      final f = instance.runtime.lastFailure!;
      throw _RpcFailure(f.code, f.message, <String, Object?>{'stack': f.stack});
    }
    if (raw == null || raw == 'null' || raw == 'undefined') {
      return <String, Object?>{};
    }
    try {
      return jsonDecode(raw) as Map<String, Object?>;
    } on FormatException {
      return <String, Object?>{'raw': raw};
    }
  }

  /// 在实例上下文中执行任意 JS 表达式并返回字符串结果。
  Map<String, Object?> _evalExpr(Map<String, Object?> params) {
    final instanceId = _requireString(params, 'instanceId');
    final instance = _instances[instanceId];
    if (instance == null) {
      throw _RpcFailure(ErrorCode.invalidState, '实例不存在: $instanceId');
    }
    final code = _requireString(params, 'code');
    final raw = instance.runtime.eval(code);
    if (raw == null && instance.runtime.lastFailure != null) {
      final f = instance.runtime.lastFailure!;
      throw _RpcFailure(f.code, f.message, <String, Object?>{'stack': f.stack});
    }
    return <String, Object?>{'result': raw};
  }

  /// 调脚本里的一个 Spider 方法。
  ///
  /// 结果在 JS 侧 `JSON.stringify` 后跨界——JSValue 只能以字符串跨 FFI，
  /// 见 `quickjs_wrapper.c` 里标注的那处待修复问题。
  Object? _invokeSpider(String name, Map<String, Object?> params) {
    final instanceId = _requireString(params, 'instanceId');
    final instance = _instances[instanceId];
    if (instance == null) {
      throw _RpcFailure(ErrorCode.invalidState, '实例不存在: $instanceId');
    }

    final argValues = params['args'] as List<Object?>? ?? const <Object?>[];
    final args = argValues.map(jsonEncode).join(', ');
    // 宿主把分类详情和视频详情都挂在 `spider.detail` 上，用参数个数区分：
    // `[tid, page]` 是分类列表，`[ids]` 是视频详情。drpy 脚本里分别对应
    // `category(tid, pg)` 和 `detail(ids)`，必须路由到正确的函数。
    final effectiveName = name == 'detail' && argValues.length >= 2
        ? 'category'
        : name;
    final expr = _spiderCallExpr(effectiveName, args);

    final raw = instance.runtime.eval(expr);
    final failure = instance.runtime.lastFailure;
    if (failure != null) {
      throw _RpcFailure(failure.code, failure.message, <String, Object?>{
        'stack': failure.stack,
      });
    }
    if (raw == null || raw == 'null' || raw == 'undefined') return null;

    try {
      return jsonDecode(raw);
    } on FormatException {
      // 脚本返回了不可序列化的东西。原文透出去，比吞掉有用。
      return raw;
    }
  }

  /// 生成调用脚本顶层函数的表达式。
  ///
  /// drpy 系脚本把首页拆成 `home()`（分类）和 `homeVod()`（推荐列表）两个
  /// 函数；宿主约定 `spider.home` 一次调用返回 `{class, list}`，所以这里把
  /// 两者合并。非 drpy 脚本（无 `homeVod`）退化为只调 `home()`。
  ///
  /// 两条纪律，都是为了「源看起来能用、其实返回空数据」这种最难查的故障：
  ///
  /// - **一律 `await`**。`async function home(){...}` 在源里很常见（本仓内置的
  ///   `type0Script` 就是），不 await 拿到的是 Promise，`JSON.stringify` 会把它
  ///   变成 `"{}"`——调用成功、结果为空、全程不报错。
  /// - **字符串与对象都接受**。drpy 约定方法返回 JSON 字符串，但也有源直接返回
  ///   对象。以前对 `home` 硬编码 `JSON.parse`、对其余硬编码 `JSON.stringify`，
  ///   换个形态就当场抛 SyntaxError。
  static String _spiderCallExpr(String name, String args) {
    if (name == 'home') {
      return '(async function () { '
          'if (typeof home !== "function") return null; '
          'var __o = {}; '
          'var __h = await home($args); '
          'if (__h) __o = Object.assign(__o, '
          '  typeof __h === "string" ? JSON.parse(__h) : __h); '
          'if (typeof homeVod === "function") { '
          'var __v = await homeVod($args); '
          'if (__v) __o = Object.assign(__o, '
          '  typeof __v === "string" ? JSON.parse(__v) : __v); '
          '} '
          'return JSON.stringify(__o); '
          '})()';
    }
    return '(async function () { '
        'if (typeof $name !== "function") return null; '
        'return JSON.stringify(await $name($args)); '
        '})()';
  }

  /// 探测脚本实现了哪些 Spider 方法，供宿主按能力位派发。
  List<String> _capabilitiesOf(JsRuntime runtime) {
    const candidates = <String>[
      'home',
      'homeVideoContent',
      'category',
      'detail',
      'search',
      'play',
      'live',
      'isVideoFormat',
      'manualVideoCheck',
      'action',
    ];
    final probe = candidates
        .map((n) => '(typeof $n === "function" ? "$n" : "")')
        .join(',');
    final raw = runtime.eval('[$probe].filter(Boolean).join(",")');
    if (raw == null || raw.isEmpty) return const <String>[];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  /// 把走宿主的 drpy 函数装进这个实例的桥。
  void _installHostFunctions(JsRuntime runtime, String instanceId) {
    _installHostFunctionsFn(runtime, instanceId, this);
  }

  final void Function(JsRuntime runtime, String instanceId, RuntimeChild child)
  _installHostFunctionsFn;

  // ---- 收发 ---------------------------------------------------------------

  void _respondResult(int id, Object? result) {
    _write(<String, Object?>{'jsonrpc': '2.0', 'id': id, 'result': result});
  }

  void _respondError(
    int id,
    ErrorCode code,
    String message,
    Map<String, Object?>? data,
  ) {
    _write(<String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'error': <String, Object?>{
        'code': code.value,
        'message': message,
        'data': ?data,
      },
    });
  }

  void _write(Map<String, Object?> msg) => _codec.writeFrame(jsonEncode(msg));

  // ---- 杂项 ---------------------------------------------------------------

  static String _requireString(Map<String, Object?> params, String key) {
    final v = params[key];
    if (v is String && v.isNotEmpty) return v;
    throw _RpcFailure(ErrorCode.invalidArgument, '缺少参数: $key');
  }

  /// 把 docs/08 §3.2 的 `limits` 映射成 [JsRuntimeLimits]。
  static JsRuntimeLimits _limitsFrom(Object? raw) {
    if (raw is! Map<String, Object?>) return const JsRuntimeLimits();
    const fallback = JsRuntimeLimits();
    final timeoutMs = raw['timeoutMs'];
    final memoryMB = raw['memoryMB'];
    return JsRuntimeLimits(
      evalTimeout: timeoutMs is int && timeoutMs > 0
          ? Duration(milliseconds: timeoutMs)
          : fallback.evalTimeout,
      memoryBytes: memoryMB is int && memoryMB > 0
          ? memoryMB * 1024 * 1024
          : fallback.memoryBytes,
      stackBytes: fallback.stackBytes,
    );
  }

  /// 释放全部实例。
  ///
  /// 先 [JsRuntime.park] 再 [JsRuntime.dispose]：**不能直接 dispose**。还活着的
  /// 实例没被 park 过，直接 dispose 会走 `JS_FreeRuntime`——正是那个会 abort 的
  /// 调用（见 [JsRuntime.park]）。park 把 context 放掉并封存壳，dispose 就只丢
  /// 引用。子进程收尾这一次也一样要避开。
  void dispose() {
    for (final instance in _instances.values) {
      instance.runtime.park();
      instance.runtime.dispose();
    }
    _instances.clear();
  }
}

/// 内部用的失败信号，[RuntimeChild._dispatch] 把它转成 JSON-RPC error。
class _RpcFailure implements Exception {
  const _RpcFailure(this.code, this.message, [this.data]);

  final ErrorCode code;
  final String message;
  final Map<String, Object?>? data;
}
