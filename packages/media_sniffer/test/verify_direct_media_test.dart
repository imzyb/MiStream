/// [SnifferResolver.verifyDirectMedia] 的行为。
///
/// 单独一组：默认关闭与打开的语义差别很大（是否为直链多花一次往返、是否可能把
/// 能播的源判死），值得独立钉住。
library;

import 'package:media_sniffer/media_sniffer.dart';
import 'package:test/test.dart';

class _Fetcher {
  _Fetcher(this.responses);

  final Map<String, SniffResponse> responses;
  final calls = <String>[];

  Future<SniffResponse> call(String url, Map<String, String> headers) async {
    calls.add(url);
    return responses[url] ??
        const SniffResponse(statusCode: 404, body: 'not found');
  }
}

SniffResponse _playlist({String? finalUrl}) => SniffResponse(
  statusCode: 200,
  body: '#EXTM3U\n#EXTINF:10,\nseg0.ts\n',
  contentType: 'application/vnd.apple.mpegurl',
  finalUrl: finalUrl,
);

void main() {
  const direct = 'https://cdn.a.com/x/index.m3u8';

  group('verifyDirectMedia 关闭（默认）', () {
    test('不验证，直接返回原地址', () async {
      final fetcher = _Fetcher({});
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(direct);

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, direct);
      expect(fetcher.calls, isEmpty);
    });
  });

  group('verifyDirectMedia 打开', () {
    test('可达时返回，并识别出类型', () async {
      final fetcher = _Fetcher({direct: _playlist()});
      final resolver = SnifferResolver(
        fetcher: fetcher.call,
        verifyDirectMedia: true,
      );

      final outcome = await resolver.resolve(direct);

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, direct);
      expect(outcome.media!.type, MediaType.hls);
      expect(outcome.media!.viaSniffing, isFalse);
      expect(fetcher.calls, [direct]);
    });

    test('403 时判为不可用', () async {
      final fetcher = _Fetcher({
        direct: const SniffResponse(statusCode: 403, body: 'forbidden'),
      });
      final resolver = SnifferResolver(
        fetcher: fetcher.call,
        verifyDirectMedia: true,
      );

      final outcome = await resolver.resolve(direct);

      expect(outcome.isOk, isFalse);
      expect(outcome.failure, SniffFailure.pageUnavailable);
      expect(outcome.detail, contains('403'));
    });

    test('抓取抛异常时判为不可用', () async {
      final resolver = SnifferResolver(
        fetcher: (_, _) => throw Exception('boom'),
        verifyDirectMedia: true,
      );

      final outcome = await resolver.resolve(direct);

      expect(outcome.failure, SniffFailure.pageUnavailable);
      expect(outcome.detail, '请求失败');
    });

    test('跟随重定向后的地址生效', () async {
      const redirected = 'https://cdn.b.com/real/index.m3u8';
      final fetcher = _Fetcher({
        direct: _playlist(finalUrl: redirected),
      });
      final resolver = SnifferResolver(
        fetcher: fetcher.call,
        verifyDirectMedia: true,
      );

      final outcome = await resolver.resolve(direct);

      expect(outcome.media!.url, redirected);
    });

    test('不影响网页线路的正常嗅探', () async {
      const page = 'https://cdn.a.com/share/abc';
      final fetcher = _Fetcher({
        page: const SniffResponse(
          statusCode: 200,
          body: '<script>u="$direct"</script>',
          contentType: 'text/html',
        ),
        direct: _playlist(),
      });
      final resolver = SnifferResolver(
        fetcher: fetcher.call,
        verifyDirectMedia: true,
      );

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, direct);
      expect(outcome.media!.viaSniffing, isTrue);
    });
  });
}
