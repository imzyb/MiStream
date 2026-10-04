/// Spider 运行时子进程的宿主侧生命周期管理。
///
/// 职责（docs/08-RPC协议.md §3.1、§6）：
/// - 启动子进程 + `runtime.handshake` 握手
/// - 心跳（每 15s `runtime.ping`，连续 3 次无响应判失联）
/// - 请求派发（经 [StdioRpcChannel]）
/// - 失败退避重启（1s→2s→4s→8s→16s，5 次后停止）
/// - 熔断：连续失败过多时停止自动重启，UI 提示手动重试
library;

import 'dart:async';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

import 'package:spider_host/src/host/host_api.dart';
import 'package:spider_host/src/rpc/rpc_message.dart';
import 'package:spider_host/src/rpc/stdio_rpc_channel.dart';

/// 心跳间隔（docs/08 §6：Host 每 15s 发 ping）。
const Duration kHeartbeatInterval = Duration(seconds: 15);

/// 连续多少次无响应判定失联（3 次 × 15s = 45s）。
const int kHeartbeatMissLimit = 3;

/// 握手超时（docs/08 §6：启动后 5s 内必须完成）。
const Duration kHandshakeTimeout = Duration(seconds: 5);

/// 优雅退出宽限（docs/08 §6：3s 内未退出则强杀）。
const Duration kGracefulShutdownMs = Duration(seconds: 3);

/// 退避重启的最大尝试次数（docs/08 §6：连续 5 次失败后停止）。
const int kMaxRestartAttempts = 5;

/// 握手结果。
class HandshakeResult {
  /// 构造握手结果。
  const HandshakeResult({
    required this.protocolVersion,
    required this.runtimeVersion,
    required this.features,
  });

  /// 从响应解码。
  factory HandshakeResult.fromResult(Object? result) {
    final map = result is Map<String, Object?>
        ? result
        : const <String, Object?>{};
    return HandshakeResult(
      protocolVersion: (map['protocolVersion'] as num?)?.toInt() ?? 0,
      runtimeVersion: map['runtimeVersion'] as String? ?? '',
      features: (map['features'] as List<Object?>?)?.cast<String>() ?? const [],
    );
  }

  /// 对端协议版本。
  final int protocolVersion;

  /// 对端运行时版本。
  final String runtimeVersion;

  /// 对端能力位交集。
  final List<String> features;
}

/// 启动子进程的抽象，便于测试注入 fake。
///
/// 返回 `stdin`（写入子进程的输入）、`stdout`（读取子进程的输出）、
/// `exitCode`（子进程退出码）和 `kill`（终止函数）。
typedef ProcessLauncher =
    Future<
      ({
        IOSink stdin,
        Stream<List<int>> stdout,
        Future<int> exitCode,
        bool Function([ProcessSignal signal]) kill,
      })
    >
    Function(
      String executable,
      List<String> arguments,
    );

/// 默认启动器：用 [Process.start] 启动。
Future<
  ({
    IOSink stdin,
    Stream<List<int>> stdout,
    Future<int> exitCode,
    bool Function([ProcessSignal signal]) kill,
  })
>
defaultProcessLauncher(
  String executable,
  List<String> arguments,
) async {
  final process = await Process.start(
    executable,
    arguments,
  );
  return (
    stdin: process.stdin,
    stdout: process.stdout,
    exitCode: process.exitCode,
    kill: process.kill,
  );
}

/// 一个子进程最多托管多少个源的「建-用-毁」周期，到点就整进程换新。
///
/// 为什么必须换：这份 assert 版 `libquickjs.dll` 上 `JS_FreeRuntime` 与
/// `JS_RunGC` 都会断言 abort，所以子进程只能「释放 context + 弃用 runtime」
/// （见 `runtimes/spider_js/lib/src/engine/js_runtime.dart` 的 `park`）。而实测
/// **context 释放并不真把内存还回来**——每个源约留 10MB。进程换新是唯一能把
/// 这块内存交还 OS 的手段，代价只是下一次 `spider.create` 重付一次 drpy2 加载。
///
/// 取 8 是「一屏订阅源试一轮」的量级：换新太频繁会把 drpy2 加载（约 0.4s）
/// 摊到每次请求上，太少则内存涨得快。
const int kSourceTearDownsPerProcess = 8;

