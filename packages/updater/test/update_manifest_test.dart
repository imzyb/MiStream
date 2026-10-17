import 'dart:convert';

import 'package:test/test.dart';
import 'package:updater/updater.dart';

String _feed({
  String version = '0.2.0',
  String? channel,
  Map<String, Object?>? assets,
  String? minimumVersion,
}) => jsonEncode({
  'channel': ?channel,
  'version': version,
  'releasedAt': '2026-10-17T12:00:00Z',
  'notes': '修好了站点',
  'minimumVersion': ?minimumVersion,
  'assets':
      assets ??
      {
        'windows-x64-portable': {
          'url': 'https://example.com/mistream-0.2.0.zip',
          'sha256': 'a' * 64,
          'size': 123,
        },
      },
});

void main() {
  group('UpdateAsset.parse', () {
    test('正常形状', () {
      final a = UpdateAsset.fromJson({
        'url': 'https://example.com/a.zip',
        'sha256': 'A' * 64,
        'size': 10,
      });
      expect(a.url, 'https://example.com/a.zip');
      expect(a.sha256, 'a' * 64, reason: 'sha256 统一转小写，避免大小写误判');
      expect(a.size, 10);
    });

    test('fileName 缺省时从 URL 末段推', () {
      final a = UpdateAsset.fromJson({'url': 'https://example.com/x/y.zip'});
      expect(a.resolvedFileName, 'y.zip');
    });

    test('显式 fileName 优先', () {
      final a = UpdateAsset.fromJson({
        'url': 'https://example.com/y.zip',
        'fileName': 'mistream.zip',
      });
      expect(a.resolvedFileName, 'mistream.zip');
    });

    test('缺 url / 非 http(s) / sha 长度不对 / size 非正 都要抛', () {
      expect(() => UpdateAsset.fromJson({}), throwsFormatException);
      expect(
        () => UpdateAsset.fromJson({'url': 'file:///c:/a.zip'}),
        throwsFormatException,
      );
      expect(
        () => UpdateAsset.fromJson({'url': '/relative/a.zip'}),
        throwsFormatException,
      );
      expect(
        () => UpdateAsset.fromJson({
          'url': 'https://e.com/a.zip',
          'sha256': 'abc',
        }),
        throwsFormatException,
      );
      expect(
        () => UpdateAsset.fromJson({'url': 'https://e.com/a.zip', 'size': 0}),
        throwsFormatException,
      );
    });
  });

  group('UpdateManifest.parse', () {
    test('单渠道', () {
      final m = UpdateManifest.fromFeed(_feed());
      expect(m.version, AppVersion.parse('0.2.0'));
      expect(m.channel, UpdateChannel.stable);
      expect(m.notes, '修好了站点');
      expect(m.releasedAt, DateTime.utc(2026, 10, 17, 12));
      expect(m.portable?.url, 'https://example.com/mistream-0.2.0.zip');
    });

    test('文件里写了 channel 就以文件为准', () {
      final m = UpdateManifest.fromFeed(_feed(channel: 'beta'));
      expect(m.channel, UpdateChannel.beta);
    });

    test('多渠道路由按请求的渠道取', () {
      final body = jsonEncode({
        'channels': {
          'stable': jsonDecode(_feed(version: '0.2.0')),
          'beta': jsonDecode(_feed(version: '0.3.0-beta.1')),
        },
      });
      expect(
        UpdateManifest.fromFeed(body).version,
        AppVersion.parse('0.2.0'),
      );
      expect(
        UpdateManifest.fromFeed(body, channel: UpdateChannel.beta).version,
        AppVersion.parse('0.3.0-beta.1'),
      );
    });

    test('多渠道里没有 beta 时回落到 stable', () {
      final body = jsonEncode({
        'channels': {'stable': jsonDecode(_feed())},
      });
      expect(
        UpdateManifest.fromFeed(body, channel: UpdateChannel.beta).version,
        AppVersion.parse('0.2.0'),
      );
    });

    test('minimumVersion 可选', () {
      expect(UpdateManifest.fromFeed(_feed()).minimumVersion, isNull);
      expect(
        UpdateManifest.fromFeed(_feed(minimumVersion: '0.1.5')).minimumVersion,
        AppVersion.parse('0.1.5'),
      );
    });

    test('坏输入要抛，tryParse 返回 null', () {
      expect(() => UpdateManifest.fromFeed('不是 json'), throwsFormatException);
      expect(() => UpdateManifest.fromFeed('[]'), throwsFormatException);
      expect(
        () => UpdateManifest.fromFeed(jsonEncode({'version': '1.0.0'})),
        throwsFormatException,
        reason: '缺 assets',
      );
      expect(
        () => UpdateManifest.fromFeed(
          jsonEncode(<String, Object?>{'version': '', 'assets': {}}),
        ),
        throwsFormatException,
      );
      expect(UpdateManifest.tryParse('不是 json'), isNull);
    });

    test('assetFor 找不到返回 null，不抛', () {
      final m = UpdateManifest.fromFeed(_feed());
      expect(m.assetFor('macos-arm64'), isNull);
      expect(m.assetFor(portableAssetKey), isNotNull);
    });
  });
}
