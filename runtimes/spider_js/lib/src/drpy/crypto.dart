/// drpy 宿主 API：编码与加密函数。
///
/// 对齐 `docs/05-Spider引擎.md` §2.2 的编码/加密类 API：
/// base64、urlencode、md5、sha1、sha256、aes、hmac。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;

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

/// AES 加密/解密（drpy 的 `aesX`）。
///
/// 参数逐个对齐参考实现 `drpyInject.js` 的
/// `aes(mode, encrypt, input, inBase64, key, iv, outBase64)`：
///
/// - [mode] Java 风格，如 `AES/CBC/PKCS5Padding` / `AES/ECB/PKCS5Padding`。
///   参考实现只按 `AES/CBC` 与 `AES/ECB` 前缀分流，后缀（`PKCS5Padding`/`NoPadding`）
///   **不参与解析**——填充始终是 Node crypto 的默认值 PKCS7，与 AES 下的
///   PKCS5 等价。本实现照做。
/// - [encrypt] true 加密，false 解密
/// - [input] 输入；[inBase64] 为 true 时先按 base64 解码
/// - [key] 密钥，按 **UTF-8 字节**取用（不是 hex/base64），不足 16 字节零补齐
/// - [iv] 初始向量规则同上；**空串视为未提供**（让 ECB 能正常工作）
/// - [outBase64] 输出是否 base64；false 时按 UTF-8 解出字符串
///
/// **不抛异常**：任何失败返回空串，原因见 [aesDecode]。
///
/// 注意：Dart 侧用命名参数是为了可读性，**drpy 的位置契约在
/// `host_bridge.dart` 的 `'aes'` handler 与 `js_runtime.dart` 的 `g.aes`
/// 两层保证**——JS 源永远按 `aesX(mode, encrypt, input, inBase64, key, iv,
/// outBase64)` 位置调用，由那两层翻译成这里的命名实参。不要把这里的签名
/// 改成位置参数来"对齐"：那会让 Dart 调用点失去参数名，改错顺序编译器帮不上忙。
String aes({
  required String mode,
  required bool encrypt,
  required String input,
  required bool inBase64,
  required String key,
  required String iv,
  required bool outBase64,
}) => aesDecode(
  mode: mode,
  encrypt: encrypt,
  input: input,
  inBase64: inBase64,
  key: key,
  iv: iv,
  outBase64: outBase64,
).text;

/// 一次 aes 调用的结果。
///
/// 与 [RsaResult] 同构：失败时 [text] 为空串、[error] 给出原因。
/// 参考实现把异常 `log` 掉后返回空串——静默吞异常是那类实现最难排查的部分，
/// 这里保留「返回空串」的对外语义，但把原因暴露给源诊断面板。
class AesResult {
  /// 构造结果。
  const AesResult(this.text, this.error);

  /// 成功时的输出文本；失败时为空串。
  final String text;

  /// 失败原因；成功时为 null。
  final String? error;

  /// 是否成功。
  bool get ok => error == null;

  @override
  String toString() => ok ? 'AesResult($text)' : 'AesResult(error: $error)';
}

