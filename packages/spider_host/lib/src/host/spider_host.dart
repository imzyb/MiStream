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
  SpiderHost({
    required this.executable,
    required this.arguments,
    this.localProtocolVersion = 1,
    this.appVersion = 'dev',
    this.maxRestartAttempts = kMaxRestartAttempts,
    this.handshakeTimeout = kHandshakeTimeout,
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

  final ProcessLauncher _launcher;
  final Duration Function(int attempt) _backoffFor;

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

  /// 熔断状态：连续失败达到上限后置 true。
  bool _tripped = false;

  /// 是否已握手成功。
  bool get isReady => _handshaken && !_disposed;

  /// 是否已熔断（不再自动重启）。
  bool get isTripped => _tripped;

  /// 当前能力位。
  List<String> get features => List.unmodifiable(_features);

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

      final channel = StdioRpcChannel(
        stdin: proc.stdout,
        stdout: proc.stdin,
      );
      _channel = channel;
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
      _startHeartbeat();
      return Ok(result);
    } on Object catch (e, st) {
      return Err(AppError.from(e, st));
    }
  }

  /// 分发一个 RPC 请求。
  Future<Result<Object?, AppError>> call(
    String method, {
    Map<String, Object?> params = const {},
    Duration? timeout,
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
    );
    return result.mapErr((e) => e);
  }

  /// 发送通知。
  Future<void> notify(String method, {Map<String, Object?> params = const {}}) {
    return _channel?.notify(method, params: params) ?? Future.value();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(kHeartbeatInterval, (_) async {
      final channel = _channel;
      if (channel == null || !_handshaken) return;
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
    _handshaken = false;
    _channel = null;
    _heartbeatTimer?.cancel();
    _scheduleRestart(reason);
  }

  void _scheduleRestart(String reason) {
    if (_disposed || _tripped || _restartTimer != null) return;
    _restartAttempt++;
    if (_restartAttempt > maxRestartAttempts) {
      _tripped = true;
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
    await _channel?.notify('runtime.shutdown', params: {'graceMs': 3000});
    await _killProcess();
    await _channel?.close();
    _channel = null;
    _handshaken = false;
  }
}
