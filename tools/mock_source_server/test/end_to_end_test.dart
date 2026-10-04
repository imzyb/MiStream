import 'dart:convert';
import 'dart:io';

import 'package:mock_source_server/mock_source_server.dart';
import 'package:test/test.dart';

void main() {
  group('MockSourceServer 端到端', () {
    late MockSourceServer server;

    setUp(() async {
      server = MockSourceServer();
      await server.start();
    });

    tearDown(() async {
      await server.close();
    });

    Future<Map<String, Object?>> fetchJson(String path) async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('${server.baseUrl}$path'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);
      return jsonDecode(body) as Map<String, Object?>;
    }

    test('配置端点返回有效 TVBox 配置', () async {
      final config = await fetchJson('/config.json');
      expect(config['sites'], isA<List<Object?>>());
      expect(config['spider'], isNotEmpty);
    });

    test('配置同时包含 type=1 和 type=3 站点', () async {
      final config = await fetchJson('/config.json');
      final sites = (config['sites']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final types = sites.map((s) => s['type']).toSet();
      expect(types, containsAll(<Object?>[1, 3]));
      final spider = sites.firstWhere((s) => s['type'] == 3);
      expect(spider['api'], server.spiderJsUrl);
      expect(spider['ext'], server.apiUrl);
    });

    test('home 返回分类与列表', () async {
      final home = await fetchJson('/api.php/provide/vod/?ac=videolist&pg=1');
      expect(home['class'], isNotEmpty);
      expect(home['list'], isNotEmpty);
    });

    test('category 返回列表', () async {
      final cat = await fetchJson('/api.php/provide/vod/?ac=list');
      expect(cat['list'], isNotEmpty);
    });

    test('detail 返回详细', () async {
      final detail = await fetchJson(
        '/api.php/provide/vod/?ac=detail&ids=1001',
      );
      final list = detail['list'] as List<Object?>?;
      expect(list, isNotNull);
      expect(list, hasLength(1));
      final first = list!.first! as Map<String, Object?>;
      expect(first['vod_name'], '测试电影');
    });

    test('search 返回搜索结果', () async {
      final search = await fetchJson(
        '/api.php/provide/vod/?ac=videolist&wd=海贼王',
      );
      final list = search['list'] as List<Object?>?;
      expect(list, isNotEmpty);
      final first = list!.first! as Map<String, Object?>;
      expect(first['vod_name'], contains('海贼王'));
    });

    test('detail 返回播放地址', () async {
      final detail = await fetchJson(
        '/api.php/provide/vod/?ac=detail&ids=1001',
      );
      final list = detail['list']! as List<Object?>;
      final first = list.first! as Map<String, Object?>;
      expect(first['vod_play_from'], 'qiyi');
      expect(first['vod_play_url'], contains('https://example.com/ep1.m3u8'));
    });

    test('集成链路：配置 → 首页 → 搜索 → 详情 → 播放', () async {
      final config = await fetchJson('/config.json');
      final sites = config['sites'] as List<Object?>?;
      expect(sites, isNotEmpty);

      final home = await fetchJson('/api.php/provide/vod/?ac=videolist&pg=1');
      final homeList = home['list'] as List<Object?>?;
      expect(homeList, isNotEmpty);
      final vodId =
          (homeList!.first! as Map<String, Object?>)['vod_id'] as String?;
      expect(vodId, isNotEmpty);

      final search = await fetchJson(
        '/api.php/provide/vod/?ac=videolist&wd=test',
      );
      expect(search['list'], isNotEmpty);

      final detail = await fetchJson(
        '/api.php/provide/vod/?ac=detail&ids=$vodId',
      );
      final detailList = detail['list'] as List<Object?>?;
      expect(detailList, isNotEmpty);

      final first = detailList!.first! as Map<String, Object?>;
      expect(first['vod_play_url'], isNotEmpty);
    });
  });

  group('MockSourceServer Spider (type=3)', () {
    late MockSourceServer server;

    setUp(() async {
      server = MockSourceServer();
      await server.start();
    });

    tearDown(() async {
      await server.close();
    });

    Future<String> fetchText(String path) async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('${server.baseUrl}$path'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);
      return body;
    }

    test('spider.js 端点返回 drpy2 风格的脚本', () async {
      final script = await fetchText('/spider.js');
      expect(script, contains('function home('));
      expect(script, contains('function category('));
      expect(script, contains('function detail('));
      expect(script, contains('function search('));
      expect(script, contains('function play('));
      expect(script, contains('function init('));
      expect(script, contains('export default'));
    });

    test('util.js 端点返回可 import 的辅助模块', () async {
      final util = await fetchText('/lib/util.js');
      expect(util, contains('function pickFirst('));
      expect(util, contains('function safeJson('));
      expect(util, contains('export default'));
    });

    test('spiderJsScript 可注入替换', () async {
      server.spiderJsScript = '// custom script\nfunction init(){return {};}';
      final script = await fetchText('/spider.js');
      expect(script, '// custom script\nfunction init(){return {};}');
    });

    test('spider.js Content-Type 是 application/javascript', () async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(server.spiderJsUrl));
      final response = await request.close();
      final ct = response.headers.value('content-type') ?? '';
      client.close(force: true);
      expect(ct, contains('application/javascript'));
    });
  });
}
