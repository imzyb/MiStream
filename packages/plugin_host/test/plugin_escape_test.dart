import 'dart:async';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

/// ROADMAP M9 出口标准第一条：**沙箱逃逸测试全部被拦截**
/// （越权网络、SSRF、路径穿越、配额超限）。
///
/// 四类的归属要分清，别在这一层假装验了别处的东西：
/// - **路径穿越** —— 本文件的 `路径穿越` 组（纯字符串层）
/// - **越权网络 / 配额** —— 本文件的 `权限闸门` 与 `并发限额` 组
/// - **SSRF** —— 不在这个包。私网拦截由宿主的 `HostApi` 白名单做，证据在
///   `spider_host/test/host_api_redirect_test.dart`（9 例）。这里只验「权限层
///   放行」这一步，验不了 SSRF 本身。
void main() {
  group('路径穿越', () {
    test('相对路径里的 .. 被真正消解', () {
      _expectEscape('/sandbox/plugin1', '../etc/passwd');
      _expectEscape('/sandbox/plugin1', 'a/../../b');
      _expectEscape('/sandbox/plugin1', '..');
    });

    test('绝对路径不在沙箱根下即逃逸', () {
      _expectEscape('/sandbox/plugin1', '/etc/passwd');
      _expectEscape('/sandbox/plugin1', '/');
    });

    test('兄弟目录：根是它的字符串前缀也不能放行', () {
      // 这是修之前真漏的一类。`'/sandbox/plugin1'` 是 `'/sandbox/plugin10'`
      // 的**字符串**前缀，前缀比较会把「去兄弟目录」判成「在沙箱内」。
      _expectEscape('/sandbox/plugin1', '/sandbox/plugin10/secret');
      _expectEscape('/sandbox/plugin1', '../plugin10/secret');
      _expectEscape('/sandbox/plugin1', '/sandbox/plugin1/../plugin2/x');
    });

    test('绝对路径里的 .. 也要消解（先进入再退出）', () {
      // 修之前：target 以根开头就早退，`..` 从未被解析。
      _expectEscape('/sandbox/plugin1', '/sandbox/plugin1/../../etc/passwd');
    });

    test('Windows 盘符路径下同样可用', () {
      // 修之前：根不以 `/` 开头，而解析结果总以 `/` 开头，
      // `startsWith` 恒 false → **恒判逃逸**，Windows 上沙箱完全不可用。
      _expectAllowed(r'C:\sandbox\plugin1', r'C:\sandbox\plugin1\data.json');
      _expectAllowed(r'C:\sandbox\plugin1', 'data/file.json');
      _expectEscape(r'C:\sandbox\plugin1', r'C:\Windows\System32\config');
      _expectEscape(r'C:\sandbox\plugin1', r'C:\sandbox\plugin10\secret');
      _expectEscape(r'C:\sandbox\plugin1', r'..\..\Windows\System32');
    });

    test('两种分隔符与冗余分隔符都归一化', () {
      _expectEscape('/sandbox/plugin1', r'..\etc\passwd');
      _expectEscape('/sandbox/plugin1', '//etc//passwd');
      _expectAllowed(r'C:\sandbox\plugin1', r'data\file.json');
    });

    test('合法路径不被误拦', () {
      _expectAllowed('/sandbox/plugin1', 'data/file.json');
      _expectAllowed('/sandbox/plugin1', '/sandbox/plugin1/data.json');
      _expectAllowed('/sandbox/plugin1', './data/./x.json');
      _expectAllowed('/sandbox/plugin1', 'data/../data/x.json');
      // 空串解析回沙箱根本身，不算逃逸。
      _expectAllowed('/sandbox/plugin1', '');
    });

    test('大小写语义：默认按平台，可显式指定', () {
      // Windows 的文件系统不敏感，其它平台敏感。显式传入让两种语义在任一
      // 平台都能验。
      expect(
        isPathTraversal('/Sandbox/P1', '/sandbox/p1/x', caseSensitive: false),
        isFalse,
      );
      expect(
        isPathTraversal('/Sandbox/P1', '/sandbox/p1/x', caseSensitive: true),
        isTrue,
      );
    });
  });

  group('权限闸门', () {
    test('未授予的权限一律判缺', () {
      const manifest = PluginManifest(
        id: 'evil',
        name: 'Evil',
        version: '1.0.0',
        type: PluginType.source,
        permissions: [PluginPermission.network],
      );
      final checker = PermissionChecker({'evil': []});

      expect(checker.hasAllPermissions(manifest), isFalse);
      expect(checker.getMissingPermissions(manifest), [
        PluginPermission.network,
      ]);
    });

    test('storage 未授予时同样判缺', () {
      const manifest = PluginManifest(
        id: 'quota',
        name: 'Quota',
        version: '1.0.0',
        type: PluginType.source,
        permissions: [PluginPermission.storage],
      );
      final checker = PermissionChecker({'quota': []});

      expect(checker.hasAllPermissions(manifest), isFalse);
      expect(checker.getMissingPermissions(manifest), [
        PluginPermission.storage,
      ]);
    });

    test('revoke 之后立即判缺（权限撤销路径）', () {
      const manifest = PluginManifest(
        id: 'p',
        name: 'P',
        version: '1.0.0',
        type: PluginType.source,
        permissions: [PluginPermission.network],
      );
      final checker = PermissionChecker({
        'p': [PluginPermission.network],
      });
      expect(checker.hasAllPermissions(manifest), isTrue);

      checker.revoke('p', PluginPermission.network);
      expect(checker.hasAllPermissions(manifest), isFalse);

      checker.grant('p', PluginPermission.network);
      expect(checker.hasAllPermissions(manifest), isTrue);
    });

    test('只声明不授予：声明本身不等于授权', () {
      const manifest = PluginManifest(
        id: 'declared',
        name: 'Declared',
        version: '1.0.0',
        type: PluginType.source,
        permissions: [PluginPermission.network, PluginPermission.fileSystem],
      );
      // 完全没出现在授予表里的插件
      final checker = PermissionChecker(const {});

      expect(checker.hasAllPermissions(manifest), isFalse);
      expect(checker.getGranted('declared'), isEmpty);
    });
  });

  group('并发限额', () {
    // 「配额超限」在 plugin_host 里就是这一层的并发上限；真正的资源配额
    // （磁盘 / 流量）不在这里，别在这一层假装验了它。
    test('超过上限的并发执行被拒', () async {
      final sandbox = PluginSandbox(maxConcurrentIsolates: 2);
      final gate = Completer<void>();
      final running = <Future<void>>[
        sandbox.execute('a', () => gate.future),
        sandbox.execute('b', () => gate.future),
      ];

      await expectLater(
        sandbox.execute('c', () async {}),
        throwsA(isA<StateError>()),
      );
      expect(sandbox.activeIsolateCount, 2);

      gate.complete();
      await Future.wait(running);
      expect(sandbox.activeIsolateCount, 0, reason: '任务结束后登记要清干净');
    });

    test('同一插件重入被拒', () async {
      final sandbox = PluginSandbox();
      final gate = Completer<void>();
      final first = sandbox.execute('a', () => gate.future);

      await expectLater(
        sandbox.execute('a', () async {}),
        throwsA(isA<StateError>()),
      );

      gate.complete();
      await first;
    });

    test('任务抛异常后登记被清掉，可以重来', () async {
      final sandbox = PluginSandbox();

      await expectLater(
        sandbox.execute('a', () async => throw StateError('插件炸了')),
        throwsA(isA<StateError>()),
      );

      expect(sandbox.activeIsolateCount, 0);
      expect(sandbox.isRunning('a'), isFalse);
      expect(await sandbox.execute('a', () async => 42), 42);
    });

    test('terminate 摘掉登记，但不中断已在跑的任务', () async {
      final sandbox = PluginSandbox();
      final gate = Completer<void>();
      var finished = false;
      final running = sandbox.execute('a', () async {
        await gate.future;
        finished = true;
      });

      await sandbox.terminate('a');
      expect(sandbox.isRunning('a'), isFalse);

      gate.complete();
      await running;
      expect(
        finished,
        isTrue,
        reason: 'terminate 只是簿记，不该中断任务（类文档已写明）',
      );
    });
  });
}

void _expectEscape(String root, String requested) {
  expect(
    isPathTraversal(root, requested),
    isTrue,
    reason: 'root=$root requested=$requested 应当判为逃逸',
  );
}

void _expectAllowed(String root, String requested) {
  expect(
    isPathTraversal(root, requested),
    isFalse,
    reason: 'root=$root requested=$requested 应当放行',
  );
}
