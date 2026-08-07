import 'dart:convert';

import 'package:core_config/src/config_parser.dart';
import 'package:core_config/src/config_import_service.dart';
import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

const validConfig = '''
{
  "spider": "https://example.com/spider.jar",
  "sites": [
    {"key": "site1", "name": "源1", "type": 1, "api": "https://api1.com"}
  ],
  "parses": [
    {"name": "解析器1", "type": 1, "url": "https://parse1.com"}
  ],
  "lives": [
    {"name": "直播1", "url": "https://live1.m3u8"}
  ]
}
''';

void main() {
  group('LooseJsonParser', () {
    test('标准 JSON 正常解析', () {
      final result = LooseJsonParser.parse('{"a":1}');
      expect(result, {'a': 1});
    });

    test('容忍注释', () {
      final result = LooseJsonParser.parse('{"a":1 // 注释\n}');
      expect(result?['a'], 1);
    });

    test('容忍尾逗号', () {
      final result = LooseJsonParser.parse('{"a":1,"b":2,}');
      expect(result?['a'], 1);
      expect(result?['b'], 2);
    });

    test('非法 JSON 返回 null', () {
      expect(LooseJsonParser.parse('not json'), isNull);
    });
  });

  group('ConfigParser', () {
    test('完整配置解析', () {
      final config = ConfigParser.parse(validConfig);
      expect(config, isNotNull);
      expect(config!.spider, 'https://example.com/spider.jar');
      expect(config.sites, hasLength(1));
      expect(config.sites.first.name, '源1');
      expect(config.sites.first.type, 1);
      expect(config.parses, hasLength(1));
      expect(config.parses.first.name, '解析器1');
      expect(config.lives, hasLength(1));
    });

    test('空站返回空列表', () {
      final config = ConfigParser.parse('{"sites":[]}');
      expect(config, isNotNull);
      expect(config!.sites, isEmpty);
    });

    test('缺字段容错', () {
      final config = ConfigParser.parse('{"sites":[{"key":"x"}]}');
      expect(config, isNotNull);
      expect(config!.sites.first.name, '');
    });
  });

  group('ConfigImportService', () {
    test('完整导入链路', () {
      final result = ConfigImportService.import(
        utf8.encode(validConfig),
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.format, 'plain');
      expect(result.valueOrNull!.siteCount, 1);
    });

    test('非法 JSON 返回错误', () {
      final result = ConfigImportService.import(
        utf8.encode('not valid'),
      );
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configDecodeFailed);
    });

    test('无站点返回错误', () {
      final result = ConfigImportService.import(
        utf8.encode('{"sites":[]}'),
      );
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configEmpty);
    });

    test('Base64 编码配置', () {
      final encoded = base64Encode(utf8.encode(validConfig));
      final result = ConfigImportService.import(utf8.encode(encoded));
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.format, 'base64');
    });
  });
}
