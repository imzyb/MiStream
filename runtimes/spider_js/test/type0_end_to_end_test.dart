/// type=0 内置脚本的**真正执行**测试。
///
/// 与 `type0_script_test.dart` 的区别：那个只断言脚本源码里出现了某些字符串，
/// 脚本写得再错也照样绿。这里把 `type0Script` 喂给真实的 `RuntimeChild` +
/// 真实 QuickJS 跑一遍完整链路（`spider.create` → `spider.home` →
/// `spider.detail` → `spider.search`），断言宿主解析器**真的能读懂**返回的字段。
///
/// 网络用桩替掉（`installHostFunctions` 注入假的 `req`），所以不需要回环端口——
/// 本沙箱禁本地回环，走 mock HTTP server 的用例在这里必然失败。
library;

import 'dart:convert';

import 'package:spider_js/spider_js.dart';
import 'package:spider_js/src/child/runtime_child.dart';
import 'package:spider_js/src/child/sync_frame_io.dart';
import 'package:test/test.dart';

/// 站点的首页 / 分类页：链接与封面都是**相对地址**，用来验证脚本会补全。
const String _listHtml = '''
<html><body>
  <div class="list">
    <a href="/v/1"><img src="/img/1.jpg"><span>影片一</span></a>
    <a href="/v/2"><img src="/img/2.jpg"><span>影片二</span></a>
  </div>
  <a class="next" href="/list/1-2.html">下一页</a>
</body></html>
''';

/// 详情页。
const String _detailHtml = '''
<html><body>
  <h1>影片一</h1>
  <img src="/img/1.jpg">
  <div class="desc">简介文本</div>
  <div class="playlist">
    <h3>线路一</h3>
    <a href="/p/1-1">第1集</a>
    <a href="/p/1-2">第2集</a>
  </div>
</body></html>
''';

const String _site = 'https://site.test';

/// 源配置。字段名与 `type0_script.dart` 的文档一致。
Map<String, Object?> _ext() => <String, Object?>{
  'homeUrl': '$_site/',
  'homeRule': 'body&&.list&&a&&href',
  'listTitleRule': '.list&&span&&Text',
  'listPicRule': '.list&&img&&src',
  'classes': <Object?>[
    <String, Object?>{'type_id': '1', 'type_name': '电影'},
  ],
  'categoryUrl': '$_site/list/{tid}-{pg}.html',
  'categoryRule': 'body&&.list&&a&&href',
  'nextPageRule': 'a.next&&href',
  'detailRule': <String, Object?>{
    'vodName': 'h1&&Text',
    'vodPic': 'img&&src',
    'vodContent': '.desc&&Text',
    'vodPlayFrom': '.playlist&&h3&&Text',
    'vodPlayUrl': '.playlist&&a&&href',
    'vodPlayUrlName': '.playlist&&a&&Text',
  },
  'searchUrl': '$_site/search?wd={wd}',
  'searchRule': 'body&&.list&&a&&href',
};

/// 驱动主循环用的假管道（与 `runtime_child_test.dart` 同构）。
class _Pipe {
  _Pipe(List<Map<String, Object?>> inbound) {
    inbound.forEach(_add);
  }

  final List<int> _in = <int>[];
  final List<int> _out = <int>[];
  int _cursor = 0;

  void _add(Map<String, Object?> msg) {
    final body = utf8.encode(jsonEncode(msg));
    _in
      ..addAll(utf8.encode('Content-Length: ${body.length}\r\n\r\n'))
      ..addAll(body);
  }

  SyncFrameCodec get codec => SyncFrameCodec(
    readByte: () => _cursor < _in.length ? _in[_cursor++] : -1,
    write: _out.addAll,
  );

  List<Map<String, Object?>> get written {
    final reader = SyncFrameCodec(readByte: _readOut());
    final out = <Map<String, Object?>>[];
    for (;;) {
      final raw = reader.readFrame();
      if (raw == null) return out;
      out.add(jsonDecode(raw) as Map<String, Object?>);
    }
  }

  int Function() _readOut() {
    var i = 0;
    return () => i < _out.length ? _out[i++] : -1;
  }
}

Map<String, Object?> _req(int id, String method, [Map<String, Object?>? p]) =>
    <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': p ?? const <String, Object?>{},
    };

/// 跑一串请求，返回每次的 `result`（出错的直接抛出，带上子进程报的错误）。
List<Map<String, Object?>> _run(
  List<Map<String, Object?>> inbound, {
  required List<String> requested,
}) {
  final pipe = _Pipe(inbound);
  final child = RuntimeChild(
    codec: pipe.codec,
    // 只换掉 req，其余走真实的 JsRuntime + 真实 drpy 宿主函数（pdfh/pdfa/joinUrl）。
    installHostFunctions: (runtime, instanceId, _) {
      runtime.bridge.register('req', (args) {
        final url = args.isEmpty ? '' : '${args[0]}';
        requested.add(url);
        final body = url.contains('/search') || url.contains('/list/')
            ? _listHtml
            : url.contains('/v/')
            ? _detailHtml
            : _listHtml;
        // 与真实 `_req` 同形：{content, headers, code, url}。
        return <String, Object?>{
          'content': body,
          'headers': const <String, Object?>{},
          'code': 200,
          'url': url,
        };
      });
    },
  );
  child.run();
  // 必须显式释放：每个实例的 HostBridge 都持着一个 NativeCallable，不关掉
  // 测试进程会一直挂着不退出（表现为「All tests passed」之后超时）。
  child.dispose();

  final results = <Map<String, Object?>>[];
  for (final msg in pipe.written) {
    final error = msg['error'];
    if (error != null) {
      throw StateError('子进程返回错误: $error');
    }
    results.add((msg['result'] as Map?)?.cast<String, Object?>() ?? const {});
  }
  return results;
}

