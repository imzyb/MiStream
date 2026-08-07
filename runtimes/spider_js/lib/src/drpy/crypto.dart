/// drpy 宿主 API：编码与加密函数。
///
/// 对齐 `docs/05-Spider引擎.md` §2.2 的编码/加密类 API：
/// base64、urlencode、md5、sha1、sha256、aes、hmac。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;

/// Base64 编码。
String base64EncodeDrpy([List<int>? bytes]) => base64Encode(bytes ?? <int>[]);

/// Base64 解码。
Uint8List base64DecodeDrpy(String input) => base64Decode(input);

/// URL 编码。
String urlencode(String input) => Uri.encodeComponent(input);

/// URL 解码。
String urldecode(String input) => Uri.decodeComponent(input);

/// MD5 十六进制。
String md5(String input) => crypto.md5.convert(utf8.encode(input)).toString();

/// SHA1 十六进制。
String sha1(String input) => crypto.sha1.convert(utf8.encode(input)).toString();

/// SHA256 十六进制。
String sha256Drpy(String input) =>
    crypto.sha256.convert(utf8.encode(input)).toString();

/// AES 加密/解密。
///
/// [encrypt] 为 true 加密，false 解密；[key] 密钥，[iv] 初始向量（CBC 用）。
/// mode: `AES/CBC/PKCS5Padding` 或 `AES/ECB/PKCS5Padding`。
String aes({
  required bool encrypt,
  required String input,
  required String key,
  String? iv,
  String mode = 'AES/CBC/PKCS5Padding',
}) {
  final aesKey = enc.Key.fromUtf8(key);
  final aesIv = iv != null ? enc.IV.fromUtf8(iv) : null;
  final isEcb = mode.toUpperCase().contains('ECB');
  final cipher = enc.AES(
    aesKey,
    mode: isEcb ? enc.AESMode.ecb : enc.AESMode.cbc,
  );

  if (encrypt) {
    final encrypted = cipher.encrypt(
      utf8.encode(input),
      iv: aesIv,
    );
    // drpy 默认返回 base64
    return base64Encode(encrypted.bytes);
  }

  final encryptedData = enc.Encrypted(base64Decode(input));
  final decrypted = cipher.decrypt(encryptedData, iv: aesIv);
  return utf8.decode(decrypted);
}

/// HMAC-SHA256 十六进制。
String hmac256(String input, String key) {
  final hmac = crypto.Hmac(crypto.sha256, utf8.encode(key));
  return hmac.convert(utf8.encode(input)).toString();
}

/// 拼接 URL：把 [path] 基于 [baseUrl] 解析为绝对 URL。
String joinUrl(String baseUrl, String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final base = Uri.parse(baseUrl);
  return base.resolve(path).toString();
}
