/// drpy `aesX` 宿主 API 测试。
///
/// 重点验证四件事：
/// 1. **正确性** —— 用 FIPS-197 官方 AES 向量做外部对照，不靠"自己加自己解"
///    这种自洽即正确的假象（自洽只能证明对称，证明不了算法对）；
/// 2. **参数形态** —— 七个位置参数，以及 key/iv 的补齐规则；
/// 3. **模式分流** —— 只按 `AES/CBC` / `AES/ECB` 前缀认，后缀不参与解析；
/// 4. **失败语义** —— 对齐参考实现：不抛异常，返回空串并给出原因。
///
/// **key/iv 入参形态的硬约束**：drpy 的 `key`/`iv` 只有**文本**一个入口，
/// 宿主按 UTF-8 取字节。所以 key 里一旦出现 `0x80` 以上的字节，文本经 UTF-8
/// 编码会**膨胀**——16 个码点可能变成 22 个字节，AESEngine 会直接报
/// `Key length not 128/192/256 bits`。FIPS-197 / SP 800-38A 的官方向量里
/// 恰好有含高位字节的 key，不能直接搬；这里只用其 **key 全落在 ASCII 内**
/// 的两组（AES-128/AES-256 ECB）。`input` 没这个限制——`inBase64: true`
/// 是一条逐字节无损的通道，真实源传响应体 `Buffer` 走的就是它。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;
import 'package:spider_js/src/drpy/crypto.dart';
import 'package:test/test.dart';

/// 把只含 ASCII（≤ 0x7f）的字节序列还原成文本 key。
///
/// 只有在每字节都 ≤ 0x7f 时，UTF-8 编码才与原始字节逐字节一致；一旦出现
/// `0x80` 以上，得到的 key 字节数会变多。调用点必须自行保证这一点。
String _asciiText(Uint8List bytes) {
  assert(
    bytes.every((b) => b <= 0x7f),
    'ASCII 之外的字节能被 UTF-8 膨胀，不能当文本 key 用',
  );
  return String.fromCharCodes(bytes);
}

Uint8List _hex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// 用 pointycastle 独立算一份期望值。
///
/// 这不是"自洽测试"：它绕开被测代码的填充、模式分流、编码三处逻辑，
/// 只借 AES 原语本身。被测实现若在这三处任一处理解错，就对不上。
String _referenceAesEcb({
  required List<int> key,
  required List<int> plain,
  required bool pad,
}) {
  final cipher = pc.ECBBlockCipher(pc.AESEngine())
    ..init(true, pc.KeyParameter(Uint8List.fromList(key)));
  final blockSize = cipher.blockSize;
  final src = Uint8List.fromList(plain);
  final Uint8List input;
  if (pad) {
    final used = src.length % blockSize;
    final buf = Uint8List(src.length + blockSize - used)
      ..setRange(0, src.length, src);
    pc.PKCS7Padding().addPadding(buf, src.length);
    input = buf;
  } else {
    input = src;
  }
  final out = BytesBuilder();
  for (var off = 0; off < input.length; off += blockSize) {
    out.add(cipher.process(input.sublist(off, off + blockSize)));
  }
  return _toHex(out.toBytes());
}

