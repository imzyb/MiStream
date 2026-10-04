// 用「inheritStdio 起真子进程 + 子进程回连回环 TCP」绕开本机 stdio 管道缺陷。
//
// 为什么需要它：本机 Dart VM 的 `Process.start` 一律报
// `CreateFile failed 231`（ERROR_PIPE_BUSY），连 `cmd /c echo` 都起不来，
// 于是任何依赖真 stdio 管道的测试都跑不了。但两条路是可用的：
//   - `ProcessStartMode.inheritStdio`（不建管道）：能起真进程；
//   - 回环 TCP：实测能收发。
// 于是把传输层换成 TCP：宿主先起一个 ServerSocket，把端口作为参数传给子进程，
// 子进程主动回连，`SpiderHost` 的 RPC 就跑在 socket 上。
//
// 生产环境不需要它——`SpiderHost.launcher` 默认仍走 `Process.start`。
// 这个 launcher 只是让「真子进程 + 真进程生命周期」在本机可测。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:spider_host/src/host/spider_host.dart';

/// 把 socket 包装成 [IOSink]，供 [StdioRpcChannel] 写入。
class _SocketSink implements IOSink {
  _SocketSink(this._socket);

  final Socket _socket;

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      stream.forEach(_socket.add);

  @override
  Future<void> flush() => _socket.flush();

  @override
  Future<void> close() => _socket.close();

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  void write(Object? object) => _socket.write(object);

  @override
  void writeAll(Iterable<Object?> iterable, [String separator = '']) =>
      _socket.writeAll(iterable, separator);

  @override
  void writeCharCode(int charCode) => _socket.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _socket.writeln(object);

  @override
  Future<void> get done => _socket.done;
}

/// 记录一次启动的上下文，便于测试断言「起了几个真进程」。
class LaunchedChild {
  LaunchedChild({
    required this.process,
    required this.socket,
    required this.port,
  });

  /// 真子进程。
  final Process process;

  /// 与该子进程通信的 socket。
  final Socket socket;

  final int port;
}

/// 起真子进程的 launcher：在 [Process.start] 之外额外挂一条 TCP 传输。
///
/// [appendPort] 控制是否把 `--port=<n>` 追加到参数末尾（默认追加）。
/// 返回的函数签名为 [ProcessLauncher]，可直接赋给 `SpiderHost.launcher`。
ProcessLauncher tcpProcessLauncher({
  required List<LaunchedChild> children,
  bool appendPort = true,
  Duration connectTimeout = const Duration(seconds: 15),
}) {
  return (String executable, List<String> arguments) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    final args = appendPort ? [...arguments, '--port=$port'] : arguments;
    final process = await Process.start(
      executable,
      args,
      // 关键：不建 stdio 管道，否则撞本机的 ERROR_PIPE_BUSY。
      mode: ProcessStartMode.inheritStdio,
    );

    final socket = await server.first.timeout(
      connectTimeout,
      onTimeout: () {
        process.kill();
        throw TimeoutException('子进程未在 $connectTimeout 内回连 $port');
      },
    );
    await server.close();

    final child = LaunchedChild(process: process, socket: socket, port: port);
    children.add(child);

    return (
      stdin: _SocketSink(socket),
      stdout: socket.cast<Uint8List>(),
      exitCode: process.exitCode,
      kill: process.kill,
    );
  };
}
