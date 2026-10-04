/// `SnifferRuntime` 门面测试。
///
/// 这一层测的是**生命周期编排**：内核发现 → 启进程 → 连 CDP → 嗅 → 清理。
/// 协议与策略各自已有测试，这里只关心「顺序对不对、异常下清不干净」。
library;

import 'package:sniffer/sniffer.dart';
import 'package:test/test.dart';

import 'fake_cdp_transport.dart';

/// 一个不启动真实进程的 runtime：内核注入成假路径，传输注入成内存实现。
///
/// 但 `SnifferKernelProcess.launch` 会真的去起进程，所以这里只测**嗅探
/// 失败路径与可用性查询**这两类不进入启动流程的分支；需要真实启动的
/// 编排由 `kernel_process_test.dart` 覆盖。
SnifferRuntime runtimeWith({
  bool hasKernel = false,
  SnifferKernel? kernel,
}) => SnifferRuntime(
  kernelLocator: SnifferKernelLocator(fileExists: (_) => hasKernel),
  kernel: kernel,
);

void main() {
  group('可用性查询', () {
    test('无内核：isAvailable=false，resolvedKernel=null', () {
      final rt = runtimeWith();
      expect(rt.isAvailable, isFalse);
      expect(rt.resolvedKernel, isNull);
    });

    test('有内核：isAvailable=true，resolvedKernel 指向它', () {
      const k = SnifferKernel(
        path: r'C:\x\msedge.exe',
        kind: SnifferKernelKind.edge,
      );
      final rt = runtimeWith(kernel: k);
      expect(rt.isAvailable, isTrue);
      expect(rt.resolvedKernel, k);
    });

    test('探测抛异常时 isAvailable 收敛为 false 而不是崩', () {
      final rt = SnifferRuntime(
        kernelLocator: SnifferKernelLocator(
          fileExists: (_) => throw const _Boom(),
        ),
      );
      expect(rt.isAvailable, isFalse);
      expect(rt.resolvedKernel, isNull);
    });
  });

  group('无内核时的嗅探', () {
    test('返回 SNIFFER_UNAVAILABLE，不尝试启动进程', () async {
      final rt = runtimeWith();
      final outcome = await rt.sniff('https://page.example/watch');
      expect(outcome.isHit, isFalse);
      expect(outcome.failure, CdpSniffFailure.unavailable);
      expect(outcome.failure!.code, -32300);
    });

    test('提示里包含可操作信息（装什么 / 在哪配）', () async {
      final rt = runtimeWith();
      final outcome = await rt.sniff('https://page.example/watch');
      expect(outcome.detail, contains('Edge'));
      expect(outcome.detail, contains('Chrome'));
      expect(outcome.detail, contains('设置'));
    });

    test('提示里的内核名不写死平台', () async {
      // 文案要跨平台成立：Linux 上装的是 Chromium 而不是 Edge。
      final rt = runtimeWith();
      final outcome = await rt.sniff('https://page.example/watch');
      expect(outcome.detail, isNot(contains('WebView2')));
    });
  });

  group('自建 runtime 的默认值', () {
    test('transportFactory 缺省可用（不抛异常）', () {
      final rt = SnifferRuntime(
        kernelLocator: SnifferKernelLocator(fileExists: (_) => false),
      );
      expect(rt, isNotNull);
    });

    test('注入的 transportFactory 在真实启动时才被调用', () async {
      var called = 0;
      final rt = SnifferRuntime(
        kernelLocator: SnifferKernelLocator(fileExists: (_) => false),
        transportFactory: (ws) {
          called++;
          return FakeCdpTransport();
        },
      );
      // 没有内核，走不到建连那一步，工厂不该被调用。
      expect(called, 0);
      await rt.sniff('https://page.example/watch');
      expect(called, 0);
    });
  });
}

/// 制造一个探测期异常。
class _Boom implements Exception {
  const _Boom();
  @override
  String toString() => '_Boom';
}
