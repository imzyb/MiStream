import 'dart:convert';

import 'package:test/test.dart';
import 'package:updater/updater.dart';

UpdateManifest _manifest({
  String version = '0.2.0',
  String? minimumVersion,
  Map<String, Object?>? assets,
}) => UpdateManifest.fromFeed(
  jsonEncode({
    'version': version,
    'minimumVersion': ?minimumVersion,
    'assets':
        assets ??
        {
          portableAssetKey: {'url': 'https://example.com/a.zip'},
        },
  }),
);

void main() {
  const checker = UpdateChecker();

  group('UpdateChecker.evaluate', () {
    test('版本相同 → upToDate', () {
      final r = checker.evaluate(
        current: AppVersion.parse('0.2.0'),
        manifest: _manifest(),
      );
      expect(r.status, UpdateStatus.upToDate);
      expect(r.shouldPrompt, isFalse);
      expect(r.asset, isNull);
    });

    test('feed 更新 → available，并给出资产', () {
      final r = checker.evaluate(
        current: AppVersion.parse('0.1.0'),
        manifest: _manifest(),
      );
      expect(r.status, UpdateStatus.available);
      expect(r.shouldPrompt, isTrue);
      expect(r.asset?.url, 'https://example.com/a.zip');
      expect(r.forced, isFalse);
    });

    test('当前版本更新 → currentAhead，且**不提示**', () {
      final r = checker.evaluate(
        current: AppVersion.parse('0.3.0'),
        manifest: _manifest(),
      );
      expect(r.status, UpdateStatus.currentAhead);
      expect(r.shouldPrompt, isFalse);
    });

    test('有新版本但本平台没包 → noAsset（发布侧缺陷，不是检查失败）', () {
      final r = checker.evaluate(
        current: AppVersion.parse('0.1.0'),
        manifest: _manifest(
          assets: {
            'macos-arm64': {'url': 'https://example.com/mac.zip'},
          },
        ),
      );
      expect(r.status, UpdateStatus.noAsset);
      expect(r.asset, isNull);
      expect(r.shouldPrompt, isFalse);
    });

    test('低于 minimumVersion → forced', () {
      final r = checker.evaluate(
        current: AppVersion.parse('0.1.0'),
        manifest: _manifest(minimumVersion: '0.1.5'),
      );
      expect(r.forced, isTrue);
      expect(r.status, UpdateStatus.available);
    });

    test('版本没变时，即使 minimumVersion 写错也不强制', () {
      // 发布侧把 minimumVersion 写成比当前还高的值属于配置错误；
      // 但「版本相同」意味着没有包可下，这时提示用户毫无意义。
      final r = checker.evaluate(
        current: AppVersion.parse('0.2.0'),
        manifest: _manifest(minimumVersion: '0.9.9'),
      );
      expect(r.status, UpdateStatus.upToDate);
      expect(r.shouldPrompt, isFalse);
    });

    test('自定义资产键（将来 mac/linux）', () {
      final r = const UpdateChecker(assetKey: 'macos-arm64').evaluate(
        current: AppVersion.parse('0.1.0'),
        manifest: _manifest(
          assets: {
            'macos-arm64': {'url': 'https://example.com/mac.zip'},
          },
        ),
      );
      expect(r.status, UpdateStatus.available);
    });
  });
}
