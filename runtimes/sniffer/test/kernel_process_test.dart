/// 真实内核端到端测试。
///
/// 这部分**必须**用真实浏览器：`parseDevToolsUrl` 面对的是内核真实的
/// stdout 格式，profile 一次性、进程真的能起、端点真的会出现——这些都无法
/// 用 mock 证明。
///
/// 沙箱/CI 里没有浏览器时自动跳过，但**跳过而不是假装通过**：跳过的测试
/// 数会体现在测试报告里，不会给人「全都验证过了」的错觉。
///
/// 注意：本测试只验证到「内核起来了、DevTools 端点是真实的」，不建立
/// WebSocket 连接。受限环境会禁回环连接，但那不影响这一段的结论——
/// 协议层由 `cdp_client_test.dart` 用内存传输完整覆盖。
library;

import 'package:sniffer/sniffer.dart';
import 'package:test/test.dart';

void main() {
  const locator = SnifferKernelLocator();
  final kernel = locator.locate();
  final skipReason = kernel == null
      ? '本机没有 Edge / Chrome / Chromium，跳过真实内核测试'
      : null;

  group('DevTools 端点解析', () {
    test('解析标准输出行', () {
      const line =
          'DevTools listening on ws://127.0.0.1:9222/devtools/browser/abc-123';
      expect(
        SnifferKernelProcess.parseDevToolsUrl(line),
        'ws://127.0.0.1:9222/devtools/browser/abc-123',
      );
    });

    test('行首有其它输出时仍能提取', () {
      const line =
          '[0919/120000.123:INFO] DevTools listening on ws://127.0.0.1:52231/devtools/browser/deadbeef';
      expect(
        SnifferKernelProcess.parseDevToolsUrl(line),
        'ws://127.0.0.1:52231/devtools/browser/deadbeef',
      );
    });

    test('行尾有其它内容时按空白截断', () {
      const line =
          'DevTools listening on ws://127.0.0.1:9222/devtools/browser/x Some trailing text';
      expect(
        SnifferKernelProcess.parseDevToolsUrl(line),
        'ws://127.0.0.1:9222/devtools/browser/x',
      );
    });

    test('非 DevTools 行返回 null', () {
      expect(SnifferKernelProcess.parseDevToolsUrl('随便一行日志'), isNull);
      expect(
        SnifferKernelProcess.parseDevToolsUrl('http://example.com/not-ws'),
        isNull,
      );
      expect(
        SnifferKernelProcess.parseDevToolsUrl('ws://127.0.0.1:1/other/path'),
        isNull,
      );
    });
  });

  group('真实内核启动', () {
    test(
      '能启动内核并拿到真实 DevTools 端点',
      () async {
        final proc = await SnifferKernelProcess.launch(
          kernel: kernel,
          startupTimeout: const Duration(seconds: 30),
        );
        try {
          expect(proc.browserWebSocketUrl, startsWith('ws://127.0.0.1:'));
          expect(proc.browserWebSocketUrl, contains('/devtools/browser/'));
          // 端口由系统分配，不可能是 0。
          final uri = Uri.parse(proc.browserWebSocketUrl);
          expect(uri.port, greaterThan(0));
          expect(proc.httpEndpoint, 'http://127.0.0.1:${uri.port}');
          // profile 目录确实建出来了。
          expect(proc.profileDir.existsSync(), isTrue);
        } finally {
          await proc.dispose();
        }
      },
      skip: skipReason,
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'dispose 之后进程退出且 profile 被清理',
      () async {
        final proc = await SnifferKernelProcess.launch(
          kernel: kernel,
          startupTimeout: const Duration(seconds: 30),
        );
        final profilePath = proc.profileDir.path;
        await proc.dispose();

        expect(proc.profileDir.existsSync(), isFalse, reason: 'profile 应被删除');

        // 进程应该已经退出（给一点时间让 OS 回收）。
        var gone = false;
        for (var i = 0; i < 20; i++) {
          try {
            await proc.process.exitCode.timeout(
              const Duration(milliseconds: 250),
            );
            gone = true;
            break;
          } on Object {
            // 还没退出，继续等。
          }
        }
        expect(gone, isTrue, reason: '内核进程应已退出（profile: $profilePath）');
      },
      skip: skipReason,
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      '两次启动得到不同端口，互不干扰',
      () async {
        final a = await SnifferKernelProcess.launch(
          kernel: kernel,
          startupTimeout: const Duration(seconds: 30),
        );
        final b = await SnifferKernelProcess.launch(
          kernel: kernel,
          startupTimeout: const Duration(seconds: 30),
        );
        try {
          // 端口由系统分配（--remote-debugging-port=0），因此必然不同——
          // 这正是"同时嗅多个源不撞车"的保证。
          expect(
            a.browserWebSocketUrl,
            isNot(b.browserWebSocketUrl),
            reason: '两个实例的端点不应相同',
          );
          expect(a.profileDir.path, isNot(b.profileDir.path));
        } finally {
          await a.dispose();
          await b.dispose();
        }
      },
      skip: skipReason,
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      '用不存在的内核路径启动会失败并给出原因',
      () async {
        const bad = SnifferKernel(
          path: r'C:\definitely\not\here\nope.exe',
          kind: SnifferKernelKind.custom,
        );
        await expectLater(
          SnifferKernelProcess.launch(
            kernel: bad,
            startupTimeout: const Duration(seconds: 2),
          ),
          throwsA(isA<Object>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('本机内核探测（真实文件系统）', () {
    test('locate 使用的是真实的存在性检查', () {
      // 上面那组用的都是注入的 fileExists；这条用默认实现跑一次，
      // 确认默认路径列表在本机确实指向了真实文件。
      final found = const SnifferKernelLocator().locate();
      if (found == null) {
        // 本机确实没装浏览器，这也是一种合法结果。
        expect(found, isNull);
        return;
      }
      expect(found.path, isNotEmpty);
      expect(found.kind, isNot(SnifferKernelKind.custom));
    });
  });
}
