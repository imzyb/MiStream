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
}
