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
import 'package:spider_js/src/child/sync_frame_io.dart';
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
      default:
        if (method.startsWith('spider.')) {
          return _invokeSpider(method.substring('spider.'.length), params);
        }
        throw _RpcFailure(ErrorCode.methodNotFound, '未知方法: $method');
    }
  }

  Map<String, Object?> _create(Map<String, Object?> params) {
    final instanceId = _requireString(params, 'instanceId');
    final script = params['script'];
    if (script is! String || script.isEmpty) {
      throw const _RpcFailure(
        ErrorCode.scriptLoadFailed,
        'spider.create 缺少 script',
      );
    }

    _instances.remove(instanceId)?.runtime.dispose();

    final runtime = _createRuntime(_limitsFrom(params['limits']));
    if (!runtime.init()) {
      runtime.dispose();
      throw _RpcFailure(
        ErrorCode.scriptLoadFailed,
        'JS 引擎不可用: ${runtime.lastError}',
      );
    }

    // 宿主函数要在脚本求值**之前**装好：drpy 源常在顶层就调 md5 之类。
    _installHostFunctions(runtime, instanceId);

    if (runtime.eval(script) == null && runtime.lastFailure != null) {
      final failure = runtime.lastFailure!;
      runtime.dispose();
      throw _RpcFailure(failure.code, failure.message, <String, Object?>{
        'stack': failure.stack,
      });
    }

    _instances[instanceId] = _Instance(runtime);

    // 有 init 就调一次，没有也不算错——不是每个源都实现它。
    final config = params['config'];
    if (config != null) {
      runtime.eval(
        'typeof init === "function" ? init(${jsonEncode(config)}) : null',
      );
    }

    return <String, Object?>{'capabilities': _capabilitiesOf(runtime)};
  }

  Map<String, Object?> _destroy(Map<String, Object?> params) {
    _instances.remove(_requireString(params, 'instanceId'))?.runtime.dispose();
    return <String, Object?>{};
  }

  /// 调脚本里的一个 Spider 方法。
  ///
  /// 结果在 JS 侧 `JSON.stringify` 后跨界——JSValue 只能以字符串跨 FFI，
  /// 见 `quickjs_wrapper.c` 的 FIXME。
  Object? _invokeSpider(String name, Map<String, Object?> params) {
    final instanceId = _requireString(params, 'instanceId');
    final instance = _instances[instanceId];
    if (instance == null) {
      throw _RpcFailure(ErrorCode.invalidState, '实例不存在: $instanceId');
    }

    final args = (params['args'] as List<Object?>? ?? const <Object?>[])
        .map(jsonEncode)
        .join(', ');
    final expr =
        'typeof $name === "function" '
        '? JSON.stringify($name($args)) '
        ': null';

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
  void dispose() {
    for (final instance in _instances.values) {
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
