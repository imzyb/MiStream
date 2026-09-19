/// CDP 协议客户端。
///
/// 职责边界：**只做协议**。id 分配、命令/响应配对、事件分发、超时、错误
/// 规范化都在这里；「怎么启动浏览器」「嗅什么」不在这里。
///
/// 这条边界是从 `CdpSniffer` 的教训来的——那一版把所有东西（进程管理、
/// 协议、嗅探策略、WebSocket）混在一个类里，结果每个方法都停在注释上，
/// 一个能跑的方法都没有。分开之后，协议层可以脱离浏览器与网络测试。
library;

import 'dart:async';

import 'package:sniffer/src/cdp/cdp_transport.dart';

/// CDP 命令执行失败（浏览器明确回了 `error`）。
class CdpCommandException implements Exception {
  /// 构造错误。
  const CdpCommandException({
    required this.method,
    required this.code,
    required this.message,
    this.data,
  });

  /// 出错的方法名。
  final String method;

  /// CDP 错误码。
  final int code;

  /// 错误描述。
  final String message;

  /// 附加数据。
  final Object? data;

  @override
  String toString() => 'CdpCommandException($method: $code $message)';
}

/// CDP 命令超时。
class CdpTimeoutException implements Exception {
  /// 构造错误。
  const CdpTimeoutException({required this.method, required this.timeout});

  /// 超时的方法名。
  final String method;

  /// 超时时长。
  final Duration timeout;

  @override
  String toString() =>
      'CdpTimeoutException($method 超过 ${timeout.inMilliseconds}ms)';
}

/// 一条 CDP 事件。
class CdpEvent {
  /// 构造事件。
  const CdpEvent({
    required this.method,
    required this.params,
    this.sessionId,
  });

  /// 事件方法名，如 `Network.responseReceived`。
  final String method;

  /// 事件参数。
  final Map<String, Object?> params;

  /// 来源会话（用 flat session 模式时才有）。
  final String? sessionId;

  @override
  String toString() => 'CdpEvent($method)';
}

/// CDP 客户端。
///
/// 用法：
/// ```dart
/// final client = CdpClient(WebSocketCdpTransport(wsUrl));
/// await client.connect();
/// await client.send('Network.enable');
/// client.events.listen((e) => ...);
/// ```
class CdpClient {
  /// 用 [transport] 构造。
  CdpClient(
    this.transport, {
    this.commandTimeout = const Duration(seconds: 15),
  });

  /// 底层传输。
  final CdpTransport transport;

  /// 单条命令的默认超时。
  final Duration commandTimeout;

  final _events = StreamController<CdpEvent>.broadcast();
  final _pending = <int, Completer<Map<String, Object?>>>{};
  StreamSubscription<CdpFrame>? _sub;
  var _nextId = 1;
  var _closed = false;

  /// 事件流。
  Stream<CdpEvent> get events => _events.stream;

  /// 已发出的命令序号，供诊断使用。
  int get lastIssuedId => _nextId - 1;

  /// 建立连接并开始收帧。
  Future<void> connect() async {
    await transport.connect();
    _sub = transport.incoming.listen(
      _onFrame,
      onError: _failAll,
      onDone: () {
        _closed = true;
        _failAll(const CdpTransportException('CDP 连接已关闭'));
      },
    );
  }

  void _onFrame(CdpFrame frame) {
    final id = frame['id'];
    if (id is int) {
      final completer = _pending.remove(id);
      if (completer == null) return; // 已被超时或取消，丢弃。
      final error = frame['error'];
      if (error is Map) {
        completer.completeError(
          CdpCommandException(
            method: _methodOf(id),
            code: _asInt(error['code']) ?? -1,
            message: error['message']?.toString() ?? '未知错误',
            data: error['data'],
          ),
        );
      } else {
        final result = frame['result'];
        completer.complete(
          result is Map<String, Object?> ? result : const <String, Object?>{},
        );
      }
      return;
    }

    // 没有 id 就是事件。
    final method = frame['method'];
    if (method is! String) return;
    final params = frame['params'];
    _events.add(
      CdpEvent(
        method: method,
        params: params is Map<String, Object?>
            ? params
            : const <String, Object?>{},
        sessionId: frame['sessionId'] as String?,
      ),
    );
  }

  final _issuedMethods = <int, String>{};

  String _methodOf(int id) => _issuedMethods[id] ?? '未知';

  /// 发送命令并等结果。
  ///
  /// [timeout] 缺省用 [commandTimeout]。
  Future<Map<String, Object?>> send(
    String method, {
    Map<String, Object?>? params,
    String? sessionId,
    Duration? timeout,
  }) {
    if (_closed) {
      return Future.error(const CdpTransportException('CDP 连接已关闭'));
    }

    final id = _nextId++;
    _issuedMethods[id] = method;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;

    final frame = <String, Object?>{
      'id': id,
      'method': method,
      // params / sessionId 缺省时**不写这个键**，而不是写 null：
      // CDP 对显式 null 的处理在不同域上不一致，省略最安全。
      'params': ?params,
      'sessionId': ?sessionId,
    };

    transport.send(frame).catchError((Object e) {
      _pending.remove(id);
      if (!completer.isCompleted) completer.completeError(e);
    });

    return completer.future.timeout(
      timeout ?? commandTimeout,
      onTimeout: () {
        _pending.remove(id);
        throw CdpTimeoutException(
          method: method,
          timeout: timeout ?? commandTimeout,
        );
      },
    );
  }

  /// 等一个满足 [predicate] 的事件。
  ///
  /// 先挂监听再返回 future，所以调用方**必须先起等待再触发动作**，否则会漏
  /// 掉早于订阅发生的事件。这是 CDP 的固有性质（事件只推一次），不是实现
  /// 缺陷；[waitForEvent] 用广播流就是为了让多个等待者并存。
  Future<CdpEvent> waitForEvent(
    bool Function(CdpEvent) predicate, {
    Duration? timeout,
  }) {
    final completer = Completer<CdpEvent>();
    late StreamSubscription<CdpEvent> sub;
    sub = _events.stream.listen((e) {
      if (!completer.isCompleted && predicate(e)) {
        completer.complete(e);
        unawaited(sub.cancel());
      }
    });

    return completer.future
        .timeout(
          timeout ?? commandTimeout,
          onTimeout: () {
            unawaited(sub.cancel());
            throw CdpTimeoutException(
              method: 'waitForEvent',
              timeout: timeout ?? commandTimeout,
            );
          },
        )
        .whenComplete(() => unawaited(sub.cancel()));
  }

  void _failAll(Object error) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }

  /// 关闭客户端与传输。
  Future<void> close() async {
    _closed = true;
    await _sub?.cancel();
    _sub = null;
    _failAll(const CdpTransportException('CDP 客户端已关闭'));
    await transport.close();
    if (!_events.isClosed) await _events.close();
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
