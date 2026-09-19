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
  /// 构造解码结果。
  const DecodeResult({required this.json, required this.format});

  /// 解码后的 JSON 文本。
  final String json;

  /// 使用的解码格式。
  final String format;
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

    return const Err(
      LocalError(
        code: ErrorCode.configDecodeFailed,
        message: '明文/Base64/AES 三条解码路径全部失败',
      ),
    );
  }

  /// 解码并对非 JSON 内容做类型探测，返回针对性错误。
  ///
  /// 与 [decode] 的区别：三条解码路径都失败后，不再笼统报「解码失败」，
  /// 而是探测原始字节，区分为「返回的是网页（HTML）」或「返回的是图片
  /// （JPEG/PNG/GIF/BMP）」，让用户在导入一个反爬/导航页地址时能立刻
  /// 明白原因，而不是困惑于一句「失败」。
  ///
  /// 返回值语义与 [decode] 一致；类型探测失败时仍回退 `configDecodeFailed`
  /// 作为兜底，不新增错误码。
  static Result<DecodeResult, AppError> decodeWithProbe(
    List<int> raw, {
    String? aesKey,
  }) {
    final result = decode(raw, aesKey: aesKey);
    if (result.isOk) return result;

    final kind = _probeNonJson(raw);
    if (kind != null) {
      return Err(
        LocalError(
          code: ErrorCode.configNotJson,
          message: '返回的是$kind，不是 TVBox JSON 配置；请确认接口地址',
        ),
      );
    }
    return result;
  }

  /// 探测原始字节是不是「不是 JSON」的内容（网页 / 图片等）。
  ///
  /// 用来在解码全失败后给出更可读的错误：比如某些源的接口地址实际上
  /// 是导航页，或对非客户端 UA 返回占位图（见 [ErrorCode.configNotJson]）。
  /// 认不出来返回 `null`，调用方仍用笼统的 `configDecodeFailed`。
  ///
  /// 返回值为内容类别文案（供 message 拼接），或 `null` 表示不明。
  static String? _probeNonJson(List<int> raw) {
    if (raw.isEmpty) return null;

    // 图片：JPEG（FFD8）、PNG（89504E47）、GIF（474946）、BMP（424D）。
    if (raw.length >= 2 && raw[0] == 0xFF && raw[1] == 0xD8) {
      return '图片（JPEG）';
    }
    if (raw.length >= 4 &&
        raw[0] == 0x89 &&
        raw[1] == 0x50 &&
        raw[2] == 0x4E &&
        raw[3] == 0x47) {
      return '图片（PNG）';
    }
    if (raw.length >= 3 && raw[0] == 0x47 && raw[1] == 0x49 && raw[2] == 0x46) {
      return '图片（GIF）';
    }
    if (raw.length >= 2 && raw[0] == 0x42 && raw[1] == 0x4D) {
      return '图片（BMP）';
    }

    // HTML：大小写不敏感地找 <!DOCTYPE 或 <html。
    final head = utf8.decode(raw.take(512).toList(), allowMalformed: true);
    final lower = head.toLowerCase();
    if (lower.contains('<!doctype') || lower.contains('<html')) {
      return '网页（HTML）';
    }

    return null;
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
