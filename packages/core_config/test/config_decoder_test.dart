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
}
