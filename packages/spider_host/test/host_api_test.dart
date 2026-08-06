import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/src/host/host_api.dart';
import 'package:test/test.dart';

void main() {
  group('HostApi.fetch', () {
    late HttpServer server;
    late int port;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = server.port;
      server.listen((request) {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"ok":true}')
          ..close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('正常抓取返回 JSON', () async {
      final api = HostApi();
      final result = await api.fetch({
        'url': 'http://127.0.0.1:$port/test',
      });
      expect(result.isOk, isTrue);
      final fetch = result.valueOrNull!;
      expect(fetch.status, 200);
      expect(fetch.finalUrl, 'http://127.0.0.1:$port/test');
      expect(utf8.decode(fetch.body), contains('{"ok":true}'));
    });

    test('私网地址被拦截（SSRF）', () async {
      final strict = HostApi(
        config: HostFetchConfig(
          privateChecker: (host) => true,
        ),
      );
      final blocked = await strict.fetch({
        'url': 'http://127.0.0.1:$port/test',
      });
      expect(blocked.isErr, isTrue);
      expect(blocked.errorOrNull?.code, ErrorCode.privateAddressBlocked);
    });

    test('协议不在白名单被拦截', () async {
      final api = HostApi();
      final result = await api.fetch({
        'url': 'ftp://example.com/file',
      });
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.protocolNotAllowed);
    });

    test('域名不在白名单被拦截', () async {
      final api = HostApi(
        config: HostFetchConfig(
          allowedHosts: ['example.com'],
        ),
      );
      final result = await api.fetch({
        'url': 'http://evil.com/test',
      });
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.hostNotAllowed);
    });

    test('URL 缺 scheme 报错', () async {
      final api = HostApi();
      final result = await api.fetch({'url': 'not-a-url'});
      expect(result.isErr, isTrue);
    });

    test('响应超过大小上限被拦截', () async {
      final bigServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bigPort = bigServer.port;
      final sub = bigServer.listen((request) {
        request.response
          ..statusCode = 200
          ..write('x' * 1000)
          ..close();
      });

      final api = HostApi(
        config: HostFetchConfig(maxResponseBytes: 100),
      );
      final result = await api.fetch({
        'url': 'http://127.0.0.1:$bigPort/big',
      });
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.responseTooLarge);

      await sub.cancel();
      await bigServer.close(force: true);
    });
  });

  group('HostApi.env', () {
    test('返回平台与 UA', () {
      final api = HostApi();
      final env = api.env({'instanceId': 'x'});
      expect(env['appVersion'], isNotEmpty);
      expect(env['defaultUA'], contains('Mozilla'));
      expect(env['platform'], isNotEmpty);
    });
  });
}
