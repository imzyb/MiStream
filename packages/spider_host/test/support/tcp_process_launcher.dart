// 用「inheritStdio 起真子进程 + 子进程回连回环 TCP」绕开 stdio 管道缺陷。
//
// 为什么需要它：在**被注入沙箱 DLL 的进程树**里（`tsbx.dll`，WorkBuddy 沙箱
// 注入，实测 `dangerouslyDisableSandbox` 也拦不住它），Dart VM 的
// `Process.start` 建 stdio 管道必报 `CreateFile failed 231`（ERROR_PIPE_BUSY），
// 连 `cmd /c echo` 都起不来，于是任何依赖真 stdio 管道的测试都跑不了。
//
// 根因（2026-10-04 用 ctypes 复刻 Dart 的 Win32 调用序列定位）：
//   - 服务端 `PIPE_ACCESS_OUTBOUND` + 客户端 `GENERIC_READ` → 231
//     ← 这正是 Dart 给子进程 stdin 用的组合
//   - 服务端 `PIPE_ACCESS_INBOUND` + 客户端 `GENERIC_WRITE` → 正常
//   - 服务端 `PIPE_ACCESS_DUPLEX` + 客户端 `GENERIC_READ|GENERIC_WRITE` → 正常
//     ← .NET 用的组合，所以 .NET / Python（匿名 CreatePipe）都不受影响
//   实例数、SECURITY_ATTRIBUTES、OVERLAPPED 均无关，方向组合才是触发条件。
// 也就是说：这不是这台机器的 Windows/Dart 坏了，而是**注入到本进程树里的
// 沙箱 DLL 钩坏了这一条 CreateFileW 组合**。用户从资源管理器直接启动的
// 应用不在这个进程树里，不受影响。
//
// 但两条路在沙箱里是可用的：
//   - `ProcessStartMode.inheritStdio`（不建管道）：能起真进程；
//   - 回环 TCP：实测能收发。
// 于是把传输层换成 TCP：宿主先起一个 ServerSocket，把端口作为参数传给子进程，
// 子进程主动回连，`SpiderHost` 的 RPC 就跑在 socket 上。
//
// 生产侧另有一条同源的回退：`resilientProcessLauncher`（管道优先，只在
// errorCode == 231 时切 TCP）。本文件是测试专用的记录版，会留下 LaunchedChild
// 供断言「起了几个真进程」。
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
