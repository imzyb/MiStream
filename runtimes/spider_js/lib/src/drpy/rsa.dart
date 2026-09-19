/// drpy 宿主 API：RSA 加解密（`rsaX`）。
///
/// 对齐 `docs/05-Spider引擎.md` §2.2 的加密类 API。参考实现是 drpy 生态里
/// `drpyInject.js` 的 `rsa` 函数，签名与语义**逐参数对齐**：
///
/// ```js
/// rsaX(mode, pub, encrypt, input, inBase64, key, outBase64)
/// ```
///
/// ## 为什么参数形态这么"原始"
///
/// 这套签名不是设计出来的，是**历史兼容的结果**：TVBox 系的解析壳（catvod /
/// 海阔 / drpy）各自实现过一份同名函数，脚本按位置传参。任何"现代化"改造
/// （改成对象入参、加默认值）都会让存量源直接失效——这正是兼容层的意义所在，
/// 见 `docs/03-技术选型.md` §1。
///
/// ## 与参考实现的行为差异
///
/// 参考实现（Node.js `crypto`）在出错时 `log` 后返回空串。本实现保持
/// **不抛异常、返回空串**的语义，但把原因记录到可读的错误信息里，便于源
/// 诊断面板显示——静默吞掉异常是那类实现最难排查的部分。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart' as pc;

/// rsaX 支持的填充模式，与参考实现的 `mode` 取值一致。
abstract final class RsaMode {
  /// `RSA/PKCS1` —— PKCS#1 v1.5 填充。
  ///
  /// 最常用的一种。国内站点用它加密密码、时间戳一类的短数据。
  static const String pkcs1 = 'RSA/PKCS1';

  /// `RSA/None/NoPadding` —— 不做填充，输入需由调用方自行补齐到模长。
  ///
  /// 参考实现在该模式下会把短于块长的输入**左侧补零**到 `blockLen`，
  /// 本实现照做（见 `_leftPad`）。
  static const String noPadding = 'RSA/None/NoPadding';

  /// `RSA/None/OAEPPadding` —— OAEP 填充（SHA-1 摘要）。
  ///
  /// 注意参考实现用的是 Node 默认 OAEP 参数，即 SHA-1。这里同样用 SHA-1，
  /// 用 SHA-256 会和绝大多数站点对不上。
  static const String oaep = 'RSA/None/OAEPPadding';
}

/// 一次 rsaX 调用的结果。
///
/// [ok] 为 false 时 [text] 为空串，[error] 给出人类可读的原因。
class RsaResult {
  /// 构造结果。
  const RsaResult(this.text, this.error);

  /// 成功时的输出文本；失败时为空串。
  final String text;

  /// 失败原因；成功时为 null。
  final String? error;

  /// 是否成功。
  bool get ok => error == null;

  @override
  String toString() => ok ? 'RsaResult($text)' : 'RsaResult(error: $error)';
}

/// `rsaX(mode, pub, encrypt, input, inBase64, key, outBase64)`。
///
/// - [mode] 见 [RsaMode]，取值大小写敏感以对齐参考实现
/// - [pub] `true` 用公钥运算，`false` 用私钥运算
/// - [encrypt] `true` 加密，`false` 解密
/// - [input] 待处理数据
/// - [inBase64] [input] 是否按 base64 解码后再处理
/// - [key] PEM 格式密钥（`-----BEGIN ... KEY-----`）
/// - [outBase64] 输出是否 base64 编码
///
/// **不抛异常**：任何失败都返回空串，原因见 [rsaDecode]，供诊断使用。
String rsa({
  required String mode,
  required bool pub,
  required bool encrypt,
  required String input,
  required String key,
  bool inBase64 = false,
  bool outBase64 = false,
}) {
  return rsaDecode(
    mode: mode,
    pub: pub,
    encrypt: encrypt,
    input: input,
    inBase64: inBase64,
    key: key,
    outBase64: outBase64,
  ).text;
}

