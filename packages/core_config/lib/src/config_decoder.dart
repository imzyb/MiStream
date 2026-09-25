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

    final kind = probeNonJson(raw);
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
  ///
  /// 公开出去是因为 [ConfigFetcher] 也要用同一把尺子判断「这次响应值不值得
  /// 采信」——配置可能是 Base64/AES，所以判据只能是否定式的：**排除明显是
  /// HTML/图片的**，其余一律放行。两处各写一套判据迟早会走偏。
  static String? probeNonJson(List<int> raw) {
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

  /// 把一段文本整理成 `jsonDecode` 能接受的 JSON，失败返回 `null`。
  ///
  /// 返回的是**整理后**的文本，调用方应拿它去解析——原文本可能含注释，
  /// 直接交给 `ConfigParser` 会二次失败。
  static String? _tryParse(String text) {
    final cleaned = sanitizeJsonText(text);
    try {
      jsonDecode(cleaned);
      return cleaned;
    } on FormatException {
      return null;
    }
  }

  /// 尝试明文 JSON 解码。
  static DecodeResult? _tryPlain(List<int> raw) {
    final cleaned = _tryParse(utf8.decode(raw, allowMalformed: true));
    if (cleaned == null) return null;
    return DecodeResult(json: cleaned, format: 'plain');
  }

  /// 尝试 Base64 解码。
  static DecodeResult? _tryBase64(List<int> raw) {
    final text = utf8.decode(raw, allowMalformed: true).trim();
    try {
      final decoded = base64Decode(text);
      final cleaned = _tryParse(utf8.decode(decoded, allowMalformed: true));
      if (cleaned == null) return null;
      return DecodeResult(json: cleaned, format: 'base64');
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
      final cleaned = _tryParse(utf8.decode(decrypted, allowMalformed: true));
      if (cleaned == null) return null;
      return DecodeResult(json: cleaned, format: 'aes');
    } on Object {
      return null;
    }
  }

  /// 把「非严格 JSON」整理成 `jsonDecode` 能吃的文本。
  ///
  /// TVBox 生态里的配置普遍不是严格 JSON，两类偏差最常见：
  ///
  /// 1. **`//` 与 `/* */` 注释**。字段后面跟一行免责声明、备用地址或分隔线
  ///    是常态。实测某源的配置里有 29 行这样的注释。
  /// 2. **字符串内的裸控制字符**（未转义的换行 / 制表符）。JSON 规范不允许，
  ///    但手写配置里很常见。
  ///
  /// 两者都会让 `jsonDecode` 抛 `FormatException`，却都不代表配置本身有问题。
  /// 参考实现（tvbox-ysc-config 的 `parse_json_lenient`）同样做了这两件事，
  /// 这里对齐它的宽容度。
  ///
  /// **必须逐字符扫描，不能用正则。** JSON 字符串值里普遍含 `//`
  /// （`"http://..."`），`//[^\n]*` 这类正则会把 URL 从中间截断——把一份好
  /// 配置改成一份坏配置。实测某源的配置有 96 行字符串里带 `http://`。
  /// 扫描时跟踪「是否在字符串内」与转义状态，字符串内的内容原样保留。
  ///
  /// 注释被替换为等量的换行（而不是直接删掉），这样报错时的行号仍然对得上。
  static String sanitizeJsonText(String text) {
    // 去 BOM：有些源会在开头带上，utf8 解出来是 U+FEFF，jsonDecode 不认。
    final source = text.startsWith('\uFEFF') ? text.substring(1) : text;

    final out = StringBuffer();
    var inString = false;
    var escaped = false;

    var i = 0;
    while (i < source.length) {
      final ch = source[i];

      if (inString) {
        if (escaped) {
          out.write(ch);
          escaped = false;
          i++;
          continue;
        }
        if (ch == r'\') {
          out.write(ch);
          escaped = true;
          i++;
          continue;
        }
        if (ch == '"') {
          out.write(ch);
          inString = false;
          i++;
          continue;
        }
        // 字符串内的裸控制字符：补上转义，让 JSON 合法。
        final code = ch.codeUnitAt(0);
        if (code < 0x20) {
          switch (ch) {
            case '\n':
              out.write(r'\n');
            case '\r':
              out.write(r'\r');
            case '\t':
              out.write(r'\t');
            default:
              out.write(r'\u');
              out.write(code.toRadixString(16).padLeft(4, '0'));
          }
          i++;
          continue;
        }
        out.write(ch);
        i++;
        continue;
      }

      // 字符串外：识别注释。
      if (ch == '/' && i + 1 < source.length) {
        final next = source[i + 1];
        if (next == '/') {
          // 行注释：吞到行尾（保留换行，行号才不会错位）。
          final nl = source.indexOf('\n', i);
          if (nl < 0) break;
          i = nl;
          continue;
        }
        if (next == '*') {
          // 块注释：吞到 */，内部的换行原样保留。
          final end = source.indexOf('*/', i + 2);
          if (end < 0) break;
          for (var k = i; k < end + 2; k++) {
            if (source[k] == '\n') out.write('\n');
          }
          i = end + 2;
          continue;
        }
      }

      if (ch == '"') inString = true;
      out.write(ch);
      i++;
    }

    return out.toString();
  }
}
