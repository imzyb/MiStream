/// 嗅探策略测试。
///
/// 这是整个 sniffer 里最该被测的一层：「什么算媒体流」「什么时候放弃」
/// 直接决定用户能不能播。用内存传输驱动，覆盖各种真实页面的网络行为。
library;

import 'package:sniffer/sniffer.dart';
import 'package:test/test.dart';

import 'fake_cdp_transport.dart';

/// 组装一个连好线的会话与客户端。
///
/// 会话固定用短超时，避免测试等 20s。
({SniffSession session, CdpClient client, FakeCdpTransport transport}) build({
  Duration timeout = const Duration(milliseconds: 400),
  List<SnifferRule>? rules,
}) {
  final transport = FakeCdpTransport(
    replies: {
      // 会话开头必发的两条 enable 命令。
      'Network.enable': [const CdpScriptedReply()],
      'Page.enable': [const CdpScriptedReply()],
      'Page.navigate': [
        const CdpScriptedReply(result: {'frameId': 'F1'}),
      ],
    },
  );
  final client = CdpClient(transport);
  final session = SniffSession(totalTimeout: timeout, rules: rules);
  return (session: session, client: client, transport: transport);
}

void main() {
  group('命中判定', () {
    test('responseReceived 的 m3u8 Content-Type 命中', () async {
      final c = build();
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(Duration.zero);

      c.transport.emit(
        responseReceivedEvent(
          url: 'https://cdn.example/live/index.m3u8',
          mimeType: 'application/vnd.apple.mpegurl',
        ),
      );

      final outcome = await future;
      expect(outcome.isHit, isTrue);
      expect(outcome.url, 'https://cdn.example/live/index.m3u8');
      expect(outcome.media!.type, MediaType.hls);

      await c.client.close();
    });

    test('命中结果带上该请求的 header', () async {
      final c = build();
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(Duration.zero);

      c.transport.emit(
        responseReceivedEvent(
          url: 'https://cdn.example/v.mp4',
          mimeType: 'video/mp4',
          headers: {'Referer': 'https://page.example/', 'User-Agent': 'UA'},
        ),
      );

      final outcome = await future;
      expect(outcome.media!.headers['Referer'], 'https://page.example/');
      expect(outcome.media!.headers['User-Agent'], 'UA');

      await c.client.close();
    });

    test('video/* MIME 即使没有扩展名也命中', () async {
      final c = build();
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(Duration.zero);

      c.transport.emit(
        responseReceivedEvent(
          url: 'https://cdn.example/stream?id=42',
          mimeType: 'video/mp2t',
        ),
      );

      final outcome = await future;
      expect(outcome.isHit, isTrue);
      expect(outcome.url, 'https://cdn.example/stream?id=42');

      await c.client.close();
    });

    test('requestWillBeSent 抓 XHR 直链（无 MIME 信息）', () async {
      final c = build();
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(Duration.zero);

      c.transport.emit(
        requestWillBeSentEvent(
          url: 'https://cdn.example/a/b.flv',
          headers: {'Referer': 'https://page.example/'},
        ),
      );

      final outcome = await future;
      expect(outcome.isHit, isTrue);
      expect(outcome.media!.type, MediaType.flv);

      await c.client.close();
    });

    test('HTML/图片等非媒体请求不命中', () async {
      final c = build(timeout: const Duration(milliseconds: 250));
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(Duration.zero);

      c.transport.emit(
        responseReceivedEvent(
          url: 'https://cdn.example/logo.png',
          mimeType: 'image/png',
        ),
      );
      c.transport.emit(
        responseReceivedEvent(
          url: 'https://page.example/index.html',
          mimeType: 'text/html',
        ),
      );
      c.transport.emit(loadEventFired());

      final outcome = await future;
      expect(outcome.isHit, isFalse);
      expect(outcome.failure, CdpSniffFailure.noMatch);

      await c.client.close();
    });
  });

  group('排除规则', () {
    test('统计脚本域名被排除', () async {
      final c = build(timeout: const Duration(milliseconds: 250));
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(Duration.zero);

      // 名字里带 .m3u8 但来自统计域名——不该被当成播放地址。
      c.transport.emit(
        responseReceivedEvent(
          url: 'https://www.google-analytics.com/collect.m3u8',
          mimeType: 'application/vnd.apple.mpegurl',
        ),
      );
      c.transport.emit(loadEventFired());

      final outcome = await future;
      expect(outcome.isHit, isFalse);

      await c.client.close();
    });

    test('广告路径被排除', () async {
      final c = build(timeout: const Duration(milliseconds: 250));
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(Duration.zero);

      c.transport.emit(
        responseReceivedEvent(
          url: 'https://cdn.example/ads/promo.mp4',
          mimeType: 'video/mp4',
        ),
      );
      c.transport.emit(loadEventFired());

      final outcome = await future;
      expect(outcome.isHit, isFalse);

      await c.client.close();
    });
  });

  group('自定义规则', () {
    test('配置规则命中的地址能嗅到', () async {
      final c = build(
        timeout: const Duration(milliseconds: 300),
        rules: const [
          SnifferRule(
            name: '私有源直链',
            urlPattern: r'/v\d+/stream\?',
            priority: 1,
          ),
        ],
      );
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(Duration.zero);

      c.transport.emit(
        requestWillBeSentEvent(url: 'https://api.example/v2/stream?token=abc'),
      );

      final outcome = await future;
      expect(outcome.isHit, isTrue);

      await c.client.close();
    });

    test('非法正则的规则被忽略，不影响其它判定', () async {
      final c = build(
        timeout: const Duration(milliseconds: 300),
        rules: const [
          SnifferRule(name: '坏规则', urlPattern: '([unclosed', priority: 1),
        ],
      );
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(Duration.zero);

      c.transport.emit(
        responseReceivedEvent(url: 'https://cdn.example/x.m3u8'),
      );

      // 内置扩展名判定仍然生效——坏规则不该拖垮整条链路。
      final outcome = await future;
      expect(outcome.isHit, isTrue);

      await c.client.close();
    });
  });

  group('命令序列', () {
    test('先 enable Network 与 Page 再 navigate', () async {
      final c = build(timeout: const Duration(milliseconds: 200));
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.transport.emit(loadEventFired());
      await future;

      final methods = c.transport.sent.map((f) => f['method']).toList();
      final iNet = methods.indexOf('Network.enable');
      final iPage = methods.indexOf('Page.enable');
      final iNav = methods.indexOf('Page.navigate');
      expect(iNet, greaterThanOrEqualTo(0));
      expect(iPage, greaterThan(iNet));
      expect(iNav, greaterThan(iPage));

      await c.client.close();
    });

    test('navigate 收到的 URL 与请求一致', () async {
      final c = build(timeout: const Duration(milliseconds: 200));
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/vod/9');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.transport.emit(loadEventFired());
      await future;

      final nav = c.transport.paramsOf('Page.navigate').single;
      expect(nav['url'], 'https://page.example/vod/9');

      await c.client.close();
    });

    test('给了 headers 就调 setExtraHTTPHeaders', () async {
      final c = build(timeout: const Duration(milliseconds: 200));
      await c.client.connect();

      final future = c.session.sniff(
        c.client,
        'https://page.example/watch',
        headers: {'Referer': 'https://ref.example/'},
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.transport.emit(loadEventFired());
      await future;

      final params = c.transport.paramsOf('Network.setExtraHTTPHeaders').single;
      expect(params['headers'], {'Referer': 'https://ref.example/'});

      await c.client.close();
    });

    test('没给 headers 就不调 setExtraHTTPHeaders', () async {
      final c = build(timeout: const Duration(milliseconds: 200));
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/watch');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.transport.emit(loadEventFired());
      await future;

      expect(c.transport.paramsOf('Network.setExtraHTTPHeaders'), isEmpty);

      await c.client.close();
    });
  });

  group('失败语义与错误码', () {
    test('加载完成无命中 -> SNIFF_NO_MATCH(-32302)', () async {
      final c = build(timeout: const Duration(milliseconds: 300));
      await c.client.connect();

      final future = c.session.sniff(c.client, 'https://page.example/empty');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.transport.emit(loadEventFired());

      final outcome = await future;
      expect(outcome.isHit, isFalse);
      expect(outcome.failure, CdpSniffFailure.noMatch);
      expect(outcome.failure!.constant, 'SNIFF_NO_MATCH');
      expect(outcome.failure!.code, -32302);

      await c.client.close();
    });

    test('超时未加载完 -> SNIFF_TIMEOUT(-32301)', () async {
      final c = build(timeout: const Duration(milliseconds: 150));
      await c.client.connect();

      // 不推 loadEventFired，也不推任何媒体事件。
      final outcome = await c.session.sniff(
        c.client,
        'https://page.example/hang',
      );
      expect(outcome.isHit, isFalse);
      expect(outcome.failure, CdpSniffFailure.timeout);
      expect(outcome.failure!.code, -32301);

      await c.client.close();
    });

    test('navigate 报错 -> SNIFF_PAGE_ERROR(-32303)', () async {
      final transport = FakeCdpTransport(
        replies: {
          'Network.enable': [const CdpScriptedReply()],
          'Page.enable': [const CdpScriptedReply()],
          'Page.navigate': [
            const CdpScriptedReply(
              result: {'errorText': 'net::ERR_NAME_NOT_RESOLVED'},
            ),
          ],
        },
      );
      final client = CdpClient(transport);
      final session = SniffSession(totalTimeout: const Duration(seconds: 2));
      await client.connect();

      final outcome = await session.sniff(
        client,
        'https://nonexistent.invalid/',
      );
      expect(outcome.isHit, isFalse);
      expect(outcome.failure, CdpSniffFailure.pageError);
      expect(outcome.failure!.code, -32303);
      expect(outcome.detail, contains('ERR_NAME_NOT_RESOLVED'));

      await client.close();
    });

    test('每种失败的错误码覆盖 RPC §7.5 全表', () {
      expect(CdpSniffFailure.unavailable.code, -32300);
      expect(CdpSniffFailure.timeout.code, -32301);
      expect(CdpSniffFailure.noMatch.code, -32302);
      expect(CdpSniffFailure.pageError.code, -32303);
      expect(CdpSniffFailure.unavailable.constant, 'SNIFFER_UNAVAILABLE');
    });
  });

  group('CdpSniffOutcome', () {
    test('hit 的语义', () {
      const media = SnifferResult(url: 'https://a/x.m3u8', type: MediaType.hls);
      final hit = CdpSniffOutcome.hit(media, kernelLabel: 'Edge');
      expect(hit.isHit, isTrue);
      expect(hit.url, 'https://a/x.m3u8');
      expect(hit.failure, isNull);
      expect(hit.kernelLabel, 'Edge');
      expect(hit.toString(), contains('https://a/x.m3u8'));
    });

    test('miss 的语义', () {
      final miss = CdpSniffOutcome.miss(CdpSniffFailure.noMatch, '没找到');
      expect(miss.isHit, isFalse);
      expect(miss.url, isNull);
      expect(miss.detail, '没找到');
      expect(miss.toString(), contains('SNIFF_NO_MATCH'));
    });
  });
}
