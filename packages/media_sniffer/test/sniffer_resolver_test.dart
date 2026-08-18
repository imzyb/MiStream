/// [SnifferResolver] 的单测。
///
/// 全部用假 [SniffFetcher]，不碰网络：解析逻辑的正确性与源站是否在线无关，
/// 而联网测试会在源站挂掉时变成假红灯。
library;

import 'dart:convert';

import 'package:media_sniffer/media_sniffer.dart';
import 'package:test/test.dart';

/// 记录请求、按 URL 返回预置响应的假抓取器。
class _FakeFetcher {
  _FakeFetcher(this.responses);

  /// URL → 响应。没登记的 URL 返回 404。
  final Map<String, SniffResponse> responses;

  /// 依次记录每一次请求，供断言「带对了 Referer」「没多发请求」。
  final calls = <({String url, Map<String, String> headers})>[];

  Future<SniffResponse> call(String url, Map<String, String> headers) async {
    calls.add((url: url, headers: Map.of(headers)));
    return responses[url] ??
        const SniffResponse(statusCode: 404, body: 'not found');
  }
}

SniffResponse _html(String body, {int status = 200, String? finalUrl}) =>
    SniffResponse(
      statusCode: status,
      body: body,
      contentType: 'text/html; charset=utf-8',
      finalUrl: finalUrl,
    );

SniffResponse _playlist({String? finalUrl}) => SniffResponse(
  statusCode: 200,
  body: '#EXTM3U\n#EXT-X-VERSION:3\n#EXTINF:10,\nseg0.ts\n',
  contentType: 'application/vnd.apple.mpegurl',
  finalUrl: finalUrl,
);

