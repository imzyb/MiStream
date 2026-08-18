import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:spider_host/src/runtime/http_runtime.dart';
import 'package:test/test.dart';

/// 写一条 JSON 响应并关闭。
///
/// 抽出来是因为 `..close()` 直接挂在级联末尾会丢弃它返回的 Future
/// （`discarded_futures`），而这里的关闭确实无需等待。
void _respondJson(HttpRequest request, String body, {int status = 200}) {
  final response = request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(body);
  unawaited(response.close());
}

/// 模拟一个 Apple CMS v2 API 服务。
Future<HttpServer> startMockApi() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    final ac = request.uri.queryParameters['ac'] ?? '';
    switch (ac) {
      case 'videolist':
        _respondJson(request, '{"list":[{"vod_id":1,"vod_name":"剧A"}]}');
      case 'list':
        _respondJson(
          request,
          '{"list":[{"type_id":1,"type_name":"电影"}]}',
        );
      case 'detail':
        _respondJson(
          request,
          '{"list":[{"vod_id":1,"vod_name":"剧A","vod_play_from":"qiyi","vod_play_url":"第1集\$https://example.com/ep1.m3u8"}]}',
        );
      default:
        final response = request.response
          ..statusCode = 404
          ..write('Unknown ac');
        unawaited(response.close());
    }
  });
  return server;
}

void main() {
  group('HttpRuntime', () {
    late HttpServer server;
    late int port;
    late HttpRuntime runtime;

    setUp(() async {
      server = await startMockApi();
      port = server.port;
      runtime = HttpRuntime('http://127.0.0.1:$port');
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('home 返回首页列表', () async {
      final result = await runtime.home();
      expect(result.isOk, isTrue);
      final data = result.valueOrNull!;
      expect(data.status, 200);
      final json = jsonDecode(data.body) as Map<String, Object?>;
      expect(json['list']! as List<Object?>, hasLength(1));
    });

    test('category 返回分类列表', () async {
      final result = await runtime.category();
      expect(result.isOk, isTrue);
      final json = jsonDecode(result.valueOrNull!.body) as Map<String, Object?>;
      final list = json['list']! as List<Object?>;
      expect((list.first! as Map)['type_name'], '电影');
    });

    test('detail 返回详情', () async {
      final result = await runtime.detail(ids: '1');
      expect(result.isOk, isTrue);
      final json = jsonDecode(result.valueOrNull!.body) as Map<String, Object?>;
      final list = json['list'] as List?;
      expect(list, isNotNull);
      expect(list!.first['vod_name'], '剧A');
    });

    test('search 返回搜索结果', () async {
      final result = await runtime.search(keyword: '测试');
      expect(result.isOk, isTrue);
      final json = jsonDecode(result.valueOrNull!.body) as Map<String, Object?>;
      expect(json['list'], isNotEmpty);
    });

    test('play 返回播放地址（通过 detail）', () async {
      final result = await runtime.play(flag: 'qiyi', ids: '1');
      expect(result.isOk, isTrue);
      final json = jsonDecode(result.valueOrNull!.body) as Map<String, Object?>;
      final list = json['list'] as List?;
      expect(list, isNotNull);
      final first = list!.first as Map;
      expect(first['vod_play_url'], contains('https://'));
    });

    test('网络错误返回 Err', () async {
      final bad = HttpRuntime('http://127.0.0.1:1');
      final result = await bad.home();
      expect(result.isErr, isTrue);
    });

    test('自定义 URL 请求', () async {
      final result = await runtime.request(
        HttpRequestParams(
          url: 'http://127.0.0.1:$port?ac=videolist',
        ),
      );
      expect(result.isOk, isTrue);
    });
  });
}
