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
}