/// Spider 运行时子进程的宿主侧管理。
///
/// 通过 [start] 启动并握手，[call] 分发请求，[dispose] 优雅退出。进程崩溃或
/// 失联时自动按退避策略重启；超过 [kMaxRestartAttempts] 次后转为不可用
/// （熔断），等待 [reset] 手动重试。
class SpiderHost {
  /// 构造宿主。
  ///
  /// [maxRestartAttempts] 控制最大退避重启次数（默认 [kMaxRestartAttempts]）。
  /// [backoffFor] 可传入自定义退避策略，用于测试缩短等待时间。
  /// [handshakeTimeout] 控制握手超时（默认 [kHandshakeTimeout]）。
  /// [sourceTearDownsPerProcess] 控制换新节奏（默认 [kSourceTearDownsPerProcess]）。
  SpiderHost({
    required this.executable,
    required this.arguments,
    this.localProtocolVersion = 1,
    this.appVersion = 'dev',
    this.maxRestartAttempts = kMaxRestartAttempts,
    this.handshakeTimeout = kHandshakeTimeout,
    this.sourceTearDownsPerProcess = kSourceTearDownsPerProcess,
    this.hostApi,
    Duration Function(int attempt)? backoffFor,
    ProcessLauncher? launcher,
  }) : _launcher = launcher ?? defaultProcessLauncher,
       _backoffFor =
           backoffFor ??
           ((int attempt) => Duration(seconds: 1 << attempt.clamp(0, 4)));

  /// 子进程可执行文件路径。
  final String executable;

  /// 传给子进程的参数。
  final List<String> arguments;

  /// 宿主侧支持的协议版本，握手时与子进程协商。
  final int localProtocolVersion;

  /// 宿主应用版本，握手时上报给子进程。
  final String appVersion;

  /// 最大退避重启次数，超过即熔断。
  final int maxRestartAttempts;

  /// 握手超时。
  final Duration handshakeTimeout;

  /// 每托管这么多个源的销毁周期就换新一次子进程，见 [kSourceTearDownsPerProcess]。
  final int sourceTearDownsPerProcess;

  /// 宿主 API 实现，服务子进程发来的 `host.*` 请求。
  ///
  /// 可空是为了让只做 Host → Runtime 单向调用的测试不必造一个；生产装配必须
  /// 传，否则脚本里的 `req` / `local.*` 全部拿到 METHOD_NOT_FOUND。
  final HostApi? hostApi;

  final ProcessLauncher _launcher;
  final Duration Function(int attempt) _backoffFor;

  StreamSubscription<RpcRequest>? _hostApiSub;

  Future<int>? _exitCode;
  bool Function(ProcessSignal signal) _kill = (_) => false;
  StdioRpcChannel? _channel;
  List<String> _features = const [];
  bool _handshaken = false;
  bool _disposed = false;

  int _restartAttempt = 0;
  Timer? _heartbeatTimer;
  Timer? _restartTimer;
  int _missedHeartbeats = 0;

  /// 当前进程的退出**是否已经处理过**。
  ///
  /// 换新时会先主动关进程（调一次 [_onProcessExit]），老进程随后真正退出又
  /// 会触发一次（挂在 `exitCode` 上的回调）。若两次都照单全收，第二次会落在
  /// 第一次重启之后、再拉起一个进程——假进程测试里两次几乎同时发生，被
  /// `_restartTimer != null` 挡住，真进程退出有延迟就暴露了。
  bool _exitHandled = false;

  /// 本进程已经收掉的源实例数，到 [sourceTearDownsPerProcess] 就换新。
  int _sourceTearDowns = 0;

  /// 当前活着的实例数（`spider.create` 减 `spider.destroy`）。
  ///
  /// 换新会连带杀掉所有活着的实例，所以只在归零时才动手。
  int _liveInstances = 0;

  bool _recycling = false;

  /// 熔断状态：连续失败达到上限后置 true。
  bool _tripped = false;

  /// 等就绪的等待者 → 各自的超时定时器。见 [waitReady]。
  final Map<Completer<bool>, Timer> _readyWaiters = <Completer<bool>, Timer>{};

  /// 是否已握手成功。
  bool get isReady => _handshaken && !_disposed;

  /// 是否已熔断（不再自动重启）。
  bool get isTripped => _tripped;

  /// 当前活着的 Spider 实例数。
  int get liveInstanceCount => _liveInstances;

