import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_source_server/mock_source_server.dart';
import 'package:mistream/application/config_install_service.dart';
import 'package:storage/storage.dart';

void main() {
  group('normalizeConfigUrl', () {
    test('中文域名转换为 punycode 并保留路径与查询参数', () {
      final normalized = normalizeConfigUrl(
        'http://www.饭太硬.cc/tv?source=1',
      );

      expect(normalized, 'http://www.xn--sss604efuw.cc/tv?source=1');
    });

    test('ASCII URL 保持不变', () {
      const url = 'https://example.com/config.json?x=1';
      expect(normalizeConfigUrl(url), url);
    });

    test('首尾空白会被移除', () {
      expect(
        normalizeConfigUrl('  https://example.com/config.json  '),
        'https://example.com/config.json',
      );
    });
  });

  test('非 HTTP(S) 地址返回 INVALID_ARGUMENT', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final service = ConfigInstallService(Repositories(db));

    final result = await service.installFromUrl('file:///config.json');

    expect(result.isErr, isTrue);
    expect(result.errorOrNull?.code, ErrorCode.invalidArgument);
  });

  group('真实源非 JSON 响应诊断', () {
    late MockSourceServer server;

    setUp(() async {
      server = MockSourceServer();
      await server.start();
    });

    tearDown(() => server.close());

    test('HTML 导航页返回 CONFIG_NOT_JSON', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final service = ConfigInstallService(Repositories(db));

      final result = await service.installFromUrl(
        '${server.baseUrl}/diagnostic.html',
      );

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configNotJson);
      expect(result.errorOrNull?.message, contains('网页（HTML）'));
    });

    test('伪装 JPEG 返回 CONFIG_NOT_JSON', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final service = ConfigInstallService(Repositories(db));

      final result = await service.installFromUrl(
        '${server.baseUrl}/diagnostic.jpg',
      );

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configNotJson);
      expect(result.errorOrNull?.message, contains('图片（JPEG）'));
    });
  });

  group('按 UA 分流的订阅源', () {
    late MockSourceServer server;

    setUp(() async {
      server = MockSourceServer();
      await server.start();
    });

    tearDown(() => server.close());

    test('认 okhttp 的源能拿到配置——饭太硬 就是这个形态', () async {
      // 该路由对非 okhttp 的 UA 一律 302 到首页。修复前用浏览器 UA 请求，
      // 必然拿到 HTML；现在默认装成 TVBox 客户端，应当直接成功。
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final service = ConfigInstallService(Repositories(db));

      final result = await service.installFromUrl(
        '${server.baseUrl}/ua-okhttp.json',
      );

      expect(result.isErr, isFalse, reason: result.errorOrNull?.message);
      expect(result.valueOrNull, greaterThan(0));
    });

    test('只认浏览器 UA 的源会在换 UA 重试后成功', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final service = ConfigInstallService(Repositories(db));

      final result = await service.installFromUrl(
        '${server.baseUrl}/ua-browser.json',
      );

      expect(result.isErr, isFalse, reason: result.errorOrNull?.message);
      expect(result.valueOrNull, greaterThan(0));
    });

    test('两个 UA 都被踢到首页时，失败文案里带出重定向链', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final service = ConfigInstallService(Repositories(db));

      final result = await service.installFromUrl(
        '${server.baseUrl}/ua-none.json',
      );

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configNotJson);
      final message = result.errorOrNull!.message;
      // 内容类别：让用户知道拿到的是网页而不是「地址无效」。
      expect(message, contains('网页（HTML）'));
      // 重定向链：地址填对却被踢走时，这是唯一能说明问题的证据。
      expect(message, contains('重定向'));
      expect(message, contains('/landing.html'));
      // 两次 UA 的尝试结果都要留痕，否则无法判断是不是 UA 的事。
      expect(message, contains('两次 UA 都试过'));
      expect(message, contains('浏览器 UA 的结果'));
    });
  });
}
