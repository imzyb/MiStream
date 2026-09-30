import 'package:live/live.dart';
import 'package:test/test.dart';

/// 一个可控的传输层桩：记录请求过的地址，按地址返回内容或抛错。
class _FakeFetcher {
  final List<String> requested = [];
  final List<String?> userAgents = [];
  final Map<String, String> bodies = {};
  final Set<String> failures = {};

  Future<String> call(String url, {String? userAgent}) async {
    requested.add(url);
    userAgents.add(userAgent);
    if (failures.contains(url)) throw StateError('连不上 $url');
    return bodies[url] ?? '';
  }
}

const _txtA = '''
央视频道,#genre#
CCTV1,http://a/1.m3u8
''';

const _txtB = '''
央视频道,#genre#
CCTV1,http://b/1.m3u8
卫视频道,#genre#
湖南卫视,http://b/2.m3u8
''';

void main() {
  group('resolveLiveUrl', () {
    test('相对路径按配置 URL 解析（真实配置里的 ./list.txt）', () {
      expect(
        resolveLiveUrl(
          './list.txt',
          baseUrl: 'https://raw.example.com/u/gao/master/0821.json',
        ),
        'https://raw.example.com/u/gao/master/list.txt',
      );
    });

    test('不带 ./ 的相对路径同样解析', () {
      expect(
        resolveLiveUrl('list.txt', baseUrl: 'https://a.com/d/c.json'),
        'https://a.com/d/list.txt',
      );
    });

    test('绝对地址原样返回', () {
      expect(
        resolveLiveUrl(
          'https://x.com/live.txt',
          baseUrl: 'https://a.com/c.json',
        ),
        'https://x.com/live.txt',
      );
    });

    test('没有 baseUrl 时原样返回（交给传输层报错，不悄悄拼）', () {
      expect(resolveLiveUrl('./list.txt'), './list.txt');
    });

    test('baseUrl 不合法时原样返回', () {
      expect(resolveLiveUrl('./list.txt', baseUrl: 'not a url'), './list.txt');
      expect(resolveLiveUrl('./list.txt', baseUrl: ''), './list.txt');
    });

    test('空地址返回空串', () {
      expect(resolveLiveUrl('   ', baseUrl: 'https://a.com/c.json'), '');
    });
  });

  group('LiveSubscription', () {
    test('logoFor 展开 {name} 占位符并做 URL 编码', () {
      const sub = LiveSubscription(
        url: 'http://x',
        logoTemplate: 'https://logo/tv/{name}.png',
      );

      expect(
        sub.logoFor('CCTV-1综合'),
        'https://logo/tv/CCTV-1%E7%BB%BC%E5%90%88.png',
      );
    });

    test('没有模板时 logoFor 返回 null', () {
      expect(const LiveSubscription(url: 'http://x').logoFor('CCTV1'), isNull);
      expect(
        const LiveSubscription(
          url: 'http://x',
          logoTemplate: '  ',
        ).logoFor('C'),
        isNull,
      );
    });

    test('频道名为空时 logoFor 返回 null', () {
      const sub = LiveSubscription(
        url: 'http://x',
        logoTemplate: 'https://logo/{name}.png',
      );

      expect(sub.logoFor(''), isNull);
    });
  });

  group('LiveImporter', () {
    late _FakeFetcher fetcher;
    late InMemoryLiveRepository repo;

    setUp(() {
      fetcher = _FakeFetcher();
      repo = InMemoryLiveRepository();
    });

    LiveImporter build() =>
        LiveImporter(repository: repo, fetcher: fetcher.call);

    test('单源导入：频道与分组落库', () async {
      fetcher.bodies['http://a/live.txt'] = _txtA;

      final report = await build().import([
        const LiveSubscription(url: 'http://a/live.txt', name: 'A'),
      ]);

      expect(report.okCount, 1);
      expect(report.written, isTrue);
      expect(report.channelCount, 1);
      expect(report.groupCount, 1);
      expect((await repo.getChannels()).length, 1);
      expect((await repo.getGroups()).map((g) => g.name), ['央视频道']);
    });

    test('多源合并：同名频道合成多线路', () async {
      fetcher.bodies['http://a/live.txt'] = _txtA;
      fetcher.bodies['http://b/live.txt'] = _txtB;

      final report = await build().import([
        const LiveSubscription(url: 'http://a/live.txt', name: 'A'),
        const LiveSubscription(url: 'http://b/live.txt', name: 'B'),
      ]);

      expect(report.okCount, 2);
      expect(report.channelCount, 2, reason: 'CCTV1 合并 + 湖南卫视');
      final cctv1 = (await repo.getChannels()).firstWhere(
        (c) => c.name == 'CCTV1',
      );
      expect(cctv1.allUrls, ['http://a/1.m3u8', 'http://b/1.m3u8']);
    });

    test('相对地址按 baseUrl 解析后再请求', () async {
      fetcher.bodies['https://cfg.example/d/list.txt'] = _txtA;

      await build().import(
        [const LiveSubscription(url: './list.txt')],
        baseUrl: 'https://cfg.example/d/0821.json',
      );

      expect(fetcher.requested, ['https://cfg.example/d/list.txt']);
    });

    test('单个源失败不中断整批', () async {
      fetcher.bodies['http://a/live.txt'] = _txtA;
      fetcher.failures.add('http://dead/live.txt');

      final report = await build().import([
        const LiveSubscription(url: 'http://dead/live.txt', name: '死的'),
        const LiveSubscription(url: 'http://a/live.txt', name: '活的'),
      ]);

      expect(report.okCount, 1);
      expect(report.failedCount, 1);
      expect(report.hasFailure, isTrue);
      expect(report.allFailed, isFalse);
      // 能用的那个源仍然落库了 —— 这正是「不中断」的意义。
      expect((await repo.getChannels()).length, 1);
    });

    test('全军覆没时不写库，旧列表原样保留', () async {
      fetcher.bodies['http://a/live.txt'] = _txtA;
      await build().import([const LiveSubscription(url: 'http://a/live.txt')]);
      expect((await repo.getChannels()).length, 1);

      fetcher.failures.add('http://a/live.txt');
      final report = await build().import([
        const LiveSubscription(url: 'http://a/live.txt'),
      ]);

      expect(report.allFailed, isTrue);
      expect(report.written, isFalse);
      expect(
        (await repo.getChannels()).length,
        1,
        reason: '一次网络抖动不该把已有频道清空',
      );
    });

    test('replace=false 时只解析不落库', () async {
      fetcher.bodies['http://a/live.txt'] = _txtA;

      final report = await build().import(
        [const LiveSubscription(url: 'http://a/live.txt')],
        replace: false,
      );

      expect(report.channelCount, 1);
      expect(report.written, isFalse);
      expect(await repo.getChannels(), isEmpty);
    });

    test('订阅地址为空时记一条失败，不请求', () async {
      final report = await build().import([
        const LiveSubscription(url: '   ', name: '空的'),
      ]);

      expect(report.failedCount, 1);
      expect(report.outcomes.single.error, isA<LiveImportError>());
      expect(fetcher.requested, isEmpty);
    });

    test('ua 透传给传输层', () async {
      fetcher.bodies['http://a/live.txt'] = _txtA;

      await build().import([
        const LiveSubscription(
          url: 'http://a/live.txt',
          userAgent: 'okhttp/3.15',
        ),
      ]);

      expect(fetcher.userAgents, ['okhttp/3.15']);
    });

    test('内容里没有 #EXTINF 时按 txt 解析（不信配置的 type）', () async {
      // 真实反例：配置写 `type: 0`（约定 M3U），内容是纯 txt。
      fetcher.bodies['http://a/live.txt'] = _txtA;

      final report = await build().import([
        const LiveSubscription(url: 'http://a/live.txt', type: 0),
      ]);

      expect(report.channelCount, 1);
      expect(report.result.channels.single.name, 'CCTV1');
    });

    test('空订阅列表：不写库、不报错', () async {
      final report = await build().import([]);

      expect(report.outcomes, isEmpty);
      expect(report.written, isFalse);
      expect(report.allFailed, isFalse, reason: '没有源可导 ≠ 全部失败');
      expect(fetcher.requested, isEmpty);
    });

    test('outcomes 顺序与输入一致', () async {
      fetcher.bodies['http://a/live.txt'] = _txtA;
      fetcher.failures.add('http://b/live.txt');

      final report = await build().import([
        const LiveSubscription(url: 'http://a/live.txt', name: 'first'),
        const LiveSubscription(url: 'http://b/live.txt', name: 'second'),
      ]);

      expect(report.outcomes.map((o) => o.subscription.name), [
        'first',
        'second',
      ]);
    });

    test('logo 模板展开给没有图标的频道', () async {
      fetcher.bodies['http://a/live.txt'] = _txtA;

      final report = await build().import([
        const LiveSubscription(
          url: 'http://a/live.txt',
          logoTemplate: 'https://logo/{name}.png',
        ),
      ]);

      expect(report.result.channels.single.logo, 'https://logo/CCTV1.png');
      expect((await repo.getChannels()).single.logo, 'https://logo/CCTV1.png');
    });

    test('自带 tvg-logo 的频道不被模板覆盖', () async {
      fetcher.bodies['http://a/m.m3u'] =
          '#EXTM3U\n'
          '#EXTINF:-1 tvg-logo="http://own/1.png",CCTV1\n'
          'http://a/1.m3u8\n';

      final report = await build().import([
        const LiveSubscription(
          url: 'http://a/m.m3u',
          logoTemplate: 'https://logo/{name}.png',
        ),
      ]);

      expect(
        report.result.channels.single.logo,
        'http://own/1.png',
        reason: '源站给的具体图标比按名字猜的准',
      );
    });

    test('没有 logo 模板时不动频道图标', () async {
      fetcher.bodies['http://a/live.txt'] = _txtA;

      final report = await build().import([
        const LiveSubscription(url: 'http://a/live.txt'),
      ]);

      expect(report.result.channels.single.logo, isNull);
    });
  });
}
