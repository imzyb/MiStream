/// 测试用的内存 CDP 传输。
///
/// 它让协议层与嗅探策略可以脱离浏览器与网络完整测试——真实链路需要
/// 一个跑着的浏览器 + 回环连接，两者在 CI 与受限环境里都不可靠。
///
/// [send] 的实现是「按脚本应答」而不是「什么都不做」：不回的传输会让
/// 每个命令都等到超时，测试会慢且掩盖真实行为；只回答不触发事件的
/// 传输又测不到嗅探策略。所以这里让测试显式给出「收到什么命令就回什么、
/// 顺带推什么事件」。
library;

import 'dart:async';

import 'package:sniffer/sniffer.dart';

/// 一条预设应答。
class CdpScriptedReply {
  /// 构造应答。
  const CdpScriptedReply({
    this.result = const <String, Object?>{},
    this.error,
    this.events = const <CdpFrame>[],
    this.delay = Duration.zero,
  });

  /// 命令的 result 内容。
  final Map<String, Object?> result;

  /// 若给出，则回一个 error 帧而不是 result。
  final Map<String, Object?>? error;

  /// 回完应答后顺带推的事件。
  final List<CdpFrame> events;

  /// 回复延迟，用于测超时。
  final Duration delay;
}

/// 内存传输。
class FakeCdpTransport implements CdpTransport {
  /// 构造。
  ///
  /// [replies] 的键是命令方法名，值是按调用次序消费的应答队列；
  /// 队列用尽后回空 result（模拟「命令成功但无返回内容」）。
  /// [onSend] 拿到每个发出的帧，供断言参数。
  FakeCdpTransport({
    Map<String, List<CdpScriptedReply>>? replies,
    this.onSend,
    this.autoEvents = const <CdpFrame>[],
    this.autoEventDelay = Duration.zero,
  }) : _replies = replies ?? {};

  final Map<String, List<CdpScriptedReply>> _replies;

  /// 每个发出帧的回调。
  final void Function(CdpFrame frame)? onSend;

  /// 连接后自动推的事件（用于测「连接即有待处理事件」）。
  final List<CdpFrame> autoEvents;

  /// 自动事件的延迟。
  final Duration autoEventDelay;

  final _incoming = StreamController<CdpFrame>.broadcast();
  final _sent = <CdpFrame>[];
  var _open = false;

  /// 所有发出的帧（按次序）。
  List<CdpFrame> get sent => List.unmodifiable(_sent);

  /// 取某方法的全部调用参数。
  List<Map<String, Object?>> paramsOf(String method) => _sent
      .where((f) => f['method'] == method)
      .map((f) => (f['params'] as Map<String, Object?>?) ?? const {})
      .toList();

  @override
  bool get isOpen => _open;

  @override
  Future<void> connect() async {
    _open = true;
    if (autoEvents.isNotEmpty) {
      unawaited(
        Future<void>.delayed(autoEventDelay).then((_) {
          for (final e in autoEvents) {
            if (!_incoming.isClosed) _incoming.add(e);
          }
        }),
      );
    }
  }

  @override
  Future<void> send(CdpFrame frame) async {
    if (!_open) {
      throw const CdpTransportException('内存传输未连接');
    }
    _sent.add(frame);
    onSend?.call(frame);

    final id = frame['id'];
    final method = frame['method']?.toString();
    if (id is! int || method == null) return;

    final queue = _replies[method];
    final scripted = (queue != null && queue.isNotEmpty)
        ? queue.removeAt(0)
        : const CdpScriptedReply();

    if (scripted.delay > Duration.zero) {
      await Future<void>.delayed(scripted.delay);
    }
    if (_incoming.isClosed) return;

    if (scripted.error != null) {
      _incoming.add({'id': id, 'error': scripted.error});
    } else {
      _incoming.add({'id': id, 'result': scripted.result});
    }

    for (final event in scripted.events) {
      if (!_incoming.isClosed) _incoming.add(event);
    }
  }

  /// 手动推一个事件。
  void emit(CdpFrame event) {
    if (!_incoming.isClosed) _incoming.add(event);
  }

  /// 手动推一个事件（异步版本，等微任务队列清空）。
  Future<void> emitLater(CdpFrame event) async {
    await Future<void>.delayed(Duration.zero);
    emit(event);
  }

  @override
  Future<void> close() async {
    _open = false;
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  Stream<CdpFrame> get incoming => _incoming.stream;
}

/// 构造一个 `Network.responseReceived` 事件。
CdpFrame responseReceivedEvent({
  required String url,
  String mimeType = 'application/vnd.apple.mpegurl',
  Map<String, String> headers = const {},
  String? requestId,
}) => <String, Object?>{
  'method': 'Network.responseReceived',
  'params': <String, Object?>{
    'requestId': requestId ?? 'r-${url.hashCode}',
    'response': <String, Object?>{
      'url': url,
      'mimeType': mimeType,
      'headers': headers,
    },
  },
};

/// 构造一个 `Network.requestWillBeSent` 事件。
CdpFrame requestWillBeSentEvent({
  required String url,
  Map<String, String> headers = const {},
  String? requestId,
}) => <String, Object?>{
  'method': 'Network.requestWillBeSent',
  'params': <String, Object?>{
    'requestId': requestId ?? 'q-${url.hashCode}',
    'request': <String, Object?>{'url': url, 'headers': headers},
  },
};

/// 构造一个 `Page.loadEventFired` 事件。
CdpFrame loadEventFired() => <String, Object?>{
  'method': 'Page.loadEventFired',
  'params': <String, Object?>{},
};
