// 真子进程侧的 RPC 桩：回连宿主的回环 TCP，说 LSP 分帧 JSON-RPC。
//
// 存在的意义：本机 Dart VM 的 `Process.start` 建不了 stdio 管道
// （`CreateFile failed 231`），所以真子进程的端到端测试只能换传输层——
// 用 `inheritStdio` 起进程（这条可行），子进程再回连宿主的 TCP。
//
// 刻意只用 dart:io / dart:convert：不依赖被测包，避免循环依赖，也让
// `dart run` 起它时不触发任何 native 钩子。
//
// 用法：`dart run test/support/rpc_child.dart --port=<宿主端口>`
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 累积字节并按 `Content-Length` 切帧，吐出完整的 JSON 文本。
class _FrameReader {
  final List<int> _buffer = [];

  /// 喂入一段字节，返回本次能凑出的所有完整帧（body 文本）。
  List<String> feed(List<int> data) {
    _buffer.addAll(data);
    final frames = <String>[];
    while (true) {
      final state = _takeOne();
      if (state == null) break;
      frames.add(state);
    }
    return frames;
  }

  String? _takeOne() {
    final headEnd = _indexOfHeaderEnd();
    if (headEnd < 0) return null;
    final header = utf8.decode(
      _buffer.sublist(0, headEnd),
      allowMalformed: true,
    );
    final match = RegExp(r'Content-Length:\s*(\d+)').firstMatch(header);
    if (match == null) {
      // 畸形头：丢掉这一截，避免死循环。
      _buffer.removeRange(0, headEnd + 4);
      return null;
    }
    final length = int.parse(match.group(1)!);
    final bodyStart = headEnd + 4;
    if (_buffer.length < bodyStart + length) return null;
    final body = utf8.decode(
      _buffer.sublist(bodyStart, bodyStart + length),
      allowMalformed: true,
    );
    _buffer.removeRange(0, bodyStart + length);
    return body;
  }

  int _indexOfHeaderEnd() {
    for (var i = 0; i + 3 < _buffer.length; i++) {
      if (_buffer[i] == 13 &&
          _buffer[i + 1] == 10 &&
          _buffer[i + 2] == 13 &&
          _buffer[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }
}

/// 把一条 JSON 消息编码成 LSP 风格分帧字节。
List<int> _encode(Object? message) {
  final body = utf8.encode(jsonEncode(message));
  final header = utf8.encode('Content-Length: ${body.length}\r\n\r\n');
  return [...header, ...body];
}

Future<void> main(List<String> args) async {
  final portArg = args.firstWhere(
    (a) => a.startsWith('--port='),
    orElse: () => '',
  );
  if (portArg.isEmpty) {
    stderr.writeln('用法: rpc_child.dart --port=<port>');
    exit(2);
  }
  final port = int.parse(portArg.substring('--port='.length));

  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    port,
    timeout: const Duration(seconds: 10),
  );

  final reader = _FrameReader();
  final pendingExit = Completer<void>();

  socket.listen(
    (data) {
      for (final frame in reader.feed(data)) {
        final Object? decoded;
        try {
          decoded = jsonDecode(frame);
        } on Object {
          continue;
        }
        if (decoded is! Map<String, Object?>) continue;
        final id = decoded['id'];
        final method = decoded['method'] as String?;
        if (method == null) continue;

        // 通知（无 id）：只在 shutdown 时退出。
        if (id == null) {
          if (method == 'runtime.shutdown') {
            final params = decoded['params'];
            final grace = (params is Map ? params['graceMs'] : null) as int?;
            Future<void>.delayed(
              Duration(milliseconds: grace ?? 0),
              () => exit(0),
            );
          }
          continue;
        }

        socket.add(_encode(_respond(method, id)));
      }
    },
    onDone: () {
      if (!pendingExit.isCompleted) pendingExit.complete();
    },
    onError: (Object e) {
      if (!pendingExit.isCompleted) pendingExit.complete();
    },
    cancelOnError: true,
  );

  await pendingExit.future.timeout(
    const Duration(seconds: 60),
    onTimeout: () => exit(0),
  );
  exit(0);
}

/// 按 method 返回应答的 result 部分；未知方法回错误。
Map<String, Object?> _respond(String method, Object? id) {
  Object? result;
  Map<String, Object?>? error;

  switch (method) {
    case 'runtime.handshake':
      result = {
        'protocolVersion': 1,
        'runtimeVersion': 'child-stub-1.0.0',
        'features': ['cancel', 'storage'],
      };
    case 'runtime.ping':
      result = {'ts': DateTime.now().millisecondsSinceEpoch};
    case 'spider.create':
      result = {
        'capabilities': ['home', 'category', 'detail', 'search', 'play'],
      };
    case 'spider.destroy':
      result = <String, Object?>{};
    default:
      error = {'code': -32601, 'message': '未知方法: $method'};
  }

  return {
    'jsonrpc': '2.0',
    'id': id,
    if (error != null) 'error': error else 'result': result,
  };
}