  /// 当前能力位。
  List<String> get features => List.unmodifiable(_features);

  /// 等待就绪。
  ///
  /// 已就绪立即返回 `true`；熔断、已释放或超过 [timeout] 返回 `false`。
  ///
  /// 存在的理由是「按计划换新」和退避重启都有窗口期：这期间 [isReady] 是
  /// `false`，但**同一个子进程马上就会回来**。调用方若把 `isReady == false`
  /// 直接当成「这个宿主废了」而另起一个，就会同时跑两个子进程、两套实例，
  /// 旧的还在后台重启——谁都不知道对方存在。想复用同一个宿主就先等它。
  Future<bool> waitReady({Duration timeout = const Duration(seconds: 20)}) {
    if (isReady) return Future.value(true);
    if (_tripped || _disposed) return Future.value(false);
    final completer = Completer<bool>();
    _readyWaiters[completer] = Timer(
      timeout,
      () => _settleReady(completer, false),
    );
    return completer.future;
  }

  /// 唤醒**全部**等待者。
  void _notifyReady(bool ready) {
    for (final completer in List<Completer<bool>>.of(_readyWaiters.keys)) {
      _settleReady(completer, ready);
    }
  }

  /// 结算一个等待者：撤掉它的超时定时器并给出结果。
  ///
  /// 先从表里摘除再判断，天然幂等——「定时器先到」和「状态先变」只会有一个
  /// 生效，另一个变成空操作。
  void _settleReady(Completer<bool> completer, bool ready) {
    final timer = _readyWaiters.remove(completer);
    if (timer == null) return;
    timer.cancel();
    if (!completer.isCompleted) completer.complete(ready);
  }

  /// 启动子进程并握手。
  Future<Result<HandshakeResult, AppError>> start() async {
    if (_disposed) {
      return const Err(
        LocalError(
          code: ErrorCode.invalidState,
          message: 'SpiderHost 已释放',
        ),
      );
    }

    try {
      final proc = await _launcher(executable, arguments);
      _exitCode = proc.exitCode;
      _kill = proc.kill;
      // 新进程：它的退出还没处理过，重置幂等标记。
      _exitHandled = false;

      final channel = StdioRpcChannel(
        stdin: proc.stdout,
        stdout: proc.stdin,
      );
      _channel = channel;
      _serveHostApi(channel);
      // 进程退出是异步事件，这里只挂回调、不等它——等它就永远不会返回。
      unawaited(proc.exitCode.then((_) => _onProcessExit('进程退出')));

      final handshake = await channel
          .call(
            'runtime.handshake',
            params: {
              'protocolVersion': localProtocolVersion,
              'appVersion': appVersion,
              'features': const ['cancel', 'sniff', 'progress', 'storage'],
            },
            timeout: handshakeTimeout,
          )
          .timeout(
            handshakeTimeout,
            onTimeout: () => const Err(
              RemoteError(
                code: ErrorCode.runtimeCrashed,
                message: '握手超时',
              ),
            ),
          );

      if (handshake.isErr) {
        await _killProcess();
        _onProcessExit('握手失败: ${handshake.errorOrNull?.message}');
        return Err<HandshakeResult, AppError>(handshake.errorOrNull!);
      }

      final result = HandshakeResult.fromResult(handshake.valueOrNull);
      if (result.protocolVersion != localProtocolVersion) {
        await _killProcess();
        _onProcessExit('协议版本不匹配');
        return Err(
          RemoteError(
            code: ErrorCode.protocolVersionMismatch,
            message:
                '协议版本不兼容: 本地 $localProtocolVersion '
                'vs 对端 ${result.protocolVersion}',
          ),
        );
      }

      _features = result.features;
      _handshaken = true;
      _restartAttempt = 0;
      _tripped = false;
      // 新进程，换新计数从头开始。
      _sourceTearDowns = 0;
      _liveInstances = 0;
      _startHeartbeat();
      _notifyReady(true);
      return Ok(result);
    } on Object catch (e, st) {
      // 走到这里说明**启动阶段**就抛了异常（exe 不存在、权限被拒、端口耗尽…），
      // 进程根本没起来——上面那些「进程退出 → 重启」的路径一条都不会走。
      // 必须在这里自己挂退避重启，否则宿主会永久停在未就绪态。
      //
      // 这不是假想：2 小时长跑第 8660 轮就是这么红的。I: 盘的
      // `.dart_tool/package_config.json` 被系统拒绝访问，子进程起不来，
      // 而宿主不重试，此后每一轮都失败。
      //
      // 退避次数与熔断语义跟「进程崩溃」完全一致（同一把 [_scheduleRestart]）：
      // 连续 [maxRestartAttempts] 次起不来照样熔断，等外部 [reset]。
      _notifyReady(false);
      _scheduleRestart('启动失败: ${AppError.from(e, st).message}');
      return Err(AppError.from(e, st));
    }
  }

