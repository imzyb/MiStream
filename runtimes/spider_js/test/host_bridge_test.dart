import 'dart:convert';

import 'package:spider_js/spider_js.dart';
import 'package:spider_js/src/drpy/crypto.dart' as drpy;
import 'package:spider_js/src/drpy/gbk.dart' as drpy;
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

    test('gbkDecode 经分发表可用，字节数组入参', () {
      // '庆余年 第二季' 的 GBK 字节。脚本在 req(buffer: true) 后直接喂进来。
      final r = bridge.invoke('gbkDecode', <Object?>[
        <int>[199, 236, 211, 224, 196, 234, 32, 181, 218, 182, 254, 188, 190],
      ]);
      expect(r['v'], '庆余年 第二季');
      expect(r['e'], isNull);
    });

    test('gbkDecode 缺参不抛异常，返回空串', () {
      // 脚本写错参数时不该让整个源挂掉。
      expect(bridge.invoke('gbkDecode', <Object?>[])['v'], '');
      expect(bridge.invoke('gbkDecode', <Object?>[null])['v'], '');
    });

    test('rsaX 经分发表可用，位置参数形态', () {
      // 按 rsaX(mode, pub, encrypt, input, inBase64, key, outBase64) 传，
      // 而**不是**命名参数对象——存量源全是位置传参的。
      final r = bridge.invoke('rsaX', <Object?>[
        'RSA/PKCS1',
        true,
        true,
        'data',
        false,
        'garbage',
        true,
      ]);
      // 密钥非法，结果是空串（对齐参考实现），但关键是不抛异常。
      expect(r['v'], '');
      expect(r['e'], isNull);
    });

    test('rsaX 布尔实参容忍 1 / "true" 写法', () {
      // JS 侧写 1 或 'true' 的源不少，宿主按真值语义转换，不能只认 bool。
      for (final truthy in <Object?>[1, '1', 'true', true]) {
        final r = bridge.invoke('rsaX', <Object?>[
          'RSA/Bogus',
          truthy,
          true,
          'x',
          false,
          'k',
          false,
        ]);
        // 走到「不支持的 mode」说明 pub 被正确识别为 true 之外的分支不适用，
        // 这里只断言不抛异常、返回字符串。
        expect(r['v'], isA<String>());
        expect(r['e'], isNull);
      }
    });

    test('rsaX 缺参不抛异常', () {
      expect(bridge.invoke('rsaX', <Object?>[])['v'], '');
      expect(bridge.invoke('rsaX', <Object?>[null])['v'], '');
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
          'rsaX',
          'console.log',
        ]),
      );
    });

    // 位置参数是 drpy 的硬契约，直接从 Dart 侧按位置调一遍，覆盖
    // `_str` / `_bool` 的取值——JS 那边只做转调，真正解析参数的是这里。
    test('aes 按位置参数解释实参', () {
      const key = '0123456789abcdef';
      final cipher = bridge.invoke('aes', <Object?>[
        'AES/ECB/PKCS5Padding',
        true,
        'hello',
        false,
        key,
        '',
        true,
      ])['v'];
      expect(cipher, isA<String>());
      expect(cipher! as String, isNotEmpty);

      expect(
        bridge.invoke('aes', <Object?>[
          'AES/ECB/PKCS5Padding',
          false,
          cipher,
          true,
          key,
          '',
          false,
        ])['v'],
        'hello',
      );
    });

    test('aes 的布尔实参容忍 1/"1"/"true"', () {
      const key = '0123456789abcdef';
      // 源里写 `1` 而非 `true` 的不少，不能只认 bool。
      final viaInt = bridge.invoke('aes', <Object?>[
        'AES/ECB/PKCS5Padding',
        1,
        'hello',
        0,
        key,
        '',
        1,
      ])['v'];
      final viaBool = bridge.invoke('aes', <Object?>[
        'AES/ECB/PKCS5Padding',
        true,
        'hello',
        false,
        key,
        '',
        true,
      ])['v'];
      expect(viaInt, viaBool);
      expect(viaInt! as String, isNotEmpty);
    });

    test('aes 缺参时按空值处理而非抛异常', () {
      // 只给两个参数：mode 之外全是空/假值。ECB 缺 iv 是合法的，
      // 所以这里应走到「key 为空 -> 补零成 16 字节」而非崩掉。
      final r = bridge.invoke('aes', <Object?>['AES/ECB/PKCS5Padding', true]);
      expect(r['e'], isNull);
      expect(r['v'], isA<String>());
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

    test('gbkDecode 在脚本里可用（包装函数已注入）', () {
      // 这条是必要的兜底：只测 Dart 侧分发表会漏掉「JS 前导脚本没包装该函数」
      // 的情况——那时 typeof gbkDecode === 'undefined'，脚本直接报未定义。
      expect(runtime.eval('typeof gbkDecode'), 'function');
      expect(
        runtime.eval(
          'gbkDecode([199,236,211,224,196,234,32,181,218,182,254,188,190])',
        ),
        '庆余年 第二季',
      );
    });

    test('gbkDecode 与 Dart 实现结果一致', () {
      const bytes = <int>[214, 208, 206, 196, 215, 214, 183, 251];
      expect(
        runtime.eval('gbkDecode([214,208,206,196,215,214,183,251])'),
        drpy.gbkDecode(bytes),
      );
    });

    test('rsaX 在脚本里可用（包装函数已注入）', () {
      // 同 gbkDecode 的教训：只测 Dart 分发表会漏掉「JS 前导脚本没包装」，
      // 那时 typeof rsaX === 'undefined'，源一调用就挂。
      expect(runtime.eval('typeof rsaX'), 'function');

      // 位置传参、密钥非法 -> 返回空串，不该抛异常。
      final out = runtime.eval(
        "rsaX('RSA/PKCS1', true, true, 'data', false, 'garbage', true)",
      );
      expect(out, '');
      expect(runtime.lastError, isNull);
    });

    test('rsaX 七个参数按位置透传，不少传', () {
      // 漏传参数会被宿主当成空值，这里借「不支持的 mode」证明第 0 位确实
      // 传到了 mode 上。
      final out = runtime.eval(
        "rsaX('RSA/Nope', true, true, 'x', false, 'k', false)",
      );
      expect(out, '');
      // 走到 mode 分支说明前面 7 个位置都解析出来了。
      expect(runtime.lastError, isNull);
    });

    test('aes 在脚本里可用且七个参数按位置透传', () {
      // 前三位是 mode/encrypt/input，第四位 inBase64 决定第五位之后怎么解释。
      // 这里借「不支持的 mode」确认第 0 位落到了 mode 上。
      expect(
        runtime.eval("aes('AES/Nope', true, 'x', false, 'k', '', true)"),
        '',
      );
      expect(runtime.lastError, isNull);
    });

    test('aes 在脚本里加密→解密往返', () {
      final out = runtime.eval('''
(function () {
  var c = aes('AES/ECB/PKCS5Padding', true, 'hello', false,
              '0123456789abcdef', '', true);
  return aes('AES/ECB/PKCS5Padding', false, c, true,
             '0123456789abcdef', '', false);
})()
''');
      expect(out, 'hello');
      expect(runtime.lastError, isNull);
    });

    test('aes 兼容旧的对象入参写法', () {
      // 历史上有过一版按对象传的包装，本机缓存里的老源可能还带着那种写法。
      // JS 源码里含单引号，用三引号避免转义噪音。
      final out = runtime.eval('''
(function () {
  var c = aes({mode: 'AES/ECB/PKCS5Padding', encrypt: true,
               input: 'hello', key: '0123456789abcdef', outBase64: true});
  return aes({mode: 'AES/ECB/PKCS5Padding', encrypt: false,
              input: c, inBase64: true, key: '0123456789abcdef'});
})()
''');
      expect(out, 'hello');
      expect(runtime.lastError, isNull);
    });
  }, skip: isQuickJSAvailable ? null : 'QuickJS native 不可用，跳过');
}