/// 同 [rsa]，但把失败原因一并返回。
RsaResult rsaDecode({
  required String mode,
  required bool pub,
  required bool encrypt,
  required String input,
  required bool inBase64,
  required String key,
  required bool outBase64,
}) {
  try {
    return _run(
      mode: mode,
      pub: pub,
      encrypt: encrypt,
      input: input,
      inBase64: inBase64,
      key: key,
      outBase64: outBase64,
    );
  } on Object catch (e) {
    // 对齐参考实现：失败返回空串而非抛出。
    return RsaResult('', 'RSA 运算失败: $e');
  }
}

RsaResult _run({
  required String mode,
  required bool pub,
  required bool encrypt,
  required String input,
  required bool inBase64,
  required String key,
  required bool outBase64,
}) {
  final keyParam = _parseKey(key, isPublic: pub);
  if (keyParam == null) {
    return RsaResult('', '密钥解析失败（PEM 格式或内容不正确）');
  }

  final modulusBits = _modulusBits(keyParam);
  if (modulusBits == 0) {
    return RsaResult('', '密钥缺少模长信息');
  }

  // 分组长度按模长算；带填充的模式要给填充预留空间，这与参考实现一致。
  final modulusBytes = modulusBits ~/ 8;
  late final pc.AsymmetricBlockCipher cipher;
  late final int blockLen;

  switch (mode) {
    case RsaMode.pkcs1:
      cipher = pc.PKCS1Encoding(pc.RSAEngine());
      // PKCS#1 v1.5 填充占 11 字节（加密时）。
      blockLen = encrypt ? modulusBytes - 11 : modulusBytes;
    case RsaMode.noPadding:
      cipher = pc.RSAEngine();
      blockLen = modulusBytes;
    case RsaMode.oaep:
      // 参考实现走 Node 默认参数，即 SHA-1 摘要。
      //
      // 不传摘要对象：`OAEPEncoding` 的 `withSHA1` 工厂已经把 SHA-1 和
      // 空的 encodingParams 固定好了，第二参数是 `Uint8List?`（MGF1 的
      // label），不是 Digest——传 Digest 会直接类型报错。
      cipher = pc.OAEPEncoding(pc.RSAEngine());
      // OAEP 填充占 42 字节（2 * hashLen + 2，SHA-1 时 hashLen=20）。
      blockLen = encrypt ? modulusBytes - 42 : modulusBytes;
    default:
      return RsaResult('', '不支持的 mode: $mode');
  }

  if (blockLen <= 0) {
    return RsaResult('', '密钥长度 $modulusBits 位不足以容纳 $mode 的填充');
  }

  final inputBytes = inBase64
      ? _tryBase64Decode(input)
      : Uint8List.fromList(utf8.encode(input));
  if (inputBytes == null) {
    return RsaResult('', 'input 不是合法的 base64');
  }

  // pointycastle 要求把密钥再包一层 `CipherParameters`：`RSAAsymmetricKey`
  // 只实现 `AsymmetricKey`，而 `RSAEngine.init` 收的是
  // `AsymmetricKeyParameter<RSAAsymmetricKey>`——公钥走 `PublicKeyParameter`，
  // 私钥走 `PrivateKeyParameter`，两者都是非抽象的具体类。
  final cipherParams = pub
      ? pc.PublicKeyParameter<pc.RSAPublicKey>(keyParam as pc.RSAPublicKey)
      : pc.PrivateKeyParameter<pc.RSAPrivateKey>(keyParam as pc.RSAPrivateKey);
  cipher.init(pub, cipherParams);

  final out = _processBlocks(
    cipher: cipher,
    input: inputBytes,
    blockLen: blockLen,
    noPadding: mode == RsaMode.noPadding,
    encrypt: encrypt,
    modulusBytes: modulusBytes,
  );
  if (out == null) {
    return RsaResult('', '$mode 分组运算失败（填充或密钥不匹配）');
  }

  if (outBase64) return RsaResult(base64Encode(out), null);
  return RsaResult(utf8.decode(out, allowMalformed: true), null);
}

