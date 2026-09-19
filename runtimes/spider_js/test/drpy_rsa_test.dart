/// drpy `rsaX` 宿主 API 测试。
///
/// 重点验证三件事：
/// 1. **自洽性** —— 公钥加密 / 私钥解密能还原原文，三种 padding 都要过；
/// 2. **分组** —— 输入超过一个块长时能正确分块，且逐块结果能拼回原文；
/// 3. **失败语义** —— 对齐参考实现：不抛异常，返回空串并给出原因。
///
/// 测试用密钥是**代码里现生成**的 1024 位密钥（见 `setUpAll`），不是硬编码的
/// PEM。这样既避免在仓库里塞不可读的长字符串，也顺带验证了 `_parsePublicKey`
/// / `_parsePrivateKey` 在真实 DER 上的解析路径。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:spider_js/src/drpy/rsa.dart';
import 'package:test/test.dart';

/// 固定种子，保证密钥生成可复现（测试失败时好复现）。
pc.FortunaRandom _seededRandom() {
  final r = pc.FortunaRandom();
  r.seed(
    pc.KeyParameter(
      Uint8List.fromList(
        List<int>.generate(32, (i) => (i * 7 + 13) & 0xFF),
      ),
    ),
  );
  return r;
}

/// 把 pointycastle 生成的密钥编码成 PEM，喂给被测代码。
///
/// 只做「密钥 -> PEM」这一层，不碰被测代码里的解析逻辑——两边分开写才能
/// 互相校验，用同一份编码器会掩盖两侧对称的错误。
String _toPem(pc.RSAAsymmetricKey key, {required bool isPublic}) {
  final seq = ASN1Sequence();

  if (isPublic) {
    // SubjectPublicKeyInfo：
    //   SEQUENCE { AlgorithmIdentifier, BIT STRING { RSAPublicKey } }
    final inner = ASN1Sequence()
      ..add(ASN1Integer(key.modulus!))
      ..add(ASN1Integer(key.exponent!));

    final algId = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'))
      ..add(ASN1Null());

    seq
      ..add(algId)
      ..add(ASN1BitString(inner.encodedBytes));
  } else {
    final priv = key as pc.RSAPrivateKey;
    // PKCS#1 RSAPrivateKey（9 个 INTEGER）
    seq
      ..add(ASN1Integer(BigInt.zero))
      ..add(ASN1Integer(priv.modulus!))
      ..add(ASN1Integer(priv.publicExponent!))
      ..add(ASN1Integer(priv.privateExponent!))
      ..add(ASN1Integer(priv.p!))
      ..add(ASN1Integer(priv.q!))
      ..add(ASN1Integer(priv.privateExponent! % (priv.p! - BigInt.one)))
      ..add(ASN1Integer(priv.privateExponent! % (priv.q! - BigInt.one)))
      ..add(ASN1Integer(priv.q!.modInverse(priv.p!)));
  }

  final b64 = base64Encode(seq.encodedBytes);
  final body = <String>[];
  for (var i = 0; i < b64.length; i += 64) {
    body.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
  }

  final header = isPublic ? 'PUBLIC KEY' : 'RSA PRIVATE KEY';
  return '-----BEGIN $header-----\n${body.join('\n')}\n-----END $header-----';
}

