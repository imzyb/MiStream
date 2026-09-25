/// 集成测试用的 mock TVBox 源服务。
///
/// 同时支持两种类型：
/// - type=1（JSON API / 苹果 CMS 风格）：`ac=videolist/list/detail` 端点。
/// - type=3（JS Spider）：`/spider.js` 端点，附带一个 `init` 函数和 `home` /
///   `category` / `categoryDetail` / `detail` / `search` / `play` 函数，每个
///   都用宿主提供的 `req()` 抓 Apple CMS 风格的 JSON 端点。
///
/// 供端到端集成测试使用，无需真实网络。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// mock 源服务。
class MockSourceServer {
  late final HttpServer _server;

  /// 实际监听的端口（绑定 0 由系统分配）。
  int get port => _server.port;

  /// 服务根地址。
  String get baseUrl => 'http://127.0.0.1:$port';

  /// Spider API 入口地址（type=1 站点使用）。
  String get apiUrl => '$baseUrl/api.php/provide/vod/';

  /// Spider 脚本地址（type=3 站点使用）。
  String get spiderJsUrl => '$baseUrl/spider.js';

  /// Spider 脚本源码。可在 [start] 之前修改，替换为不同形态的样例。
  String spiderJsScript = _defaultSpiderScript;

  /// 启动服务。
  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  /// 关闭服务。
  Future<void> close() => _server.close(force: true);

  void _handle(HttpRequest request) {
    final path = request.uri.path;
    if (path == '/diagnostic.html') {
      _respondText(
        request,
        '<!DOCTYPE html><html><body>导航页</body></html>',
        contentType: 'text/html; charset=utf-8',
      );
      return;
    }
    if (path == '/diagnostic.jpg') {
      _respondBytes(
        request,
        const [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46],
        contentType: 'image/x-ms-bmp',
      );
      return;
    }
    if (path == '/config.json') {
      _respondJson(request, _config());
      return;
    }
    // 落地页：被 UA 分流的源会把不认识的客户端踢到这里。
    if (path == '/landing.html') {
      _respondText(
        request,
        '<!DOCTYPE html><html><body>首页</body></html>',
        contentType: 'text/html; charset=utf-8',
      );
      return;
    }
    // 按 UA 分流（饭太硬 等真实订阅站的做法）：认 okhttp 才给配置，
    // 其它 UA 一律 302 到首页。浏览器 UA 会稳定地拿到 HTML。
    if (path == '/ua-okhttp.json') {
      if (_userAgentOf(request).contains('okhttp')) {
        _respondJson(request, _config());
      } else {
        _redirectTo(request, '/landing.html');
      }
      return;
    }
    // 与上面相反的分流：只认浏览器 UA，对 okhttp 返回网页。
    // 用来验证抓取层的「换 UA 重试」确实生效。
    if (path == '/ua-browser.json') {
      if (_userAgentOf(request).contains('okhttp')) {
        _respondText(
          request,
          '<!DOCTYPE html><html><body>不支持 okhttp</body></html>',
          contentType: 'text/html; charset=utf-8',
        );
      } else {
        _respondJson(request, _config());
      }
      return;
    }
    // 对**任何** UA 都 302 到首页。用来验证失败文案里带上了重定向链——
    // 「地址填对了却被踢到首页」正是靠这条链才能一眼看出来。
    if (path == '/ua-none.json') {
      _redirectTo(request, '/landing.html');
      return;
    }
    if (path == '/spider.js') {
      _respondText(
        request,
        spiderJsScript,
        contentType: 'application/javascript',
      );
      return;
    }
    if (path == '/lib/util.js') {
      _respondText(request, _utilScript, contentType: 'application/javascript');
      return;
    }
    if (path == '/api.php/provide/vod/' || path == '/api.php') {
      final ac = request.uri.queryParameters['ac'] ?? '';
      _handleAc(request, ac);
      return;
    }
    _respond(request, 404, 'Not found');
  }

  void _handleAc(HttpRequest request, String ac) {
    switch (ac) {
      case 'videolist':
        final wd = request.uri.queryParameters['wd'];
        if (wd != null && wd.isNotEmpty) {
          _respondJson(request, {
            'list': [
              {
                'vod_id': 3001,
                'vod_name': '搜索结果-$wd',
                'vod_pic': 'http://example.com/pic3.jpg',
              },
            ],
          });
        } else {
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
        }
      case 'list':
        final tid = request.uri.queryParameters['t'];
        if (tid != null && tid.isNotEmpty) {
          _respondJson(request, {
            'list': [
              {
                'vod_id': '2001',
                'vod_name': '分类剧集',
                'vod_pic': 'http://example.com/pic2.jpg',
              },
            ],
          });
        } else {
          _respondJson(request, {
            'list': [
              {'type_id': '1', 'type_name': '电影'},
              {'type_id': '2', 'type_name': '剧集'},
            ],
          });
        }
      case 'detail':
        _respondJson(request, {
          'list': [
            {
              'vod_id': '1001',
              'vod_name': '测试电影',
              'vod_pic': 'http://example.com/pic1.jpg',
              'vod_play_from': 'qiyi',
              'vod_play_url':
                  r'第1集$https://example.com/ep1.m3u8#第2集$https://example.com/ep2.m3u8',
            },
          ],
        });
      default:
        _respond(request, 404, 'Unknown ac: $ac');
    }
  }