/// 逐块调用 cipher，与参考实现的分组循环等价。
///
/// 两处需要手动兜住 pointycastle 与 Node `crypto` 的语义差异：
///
/// 1. **加密方向**：`NoPadding` 时要先把不足块长的尾块**左侧补零**，这是参考
///    实现里的 `Buffer.alloc(128 - len) + tmpIn`；不补的话 RSA 引擎会因输入
///    长度不符报错。
/// 2. **解密方向**：`NoPadding` 时 pointycastle 的 `RSAEngine` 返回的是**最小
///    字节表示**（`encodeBigInt` 会丢掉前导零，见 `rsa.dart:_convertOutput`），
///    而 Node 解密恒返回模长字节。不在解码侧补零的话，调用方拿到的明文长度会
///    随内容变化——源脚本按固定偏移取值时会直接错位。
Uint8List? _processBlocks({
  required pc.AsymmetricBlockCipher cipher,
  required Uint8List input,
  required int blockLen,
  required bool noPadding,
  required bool encrypt,
  required int modulusBytes,
}) {
  final out = BytesBuilder();
  var idx = 0;
  while (idx < input.length) {
    final end = (idx + blockLen) > input.length ? input.length : idx + blockLen;
    var chunk = Uint8List.sublistView(input, idx, end);
    // 第 1 点：加密方向的入口补零。
    if (noPadding && encrypt && chunk.length < blockLen) {
      chunk = _leftPad(chunk, blockLen);
    }
    try {
      final piece = cipher.process(chunk);
      // 第 2 点：解密方向的出口补零。
      out.add(noPadding && !encrypt ? _leftPad(piece, modulusBytes) : piece);
    } on Object {
      return null;
    }
    idx = end;
  }
  return out.toBytes();
}

/// 左侧补零到 [targetLen]。
Uint8List _leftPad(Uint8List data, int targetLen) {
  if (data.length >= targetLen) return data;
  final out = Uint8List(targetLen);
  out.setRange(targetLen - data.length, targetLen, data);
  return out;
}

Uint8List? _tryBase64Decode(String input) {
  try {
    return base64Decode(input);
  } on FormatException {
    return null;
  }
}

/// 取密钥模长（位）。解析不出来返回 0。
int _modulusBits(pc.RSAAsymmetricKey key) {
  final modulus = key.modulus;
  if (modulus == null || modulus == BigInt.zero) return 0;
  return modulus.bitLength;
}

/// 解析 PEM 密钥。
///
/// 支持两种常见封装：
/// - `-----BEGIN PUBLIC KEY-----` / `-----BEGIN RSA PUBLIC KEY-----`
/// - `-----BEGIN PRIVATE KEY-----` / `-----BEGIN RSA PRIVATE KEY-----`
///
/// 参考实现靠 Node `crypto.createPublicKey/createPrivateKey` 直接吃 PEM，
/// Dart 侧没有等价物，需要自己解 ASN.1。这里的处理范围刻意收窄到
/// **解析 PEM 必需的子集**：只认 RSA，不做算法推断。
pc.RSAAsymmetricKey? _parseKey(String pem, {required bool isPublic}) {
  final der = _pemToDer(pem);
  if (der == null) return null;

  try {
    if (isPublic) {
      return _parsePublicKey(der);
    }
    return _parsePrivateKey(der);
  } on Object {
    return null;
  }
}

/// 从 PEM 文本取出 DER 字节。
///
/// PEM 结构就是「头行 + base64 正文 + 尾行」，正文可能被折行，所以要去掉
/// 所有空白再解码。头行不参与校验——真实源里 `RSA PUBLIC KEY` 和
/// `PUBLIC KEY` 混用得很厉害，严格校验会误伤。
Uint8List? _pemToDer(String pem) {
  final trimmed = pem.trim();
  if (!trimmed.contains('-----BEGIN')) return null;

  final body = StringBuffer();
  for (final line in trimmed.split('\n')) {
    final l = line.trim();
    if (l.startsWith('-----')) continue;
    body.write(l);
  }
  if (body.isEmpty) return null;

  try {
    return base64Decode(body.toString());
  } on FormatException {
    return null;
  }
}

