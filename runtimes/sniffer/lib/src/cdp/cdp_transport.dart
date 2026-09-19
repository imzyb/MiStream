/// CDP 传输抽象。
///
/// 把「怎么把一帧文本送出去、怎么收回来」与「CDP 说什么」分开，是为了让
/// 协议层能脱离真实网络测试。这在当前工程里不是洁癖——嗅探的完整链路
/// 需要真实浏览器 + 回环连接，两者都有环境依赖（CI 里未必有浏览器，
/// 受限环境里未必放行回环），把协议逻辑绑死在 WebSocket 上等于让这部分
/// 代码永远无法被测试覆盖。
///
/// 生产实现是 [WebSocketCdpTransport]；测试用内存实现。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一帧 CDP 消息。
///
/// CDP 的线上格式就是 JSON 对象，所以传输层直接透传 `Map`，不做二次编码。
/// 在传输层再包一层自定义结构只会增加一层无意义的映射。
typedef CdpFrame = Map<String, Object?>;

/// CDP 传输通道。
abstract class CdpTransport {
  /// 建立连接。已连接时重复调用应当是幂等的。
  Future<void> connect();

  /// 发送一帧。
  Future<void> send(CdpFrame frame);

  /// 收到的帧流。
  ///
  /// 广播流：CDP 客户端与测试观察者会同时订阅。
  Stream<CdpFrame> get incoming;

  /// 关闭连接。
  Future<void> close();

  /// 连接是否仍然可用。
  bool get isOpen;
}

/// 基于 WebSocket 的 CDP 传输。
///
/// CDP 的浏览器级端点是 `ws://127.0.0.1:<port>/devtools/browser/<id>`，
/// 页面级端点是 `.../devtools/page/<id>`。两者协议一致，只是能发的命令不同，
/// 所以这里不区分。
class WebSocketCdpTransport implements CdpTransport {
  /// 用 [endpoint] 构造。
  WebSocketCdpTransport(
    this.endpoint, {
    this.connectTimeout = const Duration(seconds: 10),
    this.maxPayloadBytes = 8 * 1024 * 1024,
  });

  /// WebSocket 地址。
  final String endpoint;

  /// 建连超时。
  ///
  /// 单列一个超时而不是复用嗅探总超时，是因为「连不上」和「页面没命中」
  /// 是两种完全不同的失败，需要给用户不同的提示。
  final Duration connectTimeout;

  /// 单帧大小上限。
  ///
  /// CDP 的 `Network.getResponseBody` 之类的响应可能很大，但页面主动推送的
  /// 事件不该无上限增长。超过上限直接断开，避免被一个畸形页面拖垮。
  final int maxPayloadBytes;

  final _incoming = StreamController<CdpFrame>.broadcast();
  WebSocket? _socket;
  StreamSubscription<Object?>? _sub;

  @override
  bool get isOpen => _socket != null;

  @override
  Future<void> connect() async {
    if (_socket != null) return;

    final socket = await WebSocket.connect(endpoint).timeout(
      connectTimeout,
      onTimeout: () => throw CdpTransportException(
        '连接 CDP 端点超时: $endpoint',
      ),
    );

    _socket = socket;
    _sub = socket.listen(
      _onData,
      onError: (Object e) => _incoming.addError(
        CdpTransportException('CDP 连接错误: $e'),
      ),
      onDone: () {
        _socket = null;
        if (!_incoming.isClosed) _incoming.close();
      },
      cancelOnError: false,
    );
  }

  void _onData(Object? data) {
    if (data is! String) return;
    if (data.length > maxPayloadBytes) {
      // 宁可直接断开也不要让一个畸形帧占满内存。
      unawaited(close());
      _incoming.addError(
        CdpTransportException('CDP 帧超过上限 ${maxPayloadBytes}B'),
      );
      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException catch (e) {
      // 单帧损坏不该终止整条链路——CDP 偶发会在关闭前吐半截。
      _incoming.addError(CdpTransportException('CDP 帧不是合法 JSON: $e'));
      return;
    }
    if (decoded is Map<String, Object?>) {
      _incoming.add(decoded);
    }
  }

  @override
  Future<void> send(CdpFrame frame) async {
    final socket = _socket;
    if (socket == null) {
      throw CdpTransportException('CDP 连接已关闭，无法发送');
    }
    socket.add(jsonEncode(frame));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close(WebSocketStatus.normalClosure);
    }
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  Stream<CdpFrame> get incoming => _incoming.stream;
}

/// CDP 传输层错误。
class CdpTransportException implements Exception {
  /// 构造错误。
  const CdpTransportException(this.message);

  /// 人类可读的原因。
  final String message;

  @override
  String toString() => 'CdpTransportException: $message';
}
