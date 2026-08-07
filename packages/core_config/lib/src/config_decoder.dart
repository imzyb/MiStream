/// TVBox 配置解码链：明文 JSON → Base64 → AES 加密体。
///
/// 依次尝试三条解码路径，见 `docs/05-Spider引擎.md` §5.1。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// 解码结果。
class DecodeResult {
  /// 解码后的 JSON 文本。
  final String json;

  /// 使用的解码格式。
  final String format;

  /// 构造解码结果。
  const DecodeResult({required this.json, required this.format});
}

/// TVBox 配置解码器。
///
/// 解码顺序：明文 JSON → Base64 → AES-128-ECB。
/// 调用方可通过 [decode] 一次性尝试全部路径，或各自调用具体方法。
class ConfigDecoder {
  /// 尝试全部解码路径，返回第一个成功的结果。
  ///
  /// [raw] 原始字节，[aesKey] AES 密钥（可选，16/24/32 字节）。
  static Result<DecodeResult, AppError> decode(
    List<int> raw, {
    String? aesKey,
  }) {
    // 1. 明文 JSON
    final plain = _tryPlain(raw);
    if (plain != null) return Ok(plain);

    // 2. Base64
    final b64 = _tryBase64(raw);
    if (b64 != null) return Ok(b64);

    // 3. AES
    if (aesKey != null) {
      final aes = _tryAes(raw, aesKey);
      if (aes != null) return Ok(aes);
    }

    return Err(
      LocalError(
        code: ErrorCode.configDecodeFailed,
        message: '明文/Base64/AES 三条解码路径全部失败',
      ),
    );
  }

  /// 尝试明文 JSON 解码。
  static DecodeResult? _tryPlain(List<int> raw) {
    final text = utf8.decode(raw, allowMalformed: true);
    try {
      jsonDecode(text);
      return DecodeResult(json: text, format: 'plain');
    } on FormatException {
      return null;
    }
  }

  /// 尝试 Base64 解码。
  static DecodeResult? _tryBase64(List<int> raw) {
    final text = utf8.decode(raw, allowMalformed: true).trim();
    try {
      final decoded = base64Decode(text);
      final jsonText = utf8.decode(decoded, allowMalformed: true);
      jsonDecode(jsonText);
      return DecodeResult(json: jsonText, format: 'base64');
    } on FormatException {
      return null;
    }
  }

  /// 尝试 AES-128-ECB 解密。
  static DecodeResult? _tryAes(List<int> raw, String keyStr) {
    try {
      final key = enc.Key.fromUtf8(keyStr);
      final aes = enc.AES(key, mode: enc.AESMode.ecb);
      final decrypted = aes.decrypt(enc.Encrypted(Uint8List.fromList(raw)));
      final text = utf8.decode(decrypted, allowMalformed: true);
      jsonDecode(text);
      return DecodeResult(json: text, format: 'aes');
    } on Object {
      return null;
    }
  }
}