void main() {
  group('looksLikeDirectMedia', () {
    test('认出常见媒体后缀', () {
      expect(
        SnifferResolver.looksLikeDirectMedia('https://a.com/x/index.m3u8'),
        isTrue,
      );
      expect(
        SnifferResolver.looksLikeDirectMedia('https://a.com/x/v.mp4?t=1'),
        isTrue,
      );
      expect(
        SnifferResolver.looksLikeDirectMedia('https://a.com/v.flv'),
        isTrue,
      );
    });

    test('网页播放页不算直链', () {
      expect(
        SnifferResolver.looksLikeDirectMedia('https://a.com/share/abc123'),
        isFalse,
      );
      expect(
        SnifferResolver.looksLikeDirectMedia('https://a.com/play/1-2'),
        isFalse,
      );
    });

    test('查询串里的后缀不算', () {
      // 关键在于只看 path：`?next=a.m3u8` 的页面本身仍是网页。
      expect(
        SnifferResolver.looksLikeDirectMedia('https://a.com/play?next=a.m3u8'),
        isFalse,
      );
    });
  });

  group('直链快路径', () {
    test('m3u8 地址不发任何请求', () async {
      final fetcher = _FakeFetcher({});
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(
        'https://cdn.a.com/2026/x/index.m3u8',
        referer: 'https://api.a.com/',
      );

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, 'https://cdn.a.com/2026/x/index.m3u8');
      expect(outcome.media!.type, MediaType.hls);
      expect(outcome.media!.viaSniffing, isFalse);
      expect(fetcher.calls, isEmpty, reason: '直链不该触发网络请求');
    });

    test('带上 UA 与 Referer', () async {
      final fetcher = _FakeFetcher({});
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(
        'https://cdn.a.com/v.mp4',
        referer: 'https://api.a.com/',
      );

      expect(outcome.media!.headers['User-Agent'], defaultSniffUserAgent);
      expect(outcome.media!.headers['Referer'], 'https://api.a.com/');
    });

    test('extraHeaders 覆盖默认值', () async {
      final fetcher = _FakeFetcher({});
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(
        'https://cdn.a.com/v.mp4',
        referer: 'https://api.a.com/',
        extraHeaders: const {'User-Agent': 'custom/1.0'},
      );

      expect(outcome.media!.headers['User-Agent'], 'custom/1.0');
    });
  });

  group('网页线路嗅探', () {
    test('从 JS 变量里抽出 m3u8 并验证后返回', () async {
      const page = 'https://cdn.a.com/share/abc';
      const stream = 'https://cdn.a.com/2026/x/index.m3u8';
      final fetcher = _FakeFetcher({
        page: _html('<script>var url = "$stream";</script>'),
        stream: _playlist(),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(
        page,
        referer: 'https://api.a.com/',
      );

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, stream);
      expect(outcome.media!.type, MediaType.hls);
      expect(outcome.media!.viaSniffing, isTrue);
    });

    test('验证候选时把播放页当 Referer', () async {
      const page = 'https://cdn.a.com/share/abc';
      const stream = 'https://cdn.a.com/2026/x/index.m3u8';
      final fetcher = _FakeFetcher({
        page: _html('<source src="$stream">'),
        stream: _playlist(),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(
        page,
        referer: 'https://api.a.com/',
      );

      // 第一次请求页面用站点 Referer，第二次验证流地址改用播放页 —— 源站的
      // 反盗链就是照这个链条查的。
      expect(fetcher.calls.first.headers['Referer'], 'https://api.a.com/');
      expect(fetcher.calls.last.headers['Referer'], page);
      expect(outcome.media!.headers['Referer'], page);
    });

    test('转义成 \\/ 的 JS 地址能还原', () async {
      const page = 'https://cdn.a.com/share/abc';
      const stream = 'https://cdn.a.com/2026/x/index.m3u8';
      final fetcher = _FakeFetcher({
        page: _html(r'{"url":"https:\/\/cdn.a.com\/2026\/x\/index.m3u8"}'),
        stream: _playlist(),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, stream);
    });

    test('相对路径按页面地址解析', () async {
      const page = 'https://cdn.a.com/share/abc';
      const stream = 'https://cdn.a.com/2026/x/index.m3u8';
      final fetcher = _FakeFetcher({
        page: _html('<script>var f = "/2026/x/index.m3u8";</script>'),
        stream: _playlist(),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, stream);
    });

    test('协议相对地址补上 scheme', () async {
      const page = 'https://cdn.a.com/share/abc';
      const stream = 'https://cdn.b.com/x/index.m3u8';
      final fetcher = _FakeFetcher({
        page: _html('<script>src="//cdn.b.com/x/index.m3u8"</script>'),
        stream: _playlist(),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, stream);
    });

    test('base64 内联地址能解出来', () async {
      const page = 'https://cdn.a.com/share/abc';
      const stream = 'https://cdn.a.com/2026/xyz/index.m3u8';
      // 补足到 60 字符以上，模拟真实播放页的内联块。
      final blob = base64.encode(utf8.encode('{"file":"$stream","t":1}'));
      final fetcher = _FakeFetcher({
        page: _html('<script>var cfg = "$blob";</script>'),
        stream: _playlist(),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(blob.length, greaterThanOrEqualTo(60), reason: '样本要够长才会被扫描');
      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, stream);
    });

    test('页面直接返回 m3u8 正文时用原地址', () async {
      const page = 'https://cdn.a.com/share/abc';
      final fetcher = _FakeFetcher({page: _playlist()});
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, page);
      expect(outcome.media!.type, MediaType.hls);
      expect(outcome.media!.viaSniffing, isFalse);
      expect(fetcher.calls.length, 1, reason: '正文已是播放列表，不必再验证候选');
    });

    test('重定向后的地址优先于请求地址', () async {
      const page = 'https://cdn.a.com/share/abc';
      const redirected = 'https://cdn.a.com/real/index.m3u8';
      final fetcher = _FakeFetcher({
        page: _playlist(finalUrl: redirected),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.media!.url, redirected);
    });
  });

  group('候选排序与验证', () {
    test('HLS 优先于 MP4', () async {
      const page = 'https://cdn.a.com/share/abc';
      const mp4 = 'https://cdn.a.com/ad/trailer.mp4';
      const hls = 'https://cdn.a.com/2026/x/index.m3u8';
      final fetcher = _FakeFetcher({
        // mp4 在页面里出现得更早，但 m3u8 才是正片。
        page: _html('<video src="$mp4"></video><script>u="$hls"</script>'),
        hls: _playlist(),
        mp4: const SniffResponse(
          statusCode: 200,
          body: '',
          contentType: 'video/mp4',
        ),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.media!.url, hls);
    });

    test('前面的候选 403 时退到下一个', () async {
      const page = 'https://cdn.a.com/share/abc';
      const blocked = 'https://cdn.a.com/blocked/index.m3u8';
      const good = 'https://cdn.b.com/good/index.m3u8';
      final fetcher = _FakeFetcher({
        page: _html('<script>a="$blocked";b="$good";</script>'),
        blocked: _html('<h1>403 Forbidden</h1>', status: 403),
        good: _playlist(),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, good);
    });

    test('maxCandidates 限制验证次数', () async {
      const page = 'https://cdn.a.com/share/abc';
      final urls = List.generate(
        6,
        (i) => 'https://cdn.a.com/c$i/index.m3u8',
      );
      final fetcher = _FakeFetcher({
        page: _html(urls.map((u) => '"$u"').join(',')),
        // 全部不可达，逼它把额度用完。
      });
      final resolver = SnifferResolver(fetcher: fetcher.call, maxCandidates: 2);

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isFalse);
      expect(outcome.failure, SniffFailure.candidatesUnplayable);
      // 1 次取页面 + 2 次验证。
      expect(fetcher.calls.length, 3);
    });

    test('verifyCandidates=false 时直接返回首个候选', () async {
      const page = 'https://cdn.a.com/share/abc';
      const stream = 'https://cdn.a.com/x/index.m3u8';
      final fetcher = _FakeFetcher({page: _html('"$stream"')});
      final resolver = SnifferResolver(
        fetcher: fetcher.call,
        verifyCandidates: false,
      );

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isTrue);
      expect(outcome.media!.url, stream);
      expect(outcome.media!.viaSniffing, isTrue);
      expect(fetcher.calls.length, 1, reason: '关掉验证就只取一次页面');
    });
  });

  group('失败分类', () {
    test('页面 403 归为 pageUnavailable', () async {
      const page = 'https://cdn.a.com/share/abc';
      final fetcher = _FakeFetcher({
        page: _html('<h1>403</h1>', status: 403),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isFalse);
      expect(outcome.failure, SniffFailure.pageUnavailable);
      expect(outcome.detail, contains('403'));
    });

    test('抓取抛异常也归为 pageUnavailable', () async {
      final resolver = SnifferResolver(
        fetcher: (_, _) => throw const SocketExceptionStub(),
      );

      final outcome = await resolver.resolve('https://cdn.a.com/share/abc');

      expect(outcome.failure, SniffFailure.pageUnavailable);
    });

    test('页面里没有媒体地址归为 noMatch', () async {
      const page = 'https://cdn.a.com/share/abc';
      final fetcher = _FakeFetcher({
        page: _html('<html><body>请安装插件后观看</body></html>'),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.isOk, isFalse);
      expect(outcome.failure, SniffFailure.noMatch);
    });

    test('候选全不可达归为 candidatesUnplayable', () async {
      const page = 'https://cdn.a.com/share/abc';
      final fetcher = _FakeFetcher({
        page: _html('"https://cdn.a.com/x/index.m3u8"'),
      });
      final resolver = SnifferResolver(fetcher: fetcher.call);

      final outcome = await resolver.resolve(page);

      expect(outcome.failure, SniffFailure.candidatesUnplayable);
      expect(outcome.detail, contains('候选'));
    });
  });

  group('extractCandidates', () {
    late SnifferResolver resolver;

    setUp(() {
      resolver = SnifferResolver(
        fetcher: (_, _) async => const SniffResponse(statusCode: 404, body: ''),
      );
    });

    test('去重', () {
      final found = resolver.extractCandidates(
        '"https://a.com/x.m3u8" and again "https://a.com/x.m3u8"',
      );
      expect(found, ['https://a.com/x.m3u8']);
    });

    test('不把 .ts 分片当候选', () {
      final found = resolver.extractCandidates(
        '"https://a.com/seg001.ts" "https://a.com/x.m3u8"',
      );
      expect(found, ['https://a.com/x.m3u8']);
    });

    test('保留查询串', () {
      final found = resolver.extractCandidates(
        '"https://a.com/x.m3u8?token=abc&e=1"',
      );
      expect(found.single, 'https://a.com/x.m3u8?token=abc&e=1');
    });

    test('HTML 实体 &amp; 还原成 &', () {
      final found = resolver.extractCandidates(
        '"https://a.com/x.m3u8?a=1&amp;b=2"',
      );
      expect(found.single, 'https://a.com/x.m3u8?a=1&b=2');
    });

    test('空页面返回空列表', () {
      expect(resolver.extractCandidates(''), isEmpty);
    });
  });
}

/// 占位异常：只为让 fetcher 抛点什么，避免在测试里引 `dart:io`。
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
