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

    Future<Map<String, Object?>> fetch(String path) async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('${server.baseUrl}$path'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);
      return jsonDecode(body) as Map<String, Object?>;
    }

    test('配置端点返回有效 TVBox 配置', () async {
      final config = await fetch('/config.json');
      expect(config['sites'], isA<List<Object?>>());
      expect(config['spider'], isNotEmpty);
    });

    test('home 返回分类与列表', () async {
      final home = await fetch('/api.php?action=home');
      expect(home['class'], isNotEmpty);
      expect(home['list'], isNotEmpty);
    });

    test('category 返回列表', () async {
      final cat = await fetch('/api.php?action=category&id=1&page=1');
      expect(cat['list'], isNotEmpty);
    });

    test('detail 返回详细', () async {
      final detail = await fetch('/api.php?action=detail&ids=1001');
      final list = detail['list'] as List<Object?>?;
      expect(list, isNotNull);
      expect(list, hasLength(1));
      final first = list!.first as Map<String, Object?>;
      expect(first['vod_name'], '测试电影');
    });

    test('search 返回搜索结果', () async {
      final search = await fetch('/api.php?action=search&wd=海贼王');
      final list = search['list'] as List<Object?>?;
      expect(list, isNotEmpty);
      final first = list!.first as Map<String, Object?>;
      expect(first['vod_name'], contains('海贼王'));
    });

    test('play 返回播放地址', () async {
      final play = await fetch('/api.php?action=play&flag=qiyi&ids=1001');
      expect(play['url'], isNotEmpty);
      expect(play['parse'], 0);
    });

    test('集成链路：配置 → 首页 → 搜索 → 详情 → 播放', () async {
      final config = await fetch('/config.json');
      final sites = config['sites'] as List<Object?>?;
      expect(sites, isNotEmpty);

      final home = await fetch('/api.php?action=home');
      final homeList = home['list'] as List<Object?>?;
      expect(homeList, isNotEmpty);
      final vodId =
          (homeList!.first as Map<String, Object?>)['vod_id'] as String?;
      expect(vodId, isNotEmpty);

      final search = await fetch('/api.php?action=search&wd=test');
      expect(search['list'], isNotEmpty);

      final detail = await fetch('/api.php?action=detail&ids=$vodId');
      final detailList = detail['list'] as List<Object?>?;
      expect(detailList, isNotEmpty);

      final play = await fetch('/api.php?action=play&flag=qiyi&ids=$vodId');
      expect(play['url'], isNotEmpty);
    });
  });
}
