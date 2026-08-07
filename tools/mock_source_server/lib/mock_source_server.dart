/// 集成测试用的 mock TVBox Spider 源服务。
///
/// 模拟一个 type=1（JSON API）源，支持 home/category/detail/search/play。
/// 供端到端集成测试使用，无需真实网络。
library;

import 'dart:convert';
import 'dart:io';

/// mock 源服务。
class MockSourceServer {
  late final HttpServer _server;
  int get port => _server.port;
  String get baseUrl => 'http://127.0.0.1:$port';
  String get apiUrl => '$baseUrl/api.php';

  /// 启动服务。
  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  /// 关闭服务。
  Future<void> close() => _server.close(force: true);

  void _handle(HttpRequest request) {
    final path = request.uri.path;
    if (path == '/config.json') {
      _respondJson(request, _config());
      return;
    }
    if (path == '/api.php') {
      final action = request.uri.queryParameters['action'] ?? '';
      _handleAction(request, action);
      return;
    }
    _respond(request, 404, 'Not found');
  }

  void _handleAction(HttpRequest request, String action) {
    switch (action) {
      case 'home':
        _respondJson(request, {
          'class': [
            {'type_id': '1', 'type_name': '电影'},
            {'type_id': '2', 'type_name': '剧集'},
          ],
          'list': [
            {
              'vod_id': '1001',
              'vod_name': '测试电影',
              'vod_pic': 'http://example.com/pic1.jpg',
              'vod_remarks': 'HD',
              'vod_year': '2024',
            },
          ],
        });
      case 'category':
        _respondJson(request, {
          'list': [
            {
              'vod_id': '2001',
              'vod_name': '分类剧集',
              'vod_pic': 'http://example.com/pic2.jpg',
            },
          ],
        });
      case 'detail':
        _respondJson(request, {
          'list': [
            {
              'vod_id': '1001',
              'vod_name': '测试电影',
              'vod_pic': 'http://example.com/pic1.jpg',
              'vod_play_from': 'qiyi',
              'vod_play_url': '第1集' + 'https://example.com/ep1.m3u8',
            },
          ],
        });
      case 'search':
        final wd = request.uri.queryParameters['wd'] ?? '';
        _respondJson(request, {
          'list': [
            {
              'vod_id': '3001',
              'vod_name': '搜索结果-$wd',
              'vod_pic': 'http://example.com/pic3.jpg',
            },
          ],
        });
      case 'play':
        _respondJson(request, {
          'url': 'https://example.com/play.m3u8',
          'parse': 0,
        });
      default:
        _respond(request, 404, 'Unknown action: $action');
    }
  }

  Map<String, Object?> _config() => {
    'spider': 'https://example.com/spider.jar',
    'sites': [
      {
        'key': 'mock',
        'name': 'Mock源',
        'type': 1,
        'api': '$apiUrl',
      },
    ],
    'lives': [
      {'name': '直播', 'url': 'http://example.com/live.m3u8'},
    ],
  };

  void _respondJson(HttpRequest request, Object data) {
    _respond(
      request,
      200,
      jsonEncode(data),
      contentType: 'application/json',
    );
  }

  void _respond(
    HttpRequest request,
    int status,
    String body, {
    String contentType = 'text/plain; charset=utf-8',
  }) {
    final bytes = utf8.encode(body);
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.parse(contentType)
      ..contentLength = bytes.length
      ..add(bytes)
      ..close();
  }
}
