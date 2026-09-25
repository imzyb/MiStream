import 'dart:async';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/src/host/host_api.dart';
import 'package:spider_host/src/host/spider_host.dart';
import 'package:test/test.dart';

import 'support/tcp_process_launcher.dart';

/// 真子进程的端到端：验证 `SpiderHost` 在**真进程 + 真进程生命周期**下
/// 的握手、调用、换新与「换新窗口内不重复建宿主」。
///
/// 为什么走 TCP 而不是 stdio：本机 Dart VM 的 `Process.start` 建不了 stdio
/// 管道（`CreateFile failed 231`），但 `inheritStdio`（不建管道）与回环 TCP
/// 都可用，于是 `support/tcp_process_launcher.dart` 把传输层换成了 TCP。
void main() {
  group('SpiderHost 真子进程（TCP 回连）', () {
    late List<LaunchedChild> children;
    late String childScript;

    setUp(() {
      children = [];
      childScript = Platform.script
          .resolve('support/rpc_child.dart')
          .toFilePath();
    });

    tearDown(() async {
      // 收尾：把还活着的子进程都杀掉，别留下孤儿。
      for (final child in children) {
        child.process.kill();
      }
    });

    SpiderHost newHost({int threshold = 1}) => SpiderHost(
      executable: Platform.resolvedExecutable,
      arguments: ['run', childScript],
      // 阈值压到 1：一次销毁周期就触发换新。
      sourceTearDownsPerProcess: threshold,
      backoffFor: (_) => Duration.zero,
      launcher: tcpProcessLauncher(children: children),
      hostApi: HostApi(),
    );

    /// 等条件成立，最多 3 秒（真进程启动没有假进程那么快）。
    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 600 && !condition(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('真子进程握手成功（真 TCP 传输）', () async {
      final host = newHost();
      addTearDown(host.dispose);

      final result = await host.start().timeout(const Duration(seconds: 30));
      expect(result.isOk, isTrue);
      expect(host.isReady, isTrue);
      expect(host.features, contains('cancel'));
      expect(children, hasLength(1), reason: '应当起了 1 个真子进程');
    });

    test('真子进程上的 spider.create / destroy 调用', () async {
      final host = newHost(threshold: 99);
      addTearDown(host.dispose);

      await host.start().timeout(const Duration(seconds: 30));
      final create = await host.call('spider.create');
      expect(create.isOk, isTrue);
      expect(host.liveInstanceCount, 1);

      final destroy = await host.call('spider.destroy');
      expect(destroy.isOk, isTrue);
      expect(host.liveInstanceCount, 0);
      // 阈值 99，不该触发换新。
      expect(children, hasLength(1));
    });

    test('换新：真子进程被关停并重新拉起', () async {
      final host = newHost(threshold: 1);
      addTearDown(host.dispose);

      await host.start().timeout(const Duration(seconds: 30));
      await host.call('spider.create');
      await host.call('spider.destroy');

      // 换新会重新启动一个真子进程。
      await waitFor(() => children.length >= 2);
      expect(children, hasLength(greaterThanOrEqualTo(2)));
      // 等新进程握手完成。
      await waitFor(() => host.isReady);
      expect(host.isReady, isTrue);
    });

    test('换新窗口内再调用：等同一个宿主，不起第二个进程', () async {
      final host = newHost(threshold: 1);
      addTearDown(host.dispose);

      await host.start().timeout(const Duration(seconds: 30));
      await host.call('spider.create');
      await host.call('spider.destroy');

      // 此刻换新已启动：老进程正在关停、新进程还在重启通道上。
      await waitFor(() => !host.isReady);
      expect(host.isReady, isFalse);

      // call() 在未就绪时**不排队**（设计如此），直接回「未就绪」。
      final duringWindow = await host.call('spider.create');
      expect(duringWindow.isErr, isTrue);
      expect(
        duringWindow.errorOrNull?.code,
        ErrorCode.runtimeNotReady,
        reason: '窗口内 call 应当明确失败，而不是悄悄另起一个进程',
      );

      // 正确用法：先 waitReady() 等同一个宿主回来，再调用。
      final ready = await host.waitReady().timeout(const Duration(seconds: 30));
      expect(ready, isTrue, reason: '等的是同一个宿主，它自己会回来');
      final result = await host.call('spider.create');
      expect(result.isOk, isTrue);

      // 全程只该有「原来的 + 换新后的」两个真进程。
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        children,
        hasLength(2),
        reason: '重复建宿主会留下一个失控的子进程',
      );
    });
  });
}