  /// 分发一个 RPC 请求。
  ///
  /// [cancelOn] 完成时向子进程发 `$/cancelRequest` 并立刻以 `REQUEST_CANCELLED`
  /// 返回。聚合搜索里用户改词就靠它释放在途请求（docs/08 §3.4）。
  Future<Result<Object?, AppError>> call(
    String method, {
    Map<String, Object?> params = const {},
    Duration? timeout,
    Future<void>? cancelOn,
  }) async {
    if (!isReady || _channel == null) {
      return const Err(
        RemoteError(
          code: ErrorCode.runtimeNotReady,
          message: '运行时未就绪',
        ),
      );
    }
    final result = await _channel!.call(
      method,
      params: params,
      timeout: timeout,
      cancelOn: cancelOn,
    );
    if (result.isOk) _trackInstanceLifecycle(method);
    return result.mapErr((e) => e);
  }

  /// 数实例生命周期，并在攒够 [sourceTearDownsPerProcess] 个销毁后换新子进程。
  ///
  /// 只在**成功**的 create/destroy 上计数：失败的那次没有真的建/毁实例，算进去
  /// 会让计数与子进程实际状态脱节，`_liveInstances` 归零判断也就失效了。
  void _trackInstanceLifecycle(String method) {
    switch (method) {
      case 'spider.create':
        _liveInstances++;
      case 'spider.destroy':
        if (_liveInstances > 0) _liveInstances--;
        _sourceTearDowns++;
        // 攒够就换新。要求此刻没有活实例：换新等于把子进程整个换掉，带着别人的
        // 实例一起走会变成难查的「调用凭空失败」。
        if (_sourceTearDowns >= sourceTearDownsPerProcess &&
            _liveInstances == 0) {
          unawaited(_recycleProcess());
        }
    }
  }

  /// 主动换新子进程，把那份留着的 JS 堆交还 OS。
  ///
  /// 走的是正常重启通道（[runtime.shutdown] → 进程退出 → [_scheduleRestart]），
  /// 但先把 `_restartAttempt` 清零：换新是计划内行为，不该消耗退避额度、更不该
  /// 把进程推向熔断。反过来，如果换新后起不来，退避计数会从 1 重新开始，该熔断
  /// 还是会熔断。
  Future<void> _recycleProcess() async {
    if (_disposed || _recycling) return;
    _recycling = true;
    _sourceTearDowns = 0;
    _restartAttempt = 0;
    try {
      await _channel?.notify('runtime.shutdown', params: {'graceMs': 1000});
      if (_disposed) return;
      _onProcessExit('按计划换新（每 $sourceTearDownsPerProcess 个源）');
    } finally {
      _recycling = false;
    }
  }

  /// 发送通知。
  Future<void> notify(String method, {Map<String, Object?> params = const {}}) {
    return _channel?.notify(method, params: params) ?? Future.value();
  }

  /// 把子进程发来的宿主 API 请求接到 [hostApi] 上。
  ///
  /// 这是宿主 API 的**唯一**服务点：脚本里的 `req` / `local.*` 最终都落到这里。
  /// 没注入 [hostApi] 时一律回 METHOD_NOT_FOUND，而不是让子进程一直等——
  /// 悬着的请求会把子进程卡在阻塞读上，比明确报错难查得多。
  void _serveHostApi(StdioRpcChannel channel) {
    unawaited(_hostApiSub?.cancel());
    _hostApiSub = channel.incomingRequests.listen((request) async {
      final api = hostApi;
      if (api == null) {
        channel.respond(
          RpcResponse.error(
            id: request.id,
            error: const RemoteError(
              code: ErrorCode.methodNotFound,
              message: '未注入 HostApi，宿主 API 不可用',
            ),
          ),
        );
        return;
      }

      final (result, error) = await _handleSafely(api, request);
      channel.respond(
        error != null
            ? RpcResponse.error(id: request.id, error: error)
            : RpcResponse.result(id: request.id, result: result),
      );
    });
  }

