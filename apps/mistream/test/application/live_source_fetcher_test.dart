/// 直播源拉取的**解码接线**验证。
///
/// 为什么不测整个 `LiveSourceFetcher.call`：那要起真实 HTTP 连接，而本项目
/// 的沙箱禁止本地回环（见 `docs/PROGRESS_AUDIT_2026-09-19.md` 环境限制清单）。
/// 于是把「响应头 → 字符集 → 文本」抽成 `decodeSourceBody`，这一层是纯函数，
/// 能被盯住。
///
/// 缺的正是这一层：老直播源站仍有 GBK 输出，只按 UTF-8 解会整篇乱码。
library;

import 'package:mistream/application/live_source_fetcher.dart';
import 'package:test/test.dart';

/// `央视频道` 的 GBK 字节（CPython `gbk` codec 生成）。
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
  group('decodeSourceBody', () {
    test('GBK 源站在没有 charset 时靠嗅探救回来', () {
      expect(
        decodeSourceBody(bytes: _gbkCctv, contentType: 'text/plain'),
        '央视频道',
      );
    });

    test('响应头里的 charset 优先于内容嗅探', () {
      // 用「UTF-8 字节 + 声明 gbk」这组反例：两种口径的结果不同，正好能区分
      // 「真的读了响应头」与「只是碰巧嗅探对了」。若把 charsetFromContentType
      // 摘掉，这里会解出正确的 `湖南卫视` —— 那就是没读响应头。
      expect(
        decodeSourceBody(
          bytes: _utf8Hunan,
          contentType: 'text/plain; charset=gbk',
        ),
        isNot('湖南卫视'),
        reason: '源站声明 GBK 就该按 GBK 解',
      );
    });

    test('UTF-8 源站正常解', () {
      expect(
        decodeSourceBody(
          bytes: _utf8Hunan,
          contentType: 'text/plain; charset=utf-8',
        ),
        '湖南卫视',
      );
      expect(
        decodeSourceBody(bytes: _utf8Hunan, contentType: null),
        '湖南卫视',
      );
    });

    test('剥掉 UTF-8 BOM', () {
      // 只有 GBK 那条能盯住显式剥 BOM：utf8 路径上 Dart 的 `Utf8Decoder`
      // 自己就会跳过 BOM，剥不剥看不出差别。
      expect(
        decodeSourceBody(
          bytes: [0xEF, 0xBB, 0xBF, ..._utf8Hunan],
          contentType: 'text/plain; charset=utf-8',
        ),
        '湖南卫视',
      );
      expect(
        decodeSourceBody(
          bytes: [0xEF, 0xBB, 0xBF, ..._gbkCctv],
          contentType: 'text/plain; charset=gbk',
        ),
        '央视频道',
      );
    });
  });
}
