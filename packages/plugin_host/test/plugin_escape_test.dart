import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

void main() {
  group('沙箱逃逸', () {
    test('无 network 权限时 hasAllPermissions 为 false', () {
      final manifest = PluginManifest(
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

    test('路径穿越被拦截', () {
      expect(isPathTraversal('/sandbox/plugin1', '../etc/passwd'), isTrue);
      expect(isPathTraversal('/sandbox/plugin1', '/etc/passwd'), isTrue);
      expect(isPathTraversal('/sandbox/plugin1', 'a/../../b'), isTrue);
      expect(isPathTraversal('/sandbox/plugin1', 'data/file.json'), isFalse);
      expect(
        isPathTraversal('/sandbox/plugin1', '/sandbox/plugin1/data.json'),
        isFalse,
      );
    });

    test('配额超限视为未授权', () {
      // storage 权限未授予时，写操作应被视为越权
      final manifest = PluginManifest(
        id: 'quota',
        name: 'Quota',
        version: '1.0.0',
        type: PluginType.source,
        permissions: [PluginPermission.storage],
      );
      final checker = PermissionChecker({'quota': []});
      expect(checker.hasAllPermissions(manifest), isFalse);
    });

    test('SSRF 私网拦截由宿主层完成，此处仅验证权限闸门', () {
      final manifest = PluginManifest(
        id: 'ssrf',
        name: 'SSRF',
        version: '1.0.0',
        type: PluginType.source,
        permissions: [PluginPermission.network],
      );
      // 即使声明了 network，仍需宿主 HostApi 的 allowedHosts 白名单二次校验
      // 这里只验证权限层放行，具体 SSRF 拦截由 spider_host/host_api_test 覆盖
      final checker = PermissionChecker({
        'ssrf': [PluginPermission.network],
      });
      expect(checker.hasAllPermissions(manifest), isTrue);
    });
  });
}