void main() {
  late String pubPem;
  late String privPem;
  late int modulusBytes;

  setUpAll(() {
    final gen = pc.RSAKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64),
          _seededRandom(),
        ),
      );
    final pair = gen.generateKeyPair();
    final pub = pair.publicKey as pc.RSAPublicKey;
    final priv = pair.privateKey as pc.RSAPrivateKey;

    pubPem = _toPem(pub, isPublic: true);
    privPem = _toPem(priv, isPublic: false);
    modulusBytes = (pub.modulus!.bitLength + 7) ~/ 8;
  });

  group('PEM 解析', () {
    test('能解析公钥', () {
      final r = rsaDecode(
        mode: RsaMode.pkcs1,
        pub: true,
        encrypt: true,
        input: 'hi',
        inBase64: false,
        key: pubPem,
        outBase64: true,
      );
      expect(r.ok, isTrue, reason: r.error ?? '');
    });

    test('能解析私钥', () {
      final r = rsaDecode(
        mode: RsaMode.pkcs1,
        pub: false,
        encrypt: false,
        input: 'YWJj',
        inBase64: true,
        key: privPem,
        outBase64: false,
      );
      // 这里只要求「密钥解析成功」——输入本身不是合法密文，分组运算失败是
      // 预期内的，但报错不该是密钥解析失败。
      expect(r.error ?? '', isNot(contains('密钥解析失败')));
    });

    test('非法 PEM 返回密钥解析失败', () {
      final r = rsaDecode(
        mode: RsaMode.pkcs1,
        pub: true,
        encrypt: true,
        input: 'hi',
        inBase64: false,
        key: 'not a pem',
        outBase64: false,
      );
      expect(r.ok, isFalse);
      expect(r.text, '');
      expect(r.error, contains('密钥解析失败'));
    });
  });

  group('PKCS#1 v1.5 往返', () {
    test('公钥加密 -> 私钥解密还原', () {
      const plain = 'hello rsa';
      final enc = rsa(
        mode: RsaMode.pkcs1,
        pub: true,
        encrypt: true,
        input: plain,
        key: pubPem,
        outBase64: true,
      );
      expect(enc, isNotEmpty);

      final dec = rsa(
        mode: RsaMode.pkcs1,
        pub: false,
        encrypt: false,
        input: enc,
        inBase64: true,
        key: privPem,
      );
      expect(dec, plain);
    });

    test('加密结果长度等于模长', () {
      final enc = rsa(
        mode: RsaMode.pkcs1,
        pub: true,
        encrypt: true,
        input: 'x',
        key: pubPem,
        outBase64: true,
      );
      expect(base64Decode(enc).length, modulusBytes);
    });

    test('超过单块的输入会分块处理', () {
      // PKCS#1 单块上限是 modulusBytes - 11；给 3 倍量，强制走多轮。
      final plain = 'A' * ((modulusBytes - 11) * 3 - 10);
      final enc = rsa(
        mode: RsaMode.pkcs1,
        pub: true,
        encrypt: true,
        input: plain,
        key: pubPem,
        outBase64: true,
      );
      expect(enc, isNotEmpty);
      expect(base64Decode(enc).length, modulusBytes * 3);

      final dec = rsa(
        mode: RsaMode.pkcs1,
        pub: false,
        encrypt: false,
        input: enc,
        inBase64: true,
        key: privPem,
      );
      expect(dec, plain);
    });
  });

  group('OAEP 往返', () {
    test('公钥加密 -> 私钥解密还原（默认 SHA-1）', () {
      const plain = 'oaep payload';
      final enc = rsa(
        mode: RsaMode.oaep,
        pub: true,
        encrypt: true,
        input: plain,
        key: pubPem,
        outBase64: true,
      );
      expect(enc, isNotEmpty);

      final dec = rsa(
        mode: RsaMode.oaep,
        pub: false,
        encrypt: false,
        input: enc,
        inBase64: true,
        key: privPem,
      );
      expect(dec, plain);
    });

    test('OAEP 与 PKCS1 密文互不兼容', () {
      final encPkcs1 = rsa(
        mode: RsaMode.pkcs1,
        pub: true,
        encrypt: true,
        input: 'x',
        key: pubPem,
        outBase64: true,
      );
      final dec = rsa(
        mode: RsaMode.oaep,
        pub: false,
        encrypt: false,
        input: encPkcs1,
        inBase64: true,
        key: privPem,
      );
      expect(dec, isEmpty);
    });
  });

  group('NoPadding', () {
    test('短输入左侧补零后能往返', () {
      // NoPadding 要求输入自行补齐到模长，且首字节必须小于 0x80
      // （RSA 运算按无符号整数解释，高位为 1 会被当成负数）。
      final block = Uint8List(modulusBytes);
      const plain = 'np';
      block.setRange(
        modulusBytes - plain.length,
        modulusBytes,
        utf8.encode(plain),
      );

      final enc = rsa(
        mode: RsaMode.noPadding,
        pub: true,
        encrypt: true,
        input: base64Encode(block),
        inBase64: true,
        key: pubPem,
        outBase64: true,
      );
      expect(enc, isNotEmpty);

      final dec = rsa(
        mode: RsaMode.noPadding,
        pub: false,
        encrypt: false,
        input: enc,
        inBase64: true,
        key: privPem,
        outBase64: true,
      );
      expect(dec, isNotEmpty);

      // NoPadding 解出来带前导零，尾部应还原出原文。
      final raw = base64Decode(dec);
      expect(raw.length, modulusBytes);
      expect(utf8.decode(raw.sublist(modulusBytes - plain.length)), plain);
    });
  });

  group('失败语义', () {
    test('不支持的 mode 返回原因', () {
      final r = rsaDecode(
        mode: 'RSA/Foo/Bar',
        pub: true,
        encrypt: true,
        input: 'x',
        inBase64: false,
        key: pubPem,
        outBase64: false,
      );
      expect(r.ok, isFalse);
      expect(r.text, '');
      expect(r.error, contains('不支持的 mode'));
    });

    test('inBase64 为 true 但输入不是 base64 时报错', () {
      final r = rsaDecode(
        mode: RsaMode.pkcs1,
        pub: true,
        encrypt: true,
        input: '!!!not base64!!!',
        inBase64: true,
        key: pubPem,
        outBase64: false,
      );
      expect(r.ok, isFalse);
      expect(r.error, contains('base64'));
    });

    test('用公钥解密会失败但不抛异常', () {
      final r = rsaDecode(
        mode: RsaMode.pkcs1,
        pub: true,
        encrypt: false,
        input: base64Encode(List.filled(modulusBytes, 1)),
        inBase64: true,
        key: pubPem,
        outBase64: false,
      );
      expect(r.ok, isFalse);
      expect(r.text, '');
    });

    test('rsa() 失败时返回空串而非抛异常', () {
      expect(
        rsa(
          mode: RsaMode.pkcs1,
          pub: true,
          encrypt: true,
          input: 'x',
          key: 'garbage',
        ),
        '',
      );
    });
  });

  group('RsaResult', () {
    test('ok 与 toString', () {
      expect(const RsaResult('abc', null).ok, isTrue);
      expect(const RsaResult('', 'boom').ok, isFalse);
      expect(const RsaResult('abc', null).toString(), contains('abc'));
      expect(const RsaResult('', 'boom').toString(), contains('boom'));
    });
  });
}
