import 'dart:convert';

import 'package:core_config/src/config_decoder.dart';
import 'package:core_domain/core_domain.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:test/test.dart';

void main() {
  const configJson = '{"spider":"https://example.com/api.php","sites":[]}';

  group('ConfigDecoder', () {
    test('明文 JSON 直接解码', () {
      final result = ConfigDecoder.decode(utf8.encode(configJson));
      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.format, 'plain');
      expect(result.valueOrNull?.json, configJson);
    });

    test('Base64 编码的 JSON 解码', () {
      final encoded = utf8.encode(base64Encode(utf8.encode(configJson)));
      final result = ConfigDecoder.decode(encoded);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.format, 'base64');
      expect(result.valueOrNull?.json, configJson);
    });

    test('AES 加密的 JSON 解码', () {
      const key = '0123456789abcdef';
      final aes = enc.AES(
        enc.Key.fromUtf8(key),
        mode: enc.AESMode.ecb,
      );
      final encrypted = aes.encrypt(utf8.encode(configJson));
      final result = ConfigDecoder.decode(
        encrypted.bytes,
        aesKey: key,
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.format, 'aes');
      expect(result.valueOrNull?.json, configJson);
    });

    test('全部路径失败返回 CONFIG_DECODE_FAILED', () {
      final result = ConfigDecoder.decode(utf8.encode('not valid {{'));
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configDecodeFailed);
    });

    test('空输入返回错误', () {
      final result = ConfigDecoder.decode(utf8.encode(''));
      expect(result.isErr, isTrue);
    });

    test('Base64 但非 JSON 内容回退到错误', () {
      // "hello" 的 base64 是有效 base64 但不是 JSON
      final encoded = utf8.encode(base64Encode(utf8.encode('hello')));
      final result = ConfigDecoder.decode(encoded);
      expect(result.isErr, isTrue);
    });
  });

  group('ConfigDecoder.decodeWithProbe', () {
    test('HTML 内容识别为 CONFIG_NOT_JSON', () {
      const html =
          '<!DOCTYPE html><html><head><title>导航</title></head><body></body></html>';
      final result = ConfigDecoder.decodeWithProbe(utf8.encode(html));
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configNotJson);
      expect(result.errorOrNull?.message, contains('网页（HTML）'));
    });

    test('图片（JPEG）识别为 CONFIG_NOT_JSON', () {
      // JPEG 魔数 FFD8FFE0 + 少量填充
      final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(16, 0x00)];
      final result = ConfigDecoder.decodeWithProbe(jpeg);
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configNotJson);
      expect(result.errorOrNull?.message, contains('图片（JPEG）'));
    });

    test('图片（BMP）识别为 CONFIG_NOT_JSON', () {
      // BMP 魔数 424D + 少量填充
      final bmp = [0x42, 0x4D, ...List.filled(16, 0x00)];
      final result = ConfigDecoder.decodeWithProbe(bmp);
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configNotJson);
    });

    test('普通乱码仍回退 CONFIG_DECODE_FAILED', () {
      final result = ConfigDecoder.decodeWithProbe(utf8.encode('not valid {{'));
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configDecodeFailed);
    });

    test('合法 JSON 仍正常解码', () {
      final result = ConfigDecoder.decodeWithProbe(utf8.encode(configJson));
      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.format, 'plain');
    });
  });

  group('ConfigDecoder 宽容解析（TVBox 配置普遍不是严格 JSON）', () {
    test('行首 // 注释被剔除后能解码', () {
      const raw =
          '{\n'
          '  // 这是注释\n'
          '  "sites": []\n'
          '}';
      final result = ConfigDecoder.decode(utf8.encode(raw));
      expect(result.isOk, isTrue);
      expect(jsonDecode(result.valueOrNull!.json), {'sites': <Object?>[]});
    });

    test('行尾 // 注释被剔除后能解码', () {
      const raw =
          '{\n'
          '  "sites": [], // 备用地址见下\n'
          '  "spider": "x"\n'
          '}';
      final result = ConfigDecoder.decode(utf8.encode(raw));
      expect(result.isOk, isTrue);
      expect(jsonDecode(result.valueOrNull!.json), {
        'sites': <Object?>[],
        'spider': 'x',
      });
    });

    test('字符串里的 http:// 不被注释剥离破坏', () {
      // 这是最容易写错的地方：用正则剥 // 会把 URL 从中间截断。
      const raw =
          '{\n'
          '  // 配置中心\n'
          '  "spider": "https://example.com/api.php", // 备用\n'
          '  "wallpaper": "http://cdn.example.com/a.jpg"\n'
          '}';
      final result = ConfigDecoder.decode(utf8.encode(raw));
      expect(result.isOk, isTrue);
      final decoded =
          jsonDecode(result.valueOrNull!.json) as Map<String, Object?>;
      expect(decoded['spider'], 'https://example.com/api.php');
      expect(decoded['wallpaper'], 'http://cdn.example.com/a.jpg');
    });

    test('////////// 分隔线整行被剔除', () {
      const raw =
          '{\n'
          '  //////////////////////////////\n'
          '  // 分隔线上面和下面都是注释\n'
          '  "sites": []\n'
          '}';
      final result = ConfigDecoder.decode(utf8.encode(raw));
      expect(result.isOk, isTrue);
      expect(jsonDecode(result.valueOrNull!.json), {'sites': <Object?>[]});
    });

    test('/* */ 块注释被剔除', () {
      const raw =
          '{\n'
          '  /* 多行\n'
          '     块注释 */\n'
          '  "sites": []\n'
          '}';
      final result = ConfigDecoder.decode(utf8.encode(raw));
      expect(result.isOk, isTrue);
      expect(jsonDecode(result.valueOrNull!.json), {'sites': <Object?>[]});
    });

    test('字符串内的裸换行/制表符被转义', () {
      // Dart 的 '\n' 就是真实换行，JSON 规范不允许字符串里出现未转义的控制字符。
      const raw = '{"name": "第一行\n第二行\t结束"}';
      final result = ConfigDecoder.decode(utf8.encode(raw));
      expect(result.isOk, isTrue);
      expect(jsonDecode(result.valueOrNull!.json), {
        'name': '第一行\n第二行\t结束',
      });
    });

    test('字符串里的转义引号不会让扫描器误判字符串结束', () {
      // 值里先有一个 \"，后面跟 //。若扫描器没跟踪转义状态，会把 // 当注释。
      const raw = r'{"a": "he said \"//\" ok", "b": 1}';
      final result = ConfigDecoder.decode(utf8.encode(raw));
      expect(result.isOk, isTrue);
      expect(jsonDecode(result.valueOrNull!.json), {
        'a': 'he said "//" ok',
        'b': 1,
      });
    });

    test('开头的 BOM 被去掉', () {
      const raw = '\uFEFF{"sites": []}';
      final result = ConfigDecoder.decode(utf8.encode(raw));
      expect(result.isOk, isTrue);
      expect(jsonDecode(result.valueOrNull!.json), {'sites': <Object?>[]});
    });

    test('解码结果是不含注释的干净 JSON（下游解析不再二次失败）', () {
      const raw =
          '{\n'
          '  // 注释\n'
          '  "sites": [{"key": "a"}]\n'
          '}';
      final result = ConfigDecoder.decode(utf8.encode(raw));
      expect(result.isOk, isTrue);
      final text = result.valueOrNull!.json;
      expect(text, isNot(contains('注释')));
      // 能被再次独立解析，说明交给 ConfigParser 也不会出问题。
      expect(() => jsonDecode(text), returnsNormally);
    });

    test('剔除注释后仍保留原行数（报错行号不错位）', () {
      const raw = '{\n// 一\n// 二\n"sites": []\n}';
      final cleaned = ConfigDecoder.sanitizeJsonText(raw);
      expect('\n'.allMatches(cleaned).length, '\n'.allMatches(raw).length);
    });

    test('Base64 编码的 JSONC 也能解码', () {
      const raw = '{\n// 注释\n"sites": []\n}';
      final encoded = utf8.encode(base64Encode(utf8.encode(raw)));
      final result = ConfigDecoder.decode(encoded);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.format, 'base64');
      expect(jsonDecode(result.valueOrNull!.json), {'sites': <Object?>[]});
    });

    test('AES 加密的 JSONC 也能解码', () {
      const key = '0123456789abcdef';
      const raw = '{\n// 注释\n"sites": []\n}';
      final aes = enc.AES(enc.Key.fromUtf8(key), mode: enc.AESMode.ecb);
      final encrypted = aes.encrypt(utf8.encode(raw));
      final result = ConfigDecoder.decode(encrypted.bytes, aesKey: key);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.format, 'aes');
      expect(jsonDecode(result.valueOrNull!.json), {'sites': <Object?>[]});
    });

    test('注释不影响 HTML 探测：网页仍报 CONFIG_NOT_JSON', () {
      // 网页里也有 //，整理后依然不是 JSON，不能因为「宽容」就误判成功。
      const html = '<!DOCTYPE html><html><body>// 注释</body></html>';
      final result = ConfigDecoder.decodeWithProbe(utf8.encode(html));
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.configNotJson);
    });

    test('sanitizeJsonText 对普通 JSON 是无操作', () {
      expect(ConfigDecoder.sanitizeJsonText(configJson), configJson);
    });
  });
}
