import 'dart:io';

import 'package:spider_host/src/host/host_api.dart';
import 'package:spider_host/src/host/spider_host.dart';
import 'package:test/test.dart';

import 'support/child_staging.dart';

/// [resilientProcessLauncher] 的回退行为。
///
/// 本机 Dart VM 的 `Process.start` 建 stdio 管道必报
/// `ProcessException(errorCode: 231)`（ERROR_PIPE_BUSY），所以生产启动器改成
/// 「管道优先、回环 TCP 兜底」。这里用**真子进程**（`support/rpc_child.dart`，
/// 认 `--port=<n>`）验证回退通道真能跑通 RPC，而不只是「没抛异常」。
void main() {
  late String childScript;

  setUp(() {
    childScript = resolveTestSupportFile('rpc_child.dart');
  });

  /// 造一个与真实缺陷同形的异常。
  ///
  /// `ProcessException` 的位置参数顺序是 `(executable, arguments, [message,
  /// errorCode])`。
  ProcessException pipeBusy(String executable, List<String> arguments) =>
      ProcessException(
        executable,
        arguments,
        'CreateFile failed 231 (所有的管道范例都在使用中。)',
        kPipeBusyErrorCode,
      );

  test('管道报 ERROR_PIPE_BUSY 时回退回环 TCP，并能在新通道上跑 RPC', () async {
    var primaryCalls = 0;
    final launcher = resilientProcessLauncher(
      primary: (executable, arguments) async {
        primaryCalls++;
        throw pipeBusy(executable, arguments);
      },
      // 子进程是 dart.exe 不是 java.exe，不做无控制台替换
      useConsolelessSibling: false,
    );

    final host = SpiderHost(
      executable: Platform.resolvedExecutable,
      arguments: ['run', childScript],
      launcher: launcher,
      hostApi: HostApi(),
      handshakeTimeout: const Duration(seconds: 30),
      backoffFor: (_) => Duration.zero,
    );
    addTearDown(host.dispose);

    final result = await host.start().timeout(const Duration(seconds: 60));
    expect(primaryCalls, 1, reason: '应当先试管道，失败后才回退');
    expect(result.isOk, isTrue, reason: result.errorOrNull?.message);
    expect(host.isReady, isTrue);

    // 回退通道上真能跑业务调用（证明分帧/RPC 在 socket 上等价）。
    final create = await host.call('spider.create');
    expect(create.isOk, isTrue);
    expect(host.liveInstanceCount, 1);
  });

  test('非 ERROR_PIPE_BUSY 的启动失败原样抛出，不回退', () async {
    var primaryCalls = 0;
    final launcher = resilientProcessLauncher(
      primary: (executable, arguments) async {
        primaryCalls++;
        throw ProcessException(executable, arguments, '系统找不到指定的文件。', 2);
      },
    );

    // exe 不存在属于「配置错」，伪装成子进程起不来会把排查带偏，必须原样抛。
    await expectLater(
      launcher(r'C:\nonexistent\mistream-probe.exe', const <String>[]),
      throwsA(
        isA<ProcessException>().having((e) => e.errorCode, 'errorCode', 2),
      ),
    );
    expect(primaryCalls, 1);
  });

  test('管道可用时不追加 --port，直接返回 primary 的结果', () async {
    final sinkFile = File(
      <String>[
        Directory.systemTemp.path,
        'mistream_launcher_test_$pid.sink',
      ].join(Platform.pathSeparator),
    );
    final sink = sinkFile.openWrite();
    addTearDown(() async {
      await sink.close();
      if (sinkFile.existsSync()) await sinkFile.delete();
    });

    late List<String> seenArguments;
    final launcher = resilientProcessLauncher(
      primary: (executable, arguments) async {
        seenArguments = arguments;
        return (
          stdin: sink,
          stdout: const Stream<List<int>>.empty(),
          exitCode: Future<int>.value(0),
          kill: _fakeKill,
        );
      },
    );

    final launched = await launcher('whatever.exe', ['-cp', 'x']);
    expect(
      seenArguments,
      ['-cp', 'x'],
      reason: '没触发回退，参数不该被追加 --port',
    );
    expect(await launched.exitCode, 0);
  });
}

bool _fakeKill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