/// 解析公钥：外层是 `SubjectPublicKeyInfo`（PKCS#8 风格）。
///
/// ```text
/// SEQUENCE
///   SEQUENCE            -- AlgorithmIdentifier: OID 1.2.840.113549.1.1.1
///     OID rsaEncryption
///     NULL
///   BIT STRING          -- 内含 PKCS#1 RSAPublicKey
///     SEQUENCE
///       INTEGER modulus
///       INTEGER publicExponent
/// ```
///
/// 也兼容直接是 PKCS#1 `RSAPublicKey` 的情况（`BEGIN RSA PUBLIC KEY`）。
pc.RSAPublicKey? _parsePublicKey(Uint8List der) {
  final parser = ASN1Parser(der);
  final top = parser.nextObject();

  ASN1Sequence seq;
  if (top is ASN1Sequence && top.elements.isNotEmpty) {
    final first = top.elements.first;
    // SubjectPublicKeyInfo 的首元素是 AlgorithmIdentifier（SEQUENCE），
    // PKCS#1 RSAPublicKey 的首元素是 INTEGER 模数。靠这个区分两种封装。
    if (first is ASN1Sequence) {
      final bitString = top.elements.last;
      if (bitString is! ASN1BitString) return null;
      final inner = ASN1Parser(Uint8List.fromList(bitString.stringValue));
      final innerSeq = inner.nextObject();
      if (innerSeq is! ASN1Sequence) return null;
      seq = innerSeq;
    } else {
      seq = top;
    }
  } else {
    return null;
  }

  final elems = seq.elements;
  if (elems.length < 2) return null;
  final modulus = _asBigInt(elems[0]);
  final exponent = _asBigInt(elems[1]);
  if (modulus == null || exponent == null) return null;

  return pc.RSAPublicKey(modulus, exponent);
}

/// 解析私钥。支持 PKCS#1（`RSAPrivateKey`）与 PKCS#8（`PrivateKeyInfo`）。
///
/// PKCS#1 结构：
/// ```text
/// SEQUENCE
///   INTEGER version(0)
///   INTEGER modulus
///   INTEGER publicExponent
///   INTEGER privateExponent
///   INTEGER prime1
///   INTEGER prime2
///   INTEGER exponent1
///   INTEGER exponent2
///   INTEGER coefficient
/// ```
///
/// PKCS#8 则把上述内容包在 `OCTET STRING` 里，外面套 `AlgorithmIdentifier`。
pc.RSAPrivateKey? _parsePrivateKey(Uint8List der) {
  final parser = ASN1Parser(der);
  final top = parser.nextObject();
  if (top is! ASN1Sequence) return null;

  var seq = top;
  final first = seq.elements.isNotEmpty ? seq.elements.first : null;

  // PKCS#8：首个元素是 INTEGER version(0)，第二个是 AlgorithmIdentifier。
  // 内层真正的 RSAPrivateKey 在最后的 OCTET STRING 里。
  if (first is ASN1Integer && seq.elements.length >= 3) {
    final octet = seq.elements.last;
    if (octet is ASN1OctetString) {
      final inner = ASN1Parser(Uint8List.fromList(octet.valueBytes()));
      final innerSeq = inner.nextObject();
      if (innerSeq is ASN1Sequence) seq = innerSeq;
    }
  }

  final elems = seq.elements;
  if (elems.length < 4) return null;

  // RSAPrivateKey 的前四项是 version/modulus/publicExponent/privateExponent。
  final modulus = _asBigInt(elems[1]);
  final privateExponent = _asBigInt(elems[3]);
  if (modulus == null || privateExponent == null) return null;

  final p = elems.length > 4 ? _asBigInt(elems[4]) : null;
  final q = elems.length > 5 ? _asBigInt(elems[5]) : null;

  return pc.RSAPrivateKey(modulus, privateExponent, p, q);
}

BigInt? _asBigInt(ASN1Object obj) {
  if (obj is! ASN1Integer) return null;
  return obj.valueAsBigInteger;
}
