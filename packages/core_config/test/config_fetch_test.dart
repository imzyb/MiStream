/// `config_fetch.dart` 的回归测试。
///
/// 只覆盖**纯逻辑**：状态码判定、重定向目标解析、诊断信息的可读性。
/// 真正的网络路径（`ConfigFetcher.fetch`）依赖真实 HTTP，而本沙箱禁本地
/// 回环，起不了测试服务器——这块的验证放到手工验收，见 `docs/11` 的口径。
library;

import 'package:core_config/core_config.dart';
import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('isRedirectStatus', () {
    test('认 301/302/303/307/308', () {
      for (final code in <int>[301, 302, 303, 307, 308]) {
        expect(isRedirectStatus(code), isTrue, reason: '$code');
      }
    });

    test('200/304/400/500 都不算重定向', () {
      for (final code in <int>[0, 200, 204, 304, 400, 403, 500]) {
        expect(isRedirectStatus(code), isFalse, reason: '$code');
      }
    });
  });

  group('resolveRedirectUrl', () {
    final current = Uri.parse('http://www.example.com/tv');

    test('绝对 Location 直接用', () {
      expect(
        resolveRedirectUrl(
          current: current,
          location: 'http://other.example.com/a',
          visited: const <String>[],
        ),
        'http://other.example.com/a',
      );
    });

    test('相对 Location 按当前 URL 解析——直接拿去请求会炸的就是这种', () {
      expect(
        resolveRedirectUrl(
          current: current,
          location: '/index.html',
          visited: const <String>[],
        ),
        'http://www.example.com/index.html',
      );
      expect(
        resolveRedirectUrl(
          current: Uri.parse('http://a.com/x/y/z'),
          location: '../w',
          visited: const <String>[],
        ),
        'http://a.com/x/w',
      );
    });

    test('Location 缺失或为空时不跟随', () {
      expect(
        resolveRedirectUrl(
          current: current,
          location: null,
          visited: const <String>[],
        ),
        isNull,
      );
      expect(
        resolveRedirectUrl(
          current: current,
          location: '',
          visited: const <String>[],
        ),
        isNull,
      );
    });

    test('目标已在链上时不跟随（成环）', () {
      expect(
        resolveRedirectUrl(
          current: Uri.parse('http://a.com/2'),
          location: 'http://a.com/1',
          visited: const <String>['http://a.com/1', 'http://a.com/2'],
        ),
        isNull,
      );
    });
  });

  group('ConfigFetchDiagnostics', () {
    test('没重定向时 effectiveUrl 就是请求地址', () {
      const diag = ConfigFetchDiagnostics(
        requestedUrl: 'http://a.com/tv',
        userAgent: kConfigFetchUserAgent,
        statusCode: 200,
        contentType: 'application/json',
        byteLength: 1234,
      );
      expect(diag.wasRedirected, isFalse);
      expect(diag.effectiveUrl, 'http://a.com/tv');
      expect(diag.describe(), 'HTTP 200 · application/json · 1234 字节');
    });

    test('有重定向时把整条链打出来——这是「地址没错却拿到 HTML」的唯一线索', () {
      const diag = ConfigFetchDiagnostics(
        requestedUrl: 'http://www.饭太硬.cc/tv',
        userAgent: kConfigFetchUserAgent,
        statusCode: 200,
        contentType: 'text/html',
        byteLength: 12486,
        redirectChain: <String>[
          'http://www.xn--sss604efuw.cc/',
          'http://www.xn--sss604efuw.cc/home',
        ],
      );
      expect(diag.wasRedirected, isTrue);
      expect(diag.effectiveUrl, 'http://www.xn--sss604efuw.cc/home');
      expect(
        diag.describe(),
        'HTTP 200 · text/html · 12486 字节；重定向 '
        'http://www.xn--sss604efuw.cc/ → http://www.xn--sss604efuw.cc/home',
      );
    });

    test('没有 content-type 时不硬凑分隔符', () {
      const diag = ConfigFetchDiagnostics(
        requestedUrl: 'http://a.com/tv',
        userAgent: 'ua',
        statusCode: 0,
      );
      expect(diag.describe(), 'HTTP 0 · 0 字节');
    });

    test('note 进 describe，也进 toDetail', () {
      const diag = ConfigFetchDiagnostics(
        requestedUrl: 'http://a.com/tv',
        userAgent: 'ua',
        statusCode: 200,
        byteLength: 999,
        note: '响应超过 16 MiB，已中止',
      );
      expect(diag.describe(), 'HTTP 200 · 999 字节（响应超过 16 MiB，已中止）');
      expect(diag.toDetail()['note'], '响应超过 16 MiB，已中止');
    });

    test('toDetail 带上定位问题需要的全部字段', () {
      const diag = ConfigFetchDiagnostics(
        requestedUrl: 'http://a.com/tv',
        userAgent: kConfigFetchUserAgent,
        statusCode: 302,
        contentType: 'text/html',
        byteLength: 138,
        redirectChain: <String>['http://b.com/'],
      );
      expect(diag.toDetail(), <String, Object?>{
        'url': 'http://a.com/tv',
        'userAgent': kConfigFetchUserAgent,
        'status': 302,
        'contentType': 'text/html',
        'bytes': 138,
        'redirects': <String>['http://b.com/'],
      });
    });
  });

  group('ConfigFetchOutcome', () {
    test('没有 error 就算成功', () {
      const ok = ConfigFetchOutcome(
        bytes: <int>[1, 2, 3],
        diagnostics: ConfigFetchDiagnostics(
          requestedUrl: 'http://a.com/tv',
          userAgent: 'ua',
        ),
      );
      expect(ok.isOk, isTrue);

      final bad = ConfigFetchOutcome(
        error: const RemoteError(
          code: ErrorCode.configFetchFailed,
          message: 'x',
        ),
        diagnostics: const ConfigFetchDiagnostics(
          requestedUrl: 'http://a.com/tv',
          userAgent: 'ua',
        ),
      );
      expect(bad.isOk, isFalse);
    });
  });

  group('UA 常量', () {
    test('配置拉取默认装成 TVBox 客户端，不是浏览器', () {
      // 这条断言是防回归的：把它改回浏览器 UA 会让「按 UA 分流」的订阅站
      // 全部失效（实测 饭太硬 就是这类站），而症状只是「返回的是网页」。
      expect(kConfigFetchUserAgent, startsWith('okhttp/'));
      expect(kConfigFetchBrowserUserAgent, startsWith('Mozilla/5.0'));
      expect(kConfigFetchUserAgent, isNot(kConfigFetchBrowserUserAgent));
    });
  });
}
