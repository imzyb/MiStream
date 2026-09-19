/// 内核发现测试。
///
/// 重点在**降级路径**：找不到内核时必须给出 `SNIFFER_UNAVAILABLE` 与可操作的
/// 提示，而不是一个无信息的失败。ADR-005 明确把这条列为不可省的行为
/// （原文是 Linux 缺 CEF 时「优雅降级并提示」）。
library;

import 'dart:io';

import 'package:sniffer/sniffer.dart';
import 'package:test/test.dart';

void main() {
  group('显式路径优先', () {
    test('给了存在的显式路径就用它，且类型是 custom', () {
      final locator = SnifferKernelLocator(
        explicitPath: r'D:\my\chrome.exe',
        fileExists: (p) => p == r'D:\my\chrome.exe',
      );
      final kernel = locator.locate();
      expect(kernel, isNotNull);
      expect(kernel!.path, r'D:\my\chrome.exe');
      expect(kernel.kind, SnifferKernelKind.custom);
    });

    test('显式路径不存在时不回退到探测', () {
      // 用户明确指定了却写错，应该直接报不可用，而不是偷偷用别的内核——
      // 否则用户会以为自己的配置生效了。
      final locator = SnifferKernelLocator(
        explicitPath: r'D:\nope\chrome.exe',
        // 除显式路径外一律"存在"：若发生回退，返回值必然非 null。
        fileExists: (p) => p != r'D:\nope\chrome.exe',
      );
      expect(locator.locate(), isNull);
    });

    test('空白显式路径按未设置处理', () {
      final locator = SnifferKernelLocator(
        explicitPath: '   ',
        fileExists: (p) => p.endsWith('msedge.exe'),
      );
      final kernel = locator.locate();
      expect(kernel, isNotNull);
      expect(kernel!.kind, SnifferKernelKind.edge);
    });
  });

  group('优先级', () {
    test('Edge 优先于 Chrome', () {
      final locator = SnifferKernelLocator(
        fileExists: (p) => p.contains('msedge.exe') || p.contains('chrome.exe'),
      );
      expect(locator.locate()!.kind, SnifferKernelKind.edge);
    });

    test('没有 Edge 时落到 Chrome', () {
      final locator = SnifferKernelLocator(
        fileExists: (p) => p.contains('chrome.exe'),
      );
      expect(locator.locate()!.kind, SnifferKernelKind.chrome);
    });

    test('返回的路径确实通过了存在性检查', () {
      const edge =
          r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe';
      final locator = SnifferKernelLocator(fileExists: (p) => p == edge);
      expect(locator.locate()!.path, edge);
    });
  });

  group('降级', () {
    test('全都没有时 locate 返回 null', () {
      final locator = SnifferKernelLocator(fileExists: (_) => false);
      expect(locator.locate(), isNull);
    });

    test('locateOrThrow 抛 SNIFFER_UNAVAILABLE 且码为 -32300', () {
      final locator = SnifferKernelLocator(fileExists: (_) => false);
      expect(
        locator.locateOrThrow,
        throwsA(
          isA<SnifferUnavailableException>().having(
            (e) => e.code,
            'code',
            -32300,
          ),
        ),
      );
    });

    test('异常信息提到探测过的路径数量，便于排查', () {
      final locator = SnifferKernelLocator(fileExists: (_) => false);
      try {
        locator.locateOrThrow();
        fail('应当抛出');
      } on SnifferUnavailableException catch (e) {
        expect(e.toString(), contains('SNIFFER_UNAVAILABLE'));
        expect(e.detail, contains('探测过'));
      }
    });

    test('存在性检查抛异常时按不存在处理', () {
      final locator = SnifferKernelLocator(
        fileExists: (_) => throw const FileSystemException('拒绝访问'),
      );
      expect(locator.locate(), isNull);
    });
  });

  group('SnifferKernel', () {
    test('相等基于路径与类型', () {
      const a = SnifferKernel(
        path: r'C:\x\chrome.exe',
        kind: SnifferKernelKind.chrome,
      );
      const b = SnifferKernel(
        path: r'C:\x\chrome.exe',
        kind: SnifferKernelKind.chrome,
      );
      const c = SnifferKernel(
        path: r'C:\x\chrome.exe',
        kind: SnifferKernelKind.edge,
      );
      expect(a, b);
      expect(a, isNot(c));
    });

    test('每种类型都有展示名', () {
      for (final kind in SnifferKernelKind.values) {
        expect(kind.label, isNotEmpty);
      }
      expect(SnifferKernelKind.edge.label, 'Microsoft Edge');
    });
  });

  group('SnifferRuntime 降级', () {
    test('无内核时返回 SNIFFER_UNAVAILABLE 且带可操作提示', () async {
      final runtime = SnifferRuntime(
        kernelLocator: SnifferKernelLocator(fileExists: (_) => false),
      );

      final outcome = await runtime.sniff('https://page.example/watch');
      expect(outcome.isHit, isFalse);
      expect(outcome.failure, CdpSniffFailure.unavailable);
      expect(outcome.failure!.code, -32300);
      // 提示要能指导用户下一步动作。
      expect(outcome.detail, contains('Edge'));
      expect(outcome.detail, contains('Chrome'));
    });

    test('无内核时 isAvailable 为 false 且 resolvedKernel 为 null', () {
      final runtime = SnifferRuntime(
        kernelLocator: SnifferKernelLocator(fileExists: (_) => false),
      );
      expect(runtime.isAvailable, isFalse);
      expect(runtime.resolvedKernel, isNull);
    });

    test('注入的 kernel 覆盖探测', () {
      const injected = SnifferKernel(
        path: r'C:\fake\chrome.exe',
        kind: SnifferKernelKind.custom,
      );
      final runtime = SnifferRuntime(
        kernel: injected,
        kernelLocator: SnifferKernelLocator(fileExists: (_) => false),
      );
      expect(runtime.isAvailable, isTrue);
      expect(runtime.resolvedKernel, injected);
    });
  });
}
