import 'dart:convert';

import 'package:spider_js/spider_js.dart';
import 'package:spider_js/src/drpy/crypto.dart' as drpy;
import 'package:spider_js/src/drpy/html_parser.dart' as drpy;
import 'package:test/test.dart';

const _html = '''
<html>
<body>
  <div class="list">
    <a href="https://example.com/1">海贼王</a>
    <a href="https://example.com/2">火影</a>
  </div>
</body>
</html>
''';

const _rule = 'body&&.list&&a&&href';

void main() {
  // ---- 分发表本身不需要 native，CI 上照跑 ----
  group('HostBridge 分发表', () {
    late HostBridge bridge;

    setUp(() {
      bridge = HostBridge();
    });

    tearDown(() {
      bridge.dispose();
    });

    test('未登记的函数返回错误 payload 而不是抛出', () {
      final r = bridge.invoke('nope', <Object?>[]);
      expect(r['v'], isNull);
      expect(r['e'], contains('未登记的宿主函数'));
    });

    test('宿主函数抛错被收敛成错误 payload', () {
      final b = HostBridge(
        extraHandlers: <String, HostHandler>{
          'boom': (_) => throw StateError('炸了'),
        },
      );
      addTearDown(b.dispose);

      final r = b.invoke('boom', <Object?>[]);
      expect(r['e'], allOf(contains('boom'), contains('炸了')));
    });

    test('extraHandlers 可覆盖内置函数', () {
      final b = HostBridge(
        extraHandlers: <String, HostHandler>{'md5': (_) => 'stub'},
      );
      addTearDown(b.dispose);
      expect(b.invoke('md5', <Object?>['x'])['v'], 'stub');
    });

    test('摘要类与 Dart 实现一致', () {
      expect(bridge.invoke('md5', <Object?>['abc'])['v'], drpy.md5('abc'));
      expect(bridge.invoke('sha1', <Object?>['abc'])['v'], drpy.sha1('abc'));
      expect(
        bridge.invoke('sha256', <Object?>['abc'])['v'],
        drpy.sha256Drpy('abc'),
      );
      expect(
        bridge.invoke('hmac256', <Object?>['abc', 'k'])['v'],
        drpy.hmac256('abc', 'k'),
      );
    });

    test('HTML 解析类与 Dart 实现一致', () {
      expect(
        bridge.invoke('pdfh', <Object?>[_html, _rule])['v'],
        drpy.pdfh(_html, _rule),
      );
      expect(
        bridge.invoke('pdfa', <Object?>[_html, _rule])['v'],
        drpy.pdfa(_html, _rule),
      );
    });

    test('pd 把相对地址补成绝对地址', () {
      const html = '<div class="list"><a href="/vod/1.html">片</a></div>';
      expect(
        bridge.invoke('pd', <Object?>[
          html,
          '.list&&a&&href',
          'https://s.com/x/y.html',
        ])['v'],
        'https://s.com/vod/1.html',
      );
    });

    test('pdfl 批量补全，baseUrl 缺省时原样返回', () {
      const html = '<a href="/p/1">1</a><a href="/p/2">2</a>';
      expect(
        bridge.invoke('pdfl', <Object?>[
          html,
          'a&&href',
          'https://s.com/',
        ])['v'],
        <String>['https://s.com/p/1', 'https://s.com/p/2'],
      );
      expect(
        bridge.invoke('pdfl', <Object?>[html, 'a&&href'])['v'],
        <String>['/p/1', '/p/2'],
      );
    });

    test('base64 往返', () {
      final enc = bridge.invoke('base64Encode', <Object?>['中文 abc'])['v'];
      expect(enc, isA<String>());
      expect(bridge.invoke('base64Decode', <Object?>[enc])['v'], '中文 abc');
    });

    test('joinUrl 解析相对路径', () {
      expect(
        bridge.invoke('joinUrl', <Object?>['https://a.com/x/y', '../z'])['v'],
        'https://a.com/z',
      );
    });

    test('缺参补空串而不是崩', () {
      expect(bridge.invoke('md5', <Object?>[])['v'], drpy.md5(''));
    });

    test('console.log 落进 consoleOutput', () {
      bridge.invoke('console.log', <Object?>['log', 'a', 1]);
      expect(bridge.consoleOutput, <String>['log a 1']);
    });

    test('登记的函数名覆盖 drpy 同步 API', () {
      expect(
        bridge.handlerNames,
        containsAll(<String>[
          'pdfh',
          'pdfa',
          'pd',
          'pdfl',
          'md5',
          'sha1',
          'sha256',
          'hmac256',
          'urlencode',
          'urldecode',
          'base64Encode',
          'base64Decode',
          'joinUrl',
          'aes',
          'console.log',
        ]),
      );
    });
  });

  // ---- 真正从 JS 里调宿主函数，需要 native ----
  group('JS 里调用 drpy 宿主 API', () {
    late JsRuntime runtime;

    setUp(() {
      runtime = JsRuntime()..init();
    });

    tearDown(() {
      runtime.dispose();
    });

    test('桥已装上', () {
      expect(runtime.isHostBridgeAvailable, isTrue);
    });

    test('脚本里 pdfh 拿到与 Dart 相同的结果', () {
      final got = runtime.eval(
        'pdfh(${jsonEncode(_html)}, ${jsonEncode(_rule)})',
      );
      expect(got, drpy.pdfh(_html, _rule));
    });

    test('脚本里 pdfa 返回真数组，可参与 JS 数组运算', () {
      expect(
        runtime.eval('pdfa(${jsonEncode(_html)}, ${jsonEncode(_rule)}).length'),
        '${drpy.pdfa(_html, _rule).length}',
      );
      // 结果得是真的 JS 数组，不是被 String() 拍平的字符串。
      expect(
        runtime.eval(
          'Array.isArray(pdfa(${jsonEncode(_html)}, ${jsonEncode(_rule)}))',
        ),
        'true',
      );
    });

    test('脚本里 pd 把相对地址拼成绝对地址', () {
      const html = '<div class="list"><a href="/vod/1.html">片</a></div>';
      expect(
        runtime.eval(
          'pd(${jsonEncode(html)}, ".list&&a&&href", '
          '"https://s.com/x/y.html")',
        ),
        'https://s.com/vod/1.html',
      );
    });

    test('脚本里 pdfl 批量补全后仍是 JS 数组', () {
      const html = '<a href="/p/1">1</a><a href="/p/2">2</a>';
      expect(
        runtime.eval(
          'pdfl(${jsonEncode(html)}, "a&&href", "https://s.com/").join("|")',
        ),
        'https://s.com/p/1|https://s.com/p/2',
      );
    });

    test('脚本里 md5 与 Dart 一致', () {
      expect(runtime.eval('md5("abc")'), drpy.md5('abc'));
    });

    test('宿主返回值可直接参与 JS 运算', () {
      expect(
        runtime.eval('md5("abc").slice(0, 4).toUpperCase()'),
        drpy.md5('abc').substring(0, 4).toUpperCase(),
      );
    });

    test('base64 在脚本里往返', () {
      expect(runtime.eval('base64Decode(base64Encode("中文 abc"))'), '中文 abc');
    });

    test('console.log 从脚本落到 consoleOutput', () {
      runtime.eval('console.log("hello", 42)');
      expect(runtime.bridge.consoleOutput, contains('log hello 42'));
    });

    test('宿主抛错在脚本里可被 try/catch 接住', () {
      final got = runtime.eval(
        'try { __host("nope", []); "unreachable" } '
        'catch (e) { "caught:" + (e.message.indexOf("未登记") >= 0) }',
      );
      expect(got, 'caught:true');
    });

    test('宿主异常未捕获时冒泡成 eval 失败并带原因', () {
      expect(runtime.eval('__host("nope", [])'), isNull);
      expect(runtime.lastError, contains('未登记的宿主函数'));
    });

    test('多次调用不串味', () {
      expect(runtime.eval('md5("a")'), drpy.md5('a'));
      expect(runtime.eval('md5("b")'), drpy.md5('b'));
      expect(runtime.eval('sha1("a")'), drpy.sha1('a'));
    });
  }, skip: isQuickJSAvailable ? null : 'QuickJS native 不可用，跳过');
}
