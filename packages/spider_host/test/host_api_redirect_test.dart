import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/spider_host.dart';
import 'package:test/test.dart';

/// SSRF 的重定向绕法。
///
/// ROADMAP M3 出口标准④明写「SSRF 逃逸测试全部被拦截（**含重定向到私网**）」。
/// 原实现只在初始 URL 上过一遍闸门，随后把 `followRedirects` 交给 HttpClient
/// 自动跟随——于是一个公网地址 302 到 http://127.0.0.1/ 或云元数据
/// 169.254.169.254 就能长驱直入。这是 SSRF 最常见的绕法。
///
/// 测试服务器本身跑在回环上，所以这里用 `privateChecker` 把「私网」定义成
/// 127.0.0.1 与 169.254.169.254，而放行 localhost——两个名字指向同一个服务器，
/// 正好当作「公网入口」与「内网目标」两种角色。
void main() {
  late HttpServer server;
  late int port;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;

    server.listen((req) async {
      final path = req.uri.path;
      switch (path) {
        case '/to-private':
          req.response
            ..statusCode = 302
            ..headers.set('location', 'http://127.0.0.1:$port/internal');
        case '/to-metadata':
          req.response
            ..statusCode = 302
            ..headers.set(
              'location',
              'http://169.254.169.254/latest/meta-data/',
            );
        case '/to-file':
          req.response
            ..statusCode = 302
            ..headers.set('location', 'file:///etc/passwd');
        case '/to-relative-private':
          // 相对地址形式的跳转，解析后仍要过闸门。
          req.response
            ..statusCode = 301
            ..headers.set('location', '/internal');
        case '/internal':
          req.response
            ..statusCode = 200
            ..write('内网数据不该被读到');
        case '/ok':
          req.response
            ..statusCode = 200
            ..write('正常内容');
        case '/to-ok':
          req.response
            ..statusCode = 302
            ..headers.set('location', 'http://localhost:$port/ok');
        default:
          // /hop/N → 逐级跳到 /hop/(N-1)，/hop/0 → /ok
          final hop = RegExp(r'^/hop/(\d+)$').firstMatch(path);
          if (hop != null) {
            final n = int.parse(hop.group(1)!);
            final next = n == 0
                ? 'http://localhost:$port/ok'
                : 'http://localhost:$port/hop/${n - 1}';
            req.response
              ..statusCode = 302
              ..headers.set('location', next);
          } else {
            req.response.statusCode = 404;
          }
      }
      await req.response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  HostApi apiWith({
    int maxRedirects = 5,
    List<String> allowedHosts = const [],
  }) => HostApi(
    config: HostFetchConfig(
      allowedHosts: allowedHosts,
      maxRedirects: maxRedirects,
      privateChecker: (h) => h == '127.0.0.1' || h == '169.254.169.254',
    ),
  );

  Future<Result<FetchResult, AppError>> fetch(
    HostApi api,
    String path, {
    bool redirect = true,
  }) => api.fetch(<String, Object?>{
    'instanceId': 'site:1',
    'url': 'http://localhost:$port$path',
    'redirect': redirect,
  });

  group('重定向到私网被拦截', () {
    test('302 到 127.0.0.1 被拦住，拿不到内网内容', () async {
      final result = await fetch(apiWith(), '/to-private');

      expect(result.isErr, isTrue, reason: '重定向到私网竟然放行了');
      expect(result.errorOrNull?.code, ErrorCode.privateAddressBlocked);
      // 双保险：即便将来错误码改了，也不能把内网响应体带回来。
      expect(result.valueOrNull, isNull);
    });

    test('302 到云元数据地址被拦住', () async {
      final result = await fetch(apiWith(), '/to-metadata');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.privateAddressBlocked);
    });

    test('相对地址的跳转解析后同样过闸门', () async {
      // /to-relative-private 跳到 /internal，而 /internal 在 localhost 上，
      // 是放行的——这条验证的是相对地址能被正确解析并继续跟随，不是拦截。
      final result = await fetch(apiWith(), '/to-relative-private');

      expect(result.isOk, isTrue, reason: result.errorOrNull?.message);
      expect(result.valueOrNull?.finalUrl, contains('/internal'));
    });

    test('302 到非白名单协议被拦住', () async {
      final result = await fetch(apiWith(), '/to-file');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.protocolNotAllowed);
    });

    test('302 到白名单外的域名被拦住', () async {
      // 只允许 localhost；/to-private 跳到 127.0.0.1，两道闸门都该拦。
      final result = await fetch(
        apiWith(allowedHosts: <String>['localhost']),
        '/to-private',
      );

      expect(result.isErr, isTrue);
      expect(
        result.errorOrNull?.code,
        anyOf(ErrorCode.privateAddressBlocked, ErrorCode.hostNotAllowed),
      );
    });
  });

  group('正常重定向仍要工作', () {
    test('跳到放行地址时正常跟随，finalUrl 是最后一跳', () async {
      final result = await fetch(apiWith(), '/to-ok');

      expect(result.isOk, isTrue, reason: result.errorOrNull?.message);
      expect(result.valueOrNull?.status, 200);
      expect(result.valueOrNull?.finalUrl, endsWith('/ok'));
    });

    test('redirect=false 时不跟随，原样返回 302', () async {
      final result = await fetch(apiWith(), '/to-private', redirect: false);

      // 不跟随就没有第二跳，自然也谈不上拦截——但绝不能把内网内容带回来。
      expect(result.isOk, isTrue, reason: result.errorOrNull?.message);
      expect(result.valueOrNull?.status, 302);
      expect(
        utf8.decode(result.valueOrNull!.body, allowMalformed: true),
        isNot(contains('内网数据')),
      );
    });

    test('多跳链条在上限内可以走完', () async {
      final result = await fetch(apiWith(), '/hop/3');

      expect(result.isOk, isTrue, reason: result.errorOrNull?.message);
      expect(result.valueOrNull?.finalUrl, endsWith('/ok'));
    });

    test('超过重定向上限报错，不会一直跟下去', () async {
      final result = await fetch(apiWith(maxRedirects: 2), '/hop/9');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.message, contains('重定向超过'));
    });
  });
}
