import 'package:text_codec/text_codec.dart';
import 'package:test/test.dart';

/// `央视频道` 的 GBK 字节（CPython `gbk` codec 生成，不是手算的）。
const _gbkCctv = [0xD1, 0xEB, 0xCA, 0xD3, 0xC6, 0xB5, 0xB5, 0xC0];

/// `湖南卫视` 的 UTF-8 字节。
const _utf8Hunan = [
  0xE6,
  0xB9,
  0x96,
  0xE5,
  0x8D,
  0x97,
  0xE5,
  0x8D,
  0xAB,
  0xE8,
  0xA7,
  0x86,
];

void main() {
  group('charsetFromContentType', () {
    test('认 GBK 系（gbk / gb2312 / gb18030 / 带引号）', () {
      expect(
        charsetFromContentType('text/plain; charset=gbk'),
        TextCharset.gbk,
      );
      expect(
        charsetFromContentType('text/html; charset=GB2312'),
        TextCharset.gbk,
      );
      expect(
        charsetFromContentType('text/html; charset="gb18030"'),
        TextCharset.gbk,
      );
    });

    test('认 UTF-8 的两种写法', () {
      expect(
        charsetFromContentType('application/json; charset=utf-8'),
        TextCharset.utf8,
      );
      expect(
        charsetFromContentType('text/plain; charset=UTF8'),
        TextCharset.utf8,
      );
    });

    test('latin1 / iso-8859-1 刻意不认（国内源站写这个值时多半是 GBK）', () {
      expect(
        charsetFromContentType('text/html; charset=iso-8859-1'),
        isNull,
      );
      expect(charsetFromContentType('text/html; charset=latin1'), isNull);
    });

    test('没给或给不出来时返回 null（交给嗅探）', () {
      expect(charsetFromContentType(null), isNull);
      expect(charsetFromContentType(''), isNull);
      expect(charsetFromContentType('text/plain'), isNull);
    });
  });

  group('decodeText', () {
    test('ASCII 透传', () {
      expect(decodeText('CCTV1'.codeUnits), 'CCTV1');
    });

    test('UTF-8 中文正常解', () {
      expect(decodeText(_utf8Hunan), '湖南卫视');
    });

    test('没有 charset 时按内容嗅探出 GBK', () {
      // 关键：UTF-8 严格解会抛异常，从而退回 GBK。用 allowMalformed 的话
      // 这里会得到一串 U+FFFD，而且不抛异常，就没有任何信号可以判。
      expect(decodeText(_gbkCctv), '央视频道');
    });

    test('响应头明说 GBK 就按 GBK 解', () {
      expect(decodeText(_gbkCctv, charset: TextCharset.gbk), '央视频道');
    });

    test('响应头明说 UTF-8 但内容其实是 GBK 时，仍能靠严格解失败救回来', () {
      expect(decodeText(_gbkCctv, charset: TextCharset.utf8), '央视频道');
    });

    test('剥掉 UTF-8 BOM', () {
      // ⚠️ 这两条测的不是同一件事：
      //  - utf8 路径上 Dart 的 `Utf8Decoder` **自己就会跳过 BOM**（实测），
      //    所以这条即便不显式剥也过；
      //  - GBK 路径上码表不认识 BOM，不先剥掉就会把 `EF BB` / `BF xx` 当成
      //    两个汉字。**只有这条能盯住显式剥 BOM 那一步**。
      expect(decodeText([0xEF, 0xBB, 0xBF, ..._utf8Hunan]), '湖南卫视');
      expect(
        decodeText([0xEF, 0xBB, 0xBF, ..._gbkCctv], charset: TextCharset.gbk),
        '央视频道',
      );
    });

    test('空字节返回空串', () {
      expect(decodeText(const []), '');
      expect(decodeText(const [0xEF, 0xBB, 0xBF]), '');
    });

    test('坏字节不抛异常，退化成 U+FFFD', () {
      // GBK 首字节后面跟了非法尾字节 —— 解码器只标坏这一个字符，不越位。
      expect(decodeText(const [0xD1]), '\uFFFD');
    });
  });
}
