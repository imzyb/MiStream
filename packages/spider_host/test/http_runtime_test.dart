import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:spider_host/src/runtime/http_runtime.dart';
import 'package:test/test.dart';

/// 模拟一个 TVBox Spider API 服务。
Future<HttpServer> startMockApi() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    final uri = request.uri;
    final action = uri.queryParameters['action'] ?? '';
    switch (action) {
      case 'home':
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"list":[{"vod_id":"1","vod_name":"剧A"}]}')
          ..close();
      case 'category':
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"list":[{"type_id":"1","type_name":"电影"}]}')
          ..close();
      case 'detail':
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"vod_id":"1","vod_name":"剧A","vod_play_from":"qiyi"}')
          ..close();
      case 'search':
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"list":[{"vod_id":"2","vod_name":"搜索结果"}]}')
          ..close();
      case 'play':
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"url":"https://example.com/play.m3u8"}')
          ..close();
      default:
        request.response
          ..statusCode = 404
          ..write('Unknown action')
          ..close();
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
      expect((json['list'] as List<Object?>), hasLength(1));
    });

    test('category 返回分类列表', () async {
      final result = await runtime.category();
      expect(result.isOk, isTrue);
      final json = jsonDecode(result.valueOrNull!.body) as Map<String, Object?>;
      final list = (json['list'] as List<Object?>);
      expect((list.first as Map)['type_name'], '电影');
    });

    test('detail 返回详情', () async {
      final result = await runtime.detail(ids: '1');
      expect(result.isOk, isTrue);
      final json = jsonDecode(result.valueOrNull!.body) as Map<String, Object?>;
      expect(json['vod_name'], '剧A');
    });

    test('search 返回搜索结果', () async {
      final result = await runtime.search(keyword: '测试');
      expect(result.isOk, isTrue);
      final json = jsonDecode(result.valueOrNull!.body) as Map<String, Object?>;
      expect(json['list'], isNotEmpty);
    });

    test('play 返回播放地址', () async {
      final result = await runtime.play(flag: 'qiyi', ids: '1');
      expect(result.isOk, isTrue);
      final json = jsonDecode(result.valueOrNull!.body) as Map<String, Object?>;
      expect(json['url'], startsWith('https://'));
    });

    test('网络错误返回 Err', () async {
      final bad = HttpRuntime('http://127.0.0.1:1');
      final result = await bad.home();
      expect(result.isErr, isTrue);
    });

    test('自定义 URL 请求', () async {
      final result = await runtime.request(
        HttpRequestParams(
          url: 'http://127.0.0.1:$port?action=home',
        ),
      );
      expect(result.isOk, isTrue);
    });
  });
}