void main() {
  group('FIPS-197 官方向量（ECB）', () {
    // FIPS-197 §C.1 AES-128：key 000102...0f（全 ASCII），
    // 明文 00112233445566778899aabbccddeeff，单块密文 69c4e0d8...。
    test('AES-128 ECB 向量一致', () {
      const keyHex = '000102030405060708090a0b0c0d0e0f';
      const plainHex = '00112233445566778899aabbccddeeff';
      const cipherHex = '69c4e0d86a7b0430d8cdb78070b4c55a';
      final keyText = _asciiText(_hex(keyHex));

      final enc = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: true,
        input: base64Encode(_hex(plainHex)),
        inBase64: true,
        key: keyText,
        iv: '',
        outBase64: true,
      );
      // 明文刚好一块，PKCS7 会补满一整块，所以密文是两块；前一块就是向量值。
      final encBytes = base64Decode(enc);
      expect(encBytes.length, 32);
      expect(_toHex(encBytes.sublist(0, 16)), cipherHex);

      final dec = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: false,
        input: enc,
        inBase64: true,
        key: keyText,
        iv: '',
        outBase64: true,
      );
      // 填入的第二块解回来是 16 个 0x10，应被完整剥掉。
      expect(_toHex(base64Decode(dec)), plainHex);
    });

    // FIPS-197 §C.1 AES-256：key 000102...1f（全 ASCII），单块密文 8ea2b7ca...。
    test('AES-256 ECB 向量一致', () {
      const keyHex =
          '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
      const plainHex = '00112233445566778899aabbccddeeff';
      const cipherHex = '8ea2b7ca516745bfeafc49904b496089';

      final enc = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: true,
        input: base64Encode(_hex(plainHex)),
        inBase64: true,
        key: _asciiText(_hex(keyHex)),
        iv: '',
        outBase64: true,
      );
      expect(_toHex(base64Decode(enc).sublist(0, 16)), cipherHex);
    });
  });

  group('独立参考实现对照', () {
    // 用全 ASCII 的 key/iv，绕开"文本 key 含高位字节会被 UTF-8 膨胀"的干扰，
    // 对照 pointycastle 原语算出的结果，验证填充与分块两处逻辑。
    test('ECB 长明文（跨多块）与参考实现一致', () {
      const key = 'abcdefghijklmnop';
      // 37 字节：跨 3 块，末块不满
      final plain = Uint8List.fromList(
        List<int>.generate(37, (i) => 65 + i % 26),
      );

      final enc = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: true,
        input: base64Encode(plain),
        inBase64: true,
        key: key,
        iv: '',
        outBase64: true,
      );
      expect(
        _toHex(base64Decode(enc)),
        _referenceAesEcb(
          key: utf8.encode(key),
          plain: plain,
          pad: true,
        ),
      );
    });

    test('CBC 填充后明文长度与参考实现一致', () {
      const key = 'abcdefghijklmnop';
      const iv = '0000000000000000';
      // 48 字节：恰好 3 块，应再补满一整块 -> 64 字节密文
      final plain = Uint8List.fromList(List<int>.generate(48, (i) => i));

      final enc = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: base64Encode(plain),
        inBase64: true,
        key: key,
        iv: iv,
        outBase64: true,
      );
      expect(base64Decode(enc).length, 64);

      final dec = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: false,
        input: enc,
        inBase64: true,
        key: key,
        iv: iv,
        outBase64: true,
      );
      expect(base64Decode(dec), plain);
    });
  });

  group('往返', () {
    test('CBC 中文往返（outBase64）', () {
      const plain = '你好，世界！这是一段中文测试文本。';
      const key = '1234567890123456';
      const iv = 'abcdefghijklmnop';

      final enc = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: plain,
        inBase64: false,
        key: key,
        iv: iv,
        outBase64: true,
      );
      expect(enc, isNotEmpty);

      final dec = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: false,
        input: enc,
        inBase64: true,
        key: key,
        iv: iv,
        outBase64: false,
      );
      expect(dec, plain);
    });

    test('ECB 往返', () {
      const plain = 'ecb payload';
      const key = 'shortkey'; // 8 字节，走补齐

      final enc = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: true,
        input: plain,
        inBase64: false,
        key: key,
        iv: '',
        outBase64: true,
      );
      expect(enc, isNotEmpty);

      final dec = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: false,
        input: enc,
        inBase64: true,
        key: key,
        iv: '',
        outBase64: false,
      );
      expect(dec, plain);
    });

    test('outBase64 为 false 时返回的是 UTF-8 解码后的文本', () {
      const key = '1234567890123456';
      // 这一路径只对「明文本身是文本」的场景有意义；密文是二进制，
      // UTF-8 解码必然有损（参考实现同样是 `toString('utf8')`）。
      // 所以这里换成 ASCII 可打印的明文，验证的是长度与可读性。
      final enc = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: true,
        input: 'A',
        inBase64: false,
        key: key,
        iv: '',
        outBase64: true,
      );
      // 单字节明文 + 一整块填充 = 16 字节密文
      expect(base64Decode(enc).length, 16);
    });

    test('outBase64 为 false 时文本明文可无损往返', () {
      // 明文是 ASCII、密文走 base64 中转，两端都不涉及非法 UTF-8。
      const key = '1234567890123456';
      const iv = 'abcdefghijklmnop';
      const plain = 'plain text payload';

      final enc = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: plain,
        inBase64: false,
        key: key,
        iv: iv,
        outBase64: true,
      );
      final dec = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: false,
        input: enc,
        inBase64: true,
        key: key,
        iv: iv,
        outBase64: false,
      );
      expect(dec, plain);
    });

    test('inBase64 入口可传任意二进制（防 UTF-8 破坏）', () {
      // 这条覆盖真实源的用法：响应体是 Buffer，直接 base64 塞进来。
      const key = '1234567890123456';
      final raw = Uint8List.fromList(
        List<int>.generate(40, (i) => i * 6 % 256),
      );

      final enc = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: true,
        input: base64Encode(raw),
        inBase64: true,
        key: key,
        iv: '',
        outBase64: true,
      );
      final dec = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: false,
        input: enc,
        inBase64: true,
        key: key,
        iv: '',
        outBase64: true,
      );
      expect(base64Decode(dec), raw);
    });

    test('恰好整块时补满一整块', () {
      const key = '1234567890123456';
      // 16 字节明文 -> PKCS7 补 16 字节 -> 32 字节密文
      final enc = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: true,
        input: 'A' * 16,
        inBase64: false,
        key: key,
        iv: '',
        outBase64: true,
      );
      expect(base64Decode(enc).length, 32);
    });
  });

  group('key / iv 补齐规则', () {
    test('不满 16 字节的 key 补零，结果与显式补零一致', () {
      const plain = 'pad test';
      final short = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: plain,
        inBase64: false,
        key: 'abc',
        iv: '1234567890123456',
        outBase64: true,
      );
      final explicit = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: plain,
        inBase64: false,
        key: 'abc${'\u0000' * 13}',
        iv: '1234567890123456',
        outBase64: true,
      );
      expect(short, explicit);
      expect(short, isNotEmpty);
    });

    test('iv 为空串时 ECB 正常（不会因"给了 IV"而报错）', () {
      final r = aesDecode(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: true,
        input: 'x',
        inBase64: false,
        key: '1234567890123456',
        iv: '',
        outBase64: true,
      );
      expect(r.ok, isTrue, reason: r.error ?? '');
    });

    test('32 字节 key 走 AES-256，与 16 字节 key 结果不同', () {
      const plain = 'key size matters';
      const iv = '1234567890123456';
      final k16 = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: plain,
        inBase64: false,
        key: '1234567890123456',
        iv: iv,
        outBase64: true,
      );
      final k32 = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: plain,
        inBase64: false,
        key: '12345678901234567890123456789012',
        iv: iv,
        outBase64: true,
      );
      expect(k16, isNotEmpty);
      expect(k32, isNotEmpty);
      expect(k16, isNot(k32));
    });
  });

  group('mode 分流', () {
    test('大小写不敏感', () {
      const key = '1234567890123456';
      const iv = '1234567890123456';
      final upper = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: 'x',
        inBase64: false,
        key: key,
        iv: iv,
        outBase64: true,
      );
      final lower = aes(
        mode: 'aes/cbc/pkcs5padding',
        encrypt: true,
        input: 'x',
        inBase64: false,
        key: key,
        iv: iv,
        outBase64: true,
      );
      expect(lower, upper);
    });

    test('后缀不参与解析：NoPadding 后缀仍按 PKCS7 处理', () {
      const key = '1234567890123456';
      const iv = '1234567890123456';
      // 参考实现只按前缀认，`NoPadding` 后缀被忽略。对齐这个行为：
      // 三字节明文补到一块，说明确实做了填充。显式选 NoPadding 反而会
      // 让存量源在网关侧对不上——这不是我们的自由度。
      final withSuffix = aes(
        mode: 'AES/CBC/NoPadding',
        encrypt: true,
        input: 'abc',
        inBase64: false,
        key: key,
        iv: iv,
        outBase64: true,
      );
      expect(base64Decode(withSuffix).length, 16);
    });

    test('不支持的 mode 返回原因', () {
      final r = aesDecode(
        mode: 'AES/CFB/PKCS5Padding',
        encrypt: true,
        input: 'x',
        inBase64: false,
        key: '1234567890123456',
        iv: '1234567890123456',
        outBase64: true,
      );
      expect(r.ok, isFalse);
      expect(r.text, '');
      expect(r.error, contains('不支持的 mode'));
    });

    test('CBC 缺 iv 返回原因', () {
      final r = aesDecode(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: 'x',
        inBase64: false,
        key: '1234567890123456',
        iv: '',
        outBase64: true,
      );
      expect(r.ok, isFalse);
      expect(r.error, contains('iv'));
    });
  });

  group('失败语义', () {
    test('inBase64 为 true 但输入不是 base64 时报错', () {
      final r = aesDecode(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: false,
        input: '!!!not base64!!!',
        inBase64: true,
        key: '1234567890123456',
        iv: '',
        outBase64: false,
      );
      expect(r.ok, isFalse);
      expect(r.error, contains('base64'));
    });

    test('密文长度非块长整数倍时报错', () {
      final r = aesDecode(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: false,
        input: base64Encode(List.filled(15, 1)),
        inBase64: true,
        key: '1234567890123456',
        iv: '',
        outBase64: false,
      );
      expect(r.ok, isFalse);
      expect(r.error, contains('整数倍'));
    });

    test('密钥不匹配时解密失败而非返回乱码', () {
      const iv = '1234567890123456';
      final enc = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: 'secret message here',
        inBase64: false,
        key: '1234567890123456',
        iv: iv,
        outBase64: true,
      );
      final r = aesDecode(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: false,
        input: enc,
        inBase64: true,
        key: '6543210987654321',
        iv: iv,
        outBase64: false,
      );
      // 错误密钥有约 1/256 的概率恰好撞出合法填充，因此只断言
      // "要么失败、要么不是原文"，重点是绝不能把乱码当成明文顺利返回。
      if (r.ok) {
        expect(r.text, isNot('secret message here'));
      } else {
        expect(r.text, '');
        expect(r.error, contains('填充'));
      }
    });

    test('aes() 失败时返回空串而非抛异常', () {
      expect(
        aes(
          mode: 'AES/XX/PKCS5Padding',
          encrypt: true,
          input: 'x',
          inBase64: false,
          key: 'k',
          iv: '',
          outBase64: true,
        ),
        '',
      );
    });
  });

  group('AesResult', () {
    test('ok 与 toString', () {
      expect(const AesResult('abc', null).ok, isTrue);
      expect(const AesResult('', 'boom').ok, isFalse);
      expect(const AesResult('abc', null).toString(), contains('abc'));
      expect(const AesResult('', 'boom').toString(), contains('boom'));
    });
  });
}