/// 同 [aes]，但把失败原因一并返回。
AesResult aesDecode({
  required String mode,
  required bool encrypt,
  required String input,
  required bool inBase64,
  required String key,
  required String iv,
  required bool outBase64,
}) {
  try {
    // 参考实现：iv 为空串时置 null，否则 ECB 模式会因「给了 IV」而报错。
    final effectiveIv = iv.isEmpty ? null : iv;
    final upper = mode.toUpperCase();
    final isEcb = upper.contains('ECB');
    final isCbc = upper.contains('CBC');
    if (!isEcb && !isCbc) {
      return AesResult('', '不支持的 mode: $mode（只认 AES/CBC 与 AES/ECB）');
    }
    if (isCbc && effectiveIv == null) {
      // Node 的 createCipheriv 对 CBC 强制要求 16 字节 IV，缺了直接抛。
      // 这里提前给出可读原因，比等到 cipher 内部报「无效参数」清楚。
      return AesResult('', 'CBC 模式需要 iv');
    }

    final keyBytes = _paddedKeyOrIv(key);
    final ivBytes = effectiveIv == null ? null : _paddedKeyOrIv(effectiveIv);

    final Uint8List inBytes;
    if (inBase64) {
      try {
        inBytes = base64Decode(input);
      } on FormatException {
        return AesResult('', 'input 不是合法的 base64');
      }
    } else {
      inBytes = Uint8List.fromList(utf8.encode(input));
    }

    // 用 CBC/ECB 模式壳 + PKCS7Padding 组合，而不用 `PaddedBlockCipherImpl`：
    // 后者自己就管填充，外面再 pad 一次会双重填充。这里填充由代码显式控制，
    // 解密时也能自己决定「填充非法」该报什么错。
    //
    // init 的参数形态两种模式**不一样**：CBC 要 `ParametersWithIV`，ECB 则把
    // `KeyParameter` 原样透传给底层 AESEngine——包一层 `ParametersWithIV` 过去
    // 会在 AESEngine 里抛类型错误。
    final pc.BlockCipher cipher;
    if (isEcb) {
      cipher = pc.ECBBlockCipher(pc.AESEngine())
        ..init(encrypt, pc.KeyParameter(keyBytes));
    } else {
      cipher = pc.CBCBlockCipher(pc.AESEngine())
        ..init(
          encrypt,
          pc.ParametersWithIV<pc.KeyParameter>(
            pc.KeyParameter(keyBytes),
            ivBytes!,
          ),
        );
    }

    final outBytes = BytesBuilder();
    final blockSize = cipher.blockSize;
    final padding = pc.PKCS7Padding();

    if (encrypt) {
      // PKCS7Padding.addPadding 是**原地**写入：offset 之前的字节是明文、
      // offset 之后的字节被填成 `块长 - offset`。所以要先备好一块足够大的
      // 缓冲区（整块明文 + 最多一整块填充），把明文拷进去，再让 addPadding
      // 从明文的真实长度处开始补。
      final used = inBytes.length % blockSize;
      final buffer = Uint8List(inBytes.length + blockSize - used);
      buffer.setRange(0, inBytes.length, inBytes);
      final padLen = padding.addPadding(buffer, inBytes.length);

      final padded = Uint8List.sublistView(buffer, 0, inBytes.length + padLen);
      for (var off = 0; off < padded.length; off += blockSize) {
        outBytes.add(cipher.process(padded.sublist(off, off + blockSize)));
      }
      return _encode(outBytes.toBytes(), outBase64);
    }

    if (inBytes.isEmpty || inBytes.length % blockSize != 0) {
      // 参考实现里 Node 会抛 `wrong final block length`，这里给可读原因。
      return AesResult('', '密文长度不是 $blockSize 的整数倍');
    }
    for (var off = 0; off < inBytes.length; off += blockSize) {
      outBytes.add(cipher.process(inBytes.sublist(off, off + blockSize)));
    }
    final raw = outBytes.toBytes();
    final int unpadded;
    try {
      // pointycastle 的 padCount 自己就会逐字节校验填充（非法即抛），
      // 所以这里不需要再手工比对一遍。
      unpadded = padding.padCount(raw);
    } on Object {
      return AesResult('', 'AES 解密失败（填充或密钥不匹配）');
    }
    return _encode(
      Uint8List.sublistView(raw, 0, raw.length - unpadded),
      outBase64,
    );
  } on Object catch (e) {
    // 对齐参考实现：失败返回空串而非抛出。
    return AesResult('', 'AES 运算失败: $e');
  }
}

/// 编码输出：`outBase64` 时给 base64，否则按 UTF-8 解出字符串。
///
/// 后者用 `allowMalformed: true`：密文不保证是合法 UTF-8，参考实现里
/// `Buffer.toString('utf8')` 对非法字节也是替换而非抛错，这里对齐。
AesResult _encode(Uint8List bytes, bool outBase64) => outBase64
    ? AesResult(base64Encode(bytes), null)
    : AesResult(utf8.decode(bytes, allowMalformed: true), null);

/// 按参考实现取 key/iv 字节：UTF-8 编码，不足 16 字节零补齐。
///
/// 参考实现用的是 `Buffer.concat([buf], 16)`——那是**追加 16 个零字节**而非
/// 「补齐到 16」。这里刻意实现成**补齐到 16**：追加 16 个零会让 16 字节的 key
/// 变成 32 字节（AES-256），与「按 key.length 选 128/256」的分支逻辑自相矛盾，
/// 那是参考实现的实现细节偏差而非有意设计。对齐意图、不对齐笔误。
Uint8List _paddedKeyOrIv(String s) {
  final bytes = Uint8List.fromList(utf8.encode(s));
  if (bytes.length >= 16) return bytes;
  final out = Uint8List(16);
  out.setRange(0, bytes.length, bytes);
  return out;
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