  Map<String, Object?> _config() => {
    'spider': 'https://example.com/spider.jar',
    'sites': [
      {
        'key': 'mock-apple',
        'name': 'Mock源',
        'type': 1,
        'api': apiUrl,
      },
      {
        'key': 'mock-spider',
        'name': 'Mock Spider 源',
        'type': 3,
        'api': spiderJsUrl,
        'ext': '$baseUrl/api.php/provide/vod/',
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

  void _respondText(
    HttpRequest request,
    String body, {
    String contentType = 'text/plain; charset=utf-8',
  }) {
    _respond(request, 200, body, contentType: contentType);
  }

  void _respondBytes(
    HttpRequest request,
    List<int> bytes, {
    required String contentType,
  }) {
    final response = request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.parse(contentType)
      ..contentLength = bytes.length
      ..add(bytes);
    unawaited(response.close());
  }

  void _respond(
    HttpRequest request,
    int status,
    String body, {
    String contentType = 'text/plain; charset=utf-8',
  }) {
    final bytes = utf8.encode(body);
    final response = request.response
      ..statusCode = status
      ..headers.contentType = ContentType.parse(contentType)
      ..contentLength = bytes.length
      ..add(bytes);
    unawaited(response.close());
  }

  /// 取请求的 `User-Agent`；缺失时给空串。
  String _userAgentOf(HttpRequest request) =>
      request.headers.value(HttpHeaders.userAgentHeader) ?? '';

  /// 发一个 302 到 [location]。
  ///
  /// `location` 刻意用**相对路径**：真实源站（如 nginx 的 `return 302`）
  /// 常这么写，而抓取层若直接把它塞给 `getUrl` 就会炸——这里正好当回归探针。
  void _redirectTo(HttpRequest request, String location) {
    final response = request.response
      ..statusCode = HttpStatus.found
      ..headers.set(HttpHeaders.locationHeader, location)
      ..contentLength = 0;
    unawaited(response.close());
  }
}

/// 简化版 drpy2 脚本：仅暴露宿主注入的 `req()`（来自 drpy_host_functions）。
///
/// 没有 import 语句——所有逻辑都在脚本内。覆盖的 Spider 方法：
/// - `init(ext)` — 记录 ext 参数，供后续拼接 API 地址。
/// - `home(filter)` — 返回首页 `{class, list}`，list 走宿主 req 抓 `ac=videolist`。
/// - `category(tid, pg, filter, extend)` — 返回分类列表。
/// - `detail(ids)` — 返回详情。
/// - `search(wd, quick)` — 返回搜索结果。
/// - `play(flag, id, flags)` — 返回 `{url, parse, header}` 形态。
String get _defaultSpiderScript => '''
var __api__ = '';
var __ids__ = {};

function init(ext) {
  __api__ = ext || '';
  return {};
}

function home(filter) {
  var resp = req(__api__ + '?ac=videolist&pg=1', { method: 'GET' });
  return JSON.parse(resp.content);
}

function category(tid, pg, filter, extend) {
  var data = req(__api__ + '?ac=list&t=' + encodeURIComponent(tid) + '&pg=' + pg, { method: 'GET' });
  return JSON.parse(data.content);
}

function detail(ids) {
  var data = req(__api__ + '?ac=detail&ids=' + encodeURIComponent(ids), { method: 'GET' });
  var parsed = JSON.parse(data.content);
  if (parsed && parsed.list && parsed.list[0]) {
    __ids__[parsed.list[0].vod_id] = parsed.list[0];
  }
  return parsed;
}

function search(wd, quick) {
  var data = req(__api__ + '?ac=videolist&wd=' + encodeURIComponent(wd), { method: 'GET' });
  return JSON.parse(data.content);
}

function play(flag, id, flags) {
  return {
    url: 'https://example.com/' + flag + '/' + id + '/index.m3u8',
    parse: 0,
    header: { 'User-Agent': 'MiStream-test/1.0' }
  };
}

export default { init: init, home: home, category: category, detail: detail, search: search, play: play };
''';

/// 一个简单的辅助模块，用来验证 import 加载路径。
String get _utilScript => '''
function pickFirst(list) {
  if (!list || !list.length) return null;
  return list[0];
}
function safeJson(text) {
  try { return JSON.parse(text); } catch (e) { return null; }
}
export default { pickFirst: pickFirst, safeJson: safeJson };
export { pickFirst, safeJson };
''';