/// 建实例 + 依次调用，返回去掉 create 之后的每次结果。
List<Map<String, Object?>> _runCalls(
  List<Map<String, Object?>> calls, {
  required List<String> requested,
}) => _run(
  <Map<String, Object?>>[
    _req(1, 'spider.create', <String, Object?>{
      'instanceId': 'site:1',
      'script': type0Script,
      'config': _ext(),
    }),
    for (var i = 0; i < calls.length; i++) ...<Map<String, Object?>>[
      Map<String, Object?>.from(calls[i])
        ..['jsonrpc'] = '2.0'
        ..['id'] = i + 2,
    ],
  ],
  requested: requested,
).skip(1).toList();

void main() {
  group('type=0 内置脚本端到端', () {
    test('spider.create 报出脚本真正实现的能力位', () {
      final requested = <String>[];
      final results = _run(<Map<String, Object?>>[
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': type0Script,
          'config': _ext(),
        }),
      ], requested: requested);

      final caps = (results.single['capabilities']! as List).cast<String>();
      // 能力位是宿主派发的依据，脚本里函数名写错时这里会安静地少一项。
      expect(
        caps,
        containsAll(<String>['home', 'category', 'detail', 'search']),
      );
    });

    test('spider.home 返回宿主解析器认得的 {class, list}', () {
      final requested = <String>[];
      final results = _runCalls(<Map<String, Object?>>[
        _req(0, 'spider.home', <String, Object?>{'instanceId': 'site:1'}),
      ], requested: requested);

      final home = results.single;
      expect(
        home['class'],
        isA<List<Object?>>().having((l) => l.length, '长度', 1),
      );
      final cls = (home['class']! as List).first as Map<String, Object?>;
      expect(cls['type_id'], '1');
      expect(cls['type_name'], '电影');

      final list = (home['list']! as List).cast<Map<String, Object?>>();
      expect(list, hasLength(2));
      // 相对地址必须补全成绝对地址，否则详情页请求会打到错误的主机。
      expect(list[0]['vod_id'], '$_site/v/1');
      expect(list[0]['vod_name'], '影片一');
      expect(list[0]['vod_pic'], '$_site/img/1.jpg');
      expect(list[1]['vod_id'], '$_site/v/2');
      expect(requested, contains('$_site/'));
    });

    test('spider.detail 返回可解析的线路与剧集', () {
      final requested = <String>[];
      final results = _runCalls(<Map<String, Object?>>[
        _req(0, 'spider.detail', <String, Object?>{
          'instanceId': 'site:1',
          'args': <Object?>['$_site/v/1'],
        }),
      ], requested: requested);

      final detail =
          (results.single['list']! as List).first as Map<String, Object?>;
      expect(detail['vod_name'], '影片一');
      expect(detail['vod_pic'], '$_site/img/1.jpg');
      expect(detail['vod_content'], '简介文本');
      expect(detail['vod_play_from'], '线路一');
      // `名称$地址#名称$地址` —— 宿主按 `#` 拆集、`$` 拆名址。
      expect(detail['vod_play_url'], '第1集\$$_site/p/1-1#第2集\$$_site/p/1-2');
      expect(requested, contains('$_site/v/1'));
    });

    test('spider.detail 带两个参数走分类列表并补上 pagecount', () {
      final requested = <String>[];
      final results = _runCalls(<Map<String, Object?>>[
        _req(0, 'spider.detail', <String, Object?>{
          'instanceId': 'site:1',
          'args': <Object?>['1', 1],
        }),
      ], requested: requested);

      final page = results.single;
      expect(page['list']! as List, hasLength(2));
      expect(page['page'], 1);
      // 页面里有「下一页」→ 报 page+1，界面才能继续翻。
      expect(page['pagecount'], 2);
      expect(requested, contains('$_site/list/1-1.html'));
    });

    test('spider.search 用编码后的关键词请求搜索页', () {
      final requested = <String>[];
      final results = _runCalls(<Map<String, Object?>>[
        _req(0, 'spider.search', <String, Object?>{
          'instanceId': 'site:1',
          'args': <Object?>['海贼王', false, 1],
        }),
      ], requested: requested);

      expect(results.single['list']! as List, hasLength(2));
      // 中文关键词必须 encodeURIComponent，直接拼进 URL 会被服务端拒。
      expect(
        requested,
        contains('$_site/search?wd=%E6%B5%B7%E8%B4%BC%E7%8E%8B'),
      );
    });
  }, skip: isQuickJSAvailable ? null : 'QuickJS native 不可用，跳过');
}
