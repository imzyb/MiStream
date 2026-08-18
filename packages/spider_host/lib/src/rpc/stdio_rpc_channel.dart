/// 通过子进程 stdio 的 JSON-RPC 双向通信管道。
///
/// 职责：
/// - 从 stdin 读 → LspFrameParser 解析 → 匹配 pending 请求或派发通知
/// - 写 stdout → encodeFramed 发送，队列上限 64 条
/// - 请求超时、取消
///
/// docs/08-RPC协议.md §1-3。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

import 'package:spider_host/src/rpc/frame_parser.dart';
import 'package:spider_host/src/rpc/rpc_message.dart';

/// 写队列背压上限（docs/08 §1：Host 写队列上限 64 条）。
const int kWriteQueueMax = 64;

/// 请求默认超时（docs/08 §6：默认 15s）。
const Duration kDefaultRequestTimeout = Duration(seconds: 15);

int _nextRequestId = 0;

/// 通过 stdio 与子进程交互的 JSON-RPC 管道。
class StdioRpcChannel {
  /// 通过 [stdin] 流（子进程输出）与 [_stdout] sink（子进程输入）构造管道。
  StdioRpcChannel({
    required Stream<List<int>> stdin,
    required this._stdout,
  }) {
    _stdinSub = stdin.listen(
      _onData,
      onError: _onChannelError,
      onDone: _onDone,
    );
  }
  late final StreamSubscription<List<int>> _stdinSub;
  final IOSink _stdout;
  final LspFrameParser _parser = LspFrameParser();
  final StreamController<Map<String, Object?>> _notificationController =
      StreamController<Map<String, Object?>>.broadcast();
  final Map<int, Completer<Result<Object?, RemoteError>>> _pending = {};
  final StreamController<RpcRequest> _requestController =
      StreamController<RpcRequest>.broadcast();
  bool _closed = false;
  int _writeQueueLength = 0;

  void _onData(List<int> data) {
    if (_closed) return;
    _processChunk(data);
  }

  void _processChunk(List<int> data) {
    // 首轮把新到的字节喂给分帧器；此后分帧器已缓存剩余字节，
    // 再喂原始 data 会重复消费，所以后续轮次传空。
    var pending = data;
    for (;;) {
      final result = _parser.add(pending);
      switch (result) {
        case FrameComplete(:final body):
          _handleMessage(body);
          pending = const [];
        case FrameNeedMore():
          return;
        case FrameError(:final reason):
          _onChannelError(
            RemoteError(
              code: ErrorCode.parseError,
              message: '分帧错误: $reason',
            ),
          );
          return;
      }
    }
  }

  void _handleMessage(String jsonText) {
    Map<String, Object?> raw;
    try {
      raw = jsonDecode(jsonText) as Map<String, Object?>;
    } on Object {
      _reply(jsonRpcParseError());
      return;
    }

    final msg = RpcMessage.fromJson(raw);
    switch (msg) {
      case RpcResponse(:final id, :final result, :final error):
        final completer = _pending.remove(id);
        if (completer != null) {
          completer.complete(
            error != null
                ? Err<Object?, RemoteError>(error)
                : Ok<Object?, RemoteError>(result),
          );
        }
      case RpcNotification(:final method, :final params):
        _notificationController.add({'method': method, 'params': params});
      case RpcRequest():
        _requestController.add(msg);
    }
  }

  /// 发送一个请求，返回异步结果。
  ///
  /// [cancelOn] 完成时向对端发一条 `$/cancelRequest`（docs/08 §3.4），并让本
  /// 次调用立刻以 `REQUEST_CANCELLED` 返回，不再等对端。聚合搜索里用户改词就
  /// 靠它——不取消的话，几十个源的在途请求会一直占着连接与内存。
  Future<Result<Object?, RemoteError>> call(
    String method, {
    Map<String, Object?> params = const {},
    Duration? timeout,
    Future<void>? cancelOn,
  }) async {
    if (_writeQueueLength >= kWriteQueueMax) {
      return const Err(
        RemoteError(
          code: ErrorCode.runtimeBusy,
          message: '写队列已满 ($kWriteQueueMax条)',
        ),
      );
    }

    final id = _nextRequestId++;
    final completer = Completer<Result<Object?, RemoteError>>();
    _pending[id] = completer;
    _writeQueueLength++;

    // 只在请求还在途时才发取消：已经回来的请求再发一条，对端只能困惑。
    unawaited(
      cancelOn?.then((_) {
        if (!_pending.containsKey(id)) return;
        _pending.remove(id);
        unawaited(
          notify(r'$/cancelRequest', params: <String, Object?>{'id': id}),
        );
        if (!completer.isCompleted) {
          completer.complete(
            const Err(
              RemoteError(
                code: ErrorCode.requestCancelled,
                message: '请求已取消',
              ),
            ),
          );
        }
      }),
    );

    try {
      await _send(RpcRequest(id: id, method: method, params: params));
      final effectiveTimeout = timeout ?? kDefaultRequestTimeout;
      final result = await completer.future.timeout(
        effectiveTimeout,
        onTimeout: () {
          _pending.remove(id);
          _writeQueueLength--;
          return Err(
            RemoteError(
              code: ErrorCode.scriptTimeout,
              message: '请求超时 (${effectiveTimeout.inMilliseconds}ms)',
            ),
          );
        },
      );
      _writeQueueLength--;
      return result;
    } on Object catch (e) {
      _pending.remove(id);
      _writeQueueLength--;
      return Err(
        RemoteError(
          code: ErrorCode.internalError,
          message: '发送失败: $e',
          detail: {'cause': e.toString()},
        ),
      );
    }
  }

  /// 发送一个通知。
  Future<void> notify(String method, {Map<String, Object?> params = const {}}) {
    return _send(RpcNotification(method: method, params: params));
  }

  Future<void> _send(RpcMessage msg) async {
    if (_closed) return;
    _stdout.add(encodeFramed(msg));
    await _stdout.flush();
  }

  void _reply(RpcResponse resp) {
    // 回复失败无处上报（管道已坏时 _send 自身会短路），刻意不阻塞调用方。
    unawaited(_send(resp));
  }

  void _onDone() {
    _onChannelError('stdin 已关闭');
  }

  void _onChannelError(Object error) {
    if (_closed) return;
    for (final entry in _pending.entries) {
      entry.value.complete(
        Err(
          RemoteError(
            code: ErrorCode.runtimeCrashed,
            message: '管道错误: $error',
          ),
        ),
      );
    }
    _pending.clear();
    _writeQueueLength = 0;
  }

  /// 订阅通知流。
  Stream<Map<String, Object?>> get notifications =>
      _notificationController.stream;

  /// 订阅来自对端的请求流（Runtime → Host 调用）。
  Stream<RpcRequest> get incomingRequests => _requestController.stream;

  /// 回应一条来自对端的请求。
  ///
  /// [incomingRequests] 只把请求送出来，不替调用方决定怎么答；宿主 API 的分发
  /// 是异步的（`host.fetch` 要真发网络），所以应答必须是独立的一步。
  void respond(RpcResponse response) => _reply(response);

  /// 关闭管道。
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _stdinSub.cancel();
    await _notificationController.close();
    await _requestController.close();
    for (final entry in _pending.entries) {
      entry.value.complete(
        const Err(
          RemoteError(
            code: ErrorCode.requestCancelled,
            message: '管道已关闭',
          ),
        ),
      );
    }
    _pending.clear();
    _writeQueueLength = 0;
    await _stdout.flush();
    await _stdout.close();
  }
}