  /// 调 [HostApi.handle] 并把各种失败形态归一成 [RemoteError]。
  ///
  /// `handle` 的错误位可能是 `AppError`，也可能是「未知方法」那种裸字符串；
  /// 处理器本身还可能抛。任何一种都必须变成一条应答——子进程在同步阻塞读上
  /// 等着，少回一条它就永远醒不过来。
  Future<(Object?, RemoteError?)> _handleSafely(
    HostApi api,
    RpcRequest request,
  ) async {
    try {
      final (result, error) = await api.handle(request.method, request.params);
      if (error == null) return (result, null);
      return (
        null,
        switch (error) {
          final RemoteError e => e,
          final AppError e => RemoteError(code: e.code, message: e.message),
          _ => RemoteError(
            code: ErrorCode.methodNotFound,
            message: error.toString(),
          ),
        },
      );
    } on Object catch (e) {
      return (
        null,
        RemoteError(code: ErrorCode.internalError, message: '宿主 API 处理失败: $e'),
      );
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(kHeartbeatInterval, (_) async {
      final channel = _channel;
      if (channel == null || !_handshaken) return;
      // 有在途请求时子进程正忙于长任务（JVM 首次 jar 转换可达数十秒），
      // 不是失联——跳过本次心跳，避免把健康的子进程误杀重启。
      if (channel.pendingCount > 0) return;
      final result = await channel.call(
        'runtime.ping',
        timeout: const Duration(seconds: 5),
      );
      if (_disposed) return;
      if (result.isOk) {
        _missedHeartbeats = 0;
      } else {
        _missedHeartbeats++;
        if (_missedHeartbeats >= kHeartbeatMissLimit) {
          _onProcessExit('心跳连续 $kHeartbeatMissLimit 次无响应');
        }
      }
    });
  }

  void _onProcessExit(String reason) {
    if (_disposed) return;
    // 同一个进程只处理一次退出。换新是「先主动关、后自然退出」两步，
    // 两次都会走到这里，第二次必须忽略，否则多起一个进程。
    if (_exitHandled) return;
    _exitHandled = true;
    _handshaken = false;
    final old = _channel;
    _channel = null;
    _heartbeatTimer?.cancel();
    // 进程没了，它托管的实例也就全没了。不清零的话 `_liveInstances` 会虚高，
    // 换新永远等不到「归零」那一刻。
    _liveInstances = 0;
    // 心跳触发的重启里子进程通常还活着，必须先杀掉，否则变成僵尸进程
    // 独占端口/资源；进程自然退出时这里只是无害的二次 kill。
    if (old != null) {
      unawaited(old.close());
    }
    _killProcess();
    _scheduleRestart(reason);
  }

  void _scheduleRestart(String reason) {
    if (_disposed || _tripped || _restartTimer != null) return;
    _restartAttempt++;
    if (_restartAttempt > maxRestartAttempts) {
      _tripped = true;
      // 熔断后不会再自动重启，等待者等不到了，立刻放它们走。
      _notifyReady(false);
      return;
    }
    final delay = _backoffFor(_restartAttempt - 1);
    _restartTimer = Timer(delay, () async {
      _restartTimer = null;
      await start();
    });
  }

  Future<void> _killProcess() async {
    await _channel?.close();
    _channel = null;
    _handshaken = false;
    if (_exitCode == null) return;
    final exitCode = _exitCode!;
    _exitCode = null;
    try {
      if (_kill(ProcessSignal.sigterm)) {
        await exitCode.timeout(
          kGracefulShutdownMs,
          onTimeout: () {
            _kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      }
    } on Object {
      // 进程可能已退出，忽略
    }
  }

  /// 复位熔断并尝试重启。
  Future<Result<HandshakeResult, AppError>> reset() async {
    _tripped = false;
    _restartAttempt = 0;
    return start();
  }

  /// 释放：优雅关闭进程与管道。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _heartbeatTimer?.cancel();
    _restartTimer?.cancel();
    _notifyReady(false);
    await _hostApiSub?.cancel();
    _hostApiSub = null;
    await _channel?.notify('runtime.shutdown', params: {'graceMs': 3000});
    await _killProcess();
    await _channel?.close();
    _channel = null;
    _handshaken = false;
  }
}
