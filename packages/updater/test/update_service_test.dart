import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:updater/updater.dart';

import 'fakes.dart';

final _feedUrl = Uri.parse('https://example.com/latest.json');

String _feedBody({String version = '0.2.0'}) => jsonEncode({
  'version': version,
  'assets': {
    portableAssetKey: {'url': 'https://example.com/a.zip', 'size': 4},
  },
});

void main() {
  group('UpdateService.check', () {
    test('取 feed → 判断有更新', () async {
      final fetcher = FakeFetcher.bytes(utf8.encode(_feedBody()));
      final service = UpdateService(fetcher: fetcher, feedUrl: _feedUrl);

      final result = await service.check(AppVersion.parse('0.1.0'));
      expect(result.status, UpdateStatus.available);
      expect(fetcher.calls.single, _feedUrl);
    });

    test('feed 404 → UpdateServiceException，且标明可重试与否', () async {
      final service = UpdateService(
        fetcher: FakeFetcher.bytes(const [], status: 404),
        feedUrl: _feedUrl,
      );
      await expectLater(
        service.check(AppVersion.parse('0.1.0')),
        throwsA(
          isA<UpdateServiceException>()
              .having((e) => e.retryable, 'retryable', isFalse)
              .having((e) => e.message, 'message', contains('404')),
        ),
      );
    });

    test('feed 是 HTML 错误页 → 报「格式不对」而不是崩', () async {
      final service = UpdateService(
        fetcher: FakeFetcher.bytes(utf8.encode('<html>502</html>')),
        feedUrl: _feedUrl,
      );
      await expectLater(
        service.check(AppVersion.parse('0.1.0')),
        throwsA(
          isA<UpdateServiceException>().having(
            (e) => e.message,
            'message',
            contains('格式不对'),
          ),
        ),
      );
    });

    test('beta 渠道取的是 beta 那份', () async {
      final body = jsonEncode({
        'channels': {
          'stable': jsonDecode(_feedBody(version: '0.2.0')),
          'beta': jsonDecode(_feedBody(version: '0.3.0-beta.1')),
        },
      });
      final service = UpdateService(
        fetcher: FakeFetcher.bytes(utf8.encode(body)),
        feedUrl: _feedUrl,
        channel: UpdateChannel.beta,
      );
      final result = await service.check(AppVersion.parse('0.2.0'));
      expect(result.manifest.version, AppVersion.parse('0.3.0-beta.1'));
      expect(result.status, UpdateStatus.available);
    });
  });

  group('UpdateService.download', () {
    test('没有资产时直接报错，不发请求', () async {
      final fetcher = FakeFetcher.bytes(utf8.encode(_feedBody()));
      final service = UpdateService(fetcher: fetcher, feedUrl: _feedUrl);
      final result = await service.check(AppVersion.parse('0.1.0'));

      final noAsset = UpdateCheckResult(
        status: UpdateStatus.noAsset,
        manifest: result.manifest,
        current: result.current,
      );
      await expectLater(
        service.download(noAsset, Directory.systemTemp),
        throwsA(isA<UpdateServiceException>()),
      );
    });

    test('走通：check 之后能下到文件', () async {
      final dir = Directory.systemTemp.createTempSync('mistream-svc-test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final fetcher = FakeFetcher((uri) async {
        if (uri.path.endsWith('latest.json')) {
          return responseOf(utf8.encode(_feedBody()));
        }
        return responseOf(List<int>.filled(4, 9));
      });
      final service = UpdateService(fetcher: fetcher, feedUrl: _feedUrl);
      final result = await service.check(AppVersion.parse('0.1.0'));
      final file = await service.download(result, dir);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), 4);
      expect(fetcher.calls.length, 2);
    });
  });
}
