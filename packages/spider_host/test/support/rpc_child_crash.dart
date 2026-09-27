// 「连上就崩」的子进程桩：驱动宿主的退避重启与熔断。
//
// 为什么必须是「连上再崩」而不是「起不来」：`SpiderHost.start()` 的 catch
// 分支（launcher 抛异常时）**不挂重启定时器**——源码注释里写明「不会自愈」。
// 要让 `_onProcessExit` → `_scheduleRestart` 这条链真正跑起来，子进程必须
// 先完成 TCP 回连，再退出。这与「源初始化就崩」的真实故障形态一致。
//
// 刻意只用 dart:io：不依赖被测包，避免循环依赖，也让 `dart run` 起它时
// 不触发任何 native 钩子。
//
// 用法：`dart run test/support/rpc_child_crash.dart --port=<宿主端口>`
import 'dart:io';

Future<void> main(List<String> args) async {
  final portArg = args.firstWhere(
    (a) => a.startsWith('--port='),
    orElse: () => '',
  );
  if (portArg.isEmpty) {
    stderr.writeln('用法: rpc_child_crash.dart --port=<port>');
    exit(2);
  }
  final port = int.parse(portArg.substring('--port='.length));

  // 回连成功即退出：不握手、不应答，模拟「源初始化就崩」。
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    port,
    timeout: const Duration(seconds: 10),
  );
  socket.destroy();
  exit(1);
}
