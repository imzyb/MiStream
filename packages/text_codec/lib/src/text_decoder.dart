/// 「字节 → 文本」的编码判定与解码。
///
/// 为什么需要它：HTTP 响应体是字节，解码口径错了就全是乱码，而且**宽容模式
/// 也救不回来** —— GBK 汉字两字节都落在 `0x81`~`0xFE`，UTF-8 解码器会把它们
/// 判为非法起始字节并输出 U+FFFD。国内不少直播源与站点至今仍是 GBK。
library;

import 'dart:convert';

import 'package:text_codec/src/gbk.dart';

/// 受支持的字符集。
enum TextCharset {
  /// UTF-8（含 ASCII）。
  utf8,

  /// GBK / GB2312 / GB18030 系。
  ///
  /// GB18030 是 GBK 的超集，本包的码表覆盖到 GBK 双字节区（`0x8140`~
  /// `0xFEFE`），GB18030 的四字节扩展区不覆盖 —— 国内源站实际用到那里的
  /// 极少，遇到会输出 U+FFFD 而不是静默出错。
  gbk,
}

/// 从 HTTP `Content-Type` 里取字符集。
///
/// 只认能确定的：`gbk` / `gb2312` / `gb18030` / `gb_2312-80` 判
/// [TextCharset.gbk]，`utf-8` / `utf8` 判 [TextCharset.utf8]，其余返回
/// `null`（交给 [decodeText] 按内容猜）。
///
/// ⚠️ **刻意不认 `iso-8859-1` / `latin1`**：国内源站写这个值时十有八九
/// 实际是 GBK（历史遗留的默认值），按 latin1 解会得到一串单字节字符。返回
/// `null` 让嗅探去判，比信一个已知不可靠的声明更准。
TextCharset? charsetFromContentType(String? contentType) {
  final value = contentType?.toLowerCase() ?? '';
  if (value.isEmpty) return null;

  final match = RegExp(r'charset\s*=\s*"?([\w\-]+)"?').firstMatch(value);
  final name = match?.group(1);
  if (name == null) return null;

  if (name == 'utf-8' || name == 'utf8') return TextCharset.utf8;
  if (name.startsWith('gb')) return TextCharset.gbk;
  return null;
}

/// 把响应字节解码成文本。
///
/// 判定顺序：
/// 1. 剥掉 UTF-8 BOM（`EF BB BF`）。⚠️ **Dart 的 `utf8.decode` 自己就会
///    跳过 BOM**（实测），所以这一步对 UTF-8 路径是多余的；但它对 **GBK
///    路径不是** —— 码表不认识 BOM，不先剥掉就会把 `EF BB`、`BF xx` 当成
///    两个汉字解出乱码。别因为「utf8 已经处理了」把它删掉。
/// 2. [charset] 明确给了 GBK 就按 GBK 解。
/// 3. 其余情况**先按 UTF-8 严格解**（不用 `allowMalformed`）：严格解失败
///    说明不是 UTF-8，退回 GBK。
///
/// 之所以「严格解失败」能当判据：GBK 双字节的高字节落在 `0x81`~`0xFE`，在
/// UTF-8 里要么是非法起始字节，要么得后面恰好跟上合法的续字节 —— 连续几十
/// 个汉字都凑巧合法的概率可以忽略。反过来 UTF-8 文本也几乎不可能恰好构成
/// 合法的 GBK 双字节序列。
///
/// **永不抛异常**：兜底用宽容模式，坏字节变成 U+FFFD。源站编码错乱时给一份
/// 带替换字符的文本，比让整次导入失败有用。
String decodeText(List<int> bytes, {TextCharset? charset}) {
  var data = bytes;
  if (_hasUtf8Bom(data)) data = data.sublist(3);
  if (data.isEmpty) return '';

  if (charset == TextCharset.gbk) return gbkDecodeWithReport(data).text;

  try {
    return utf8.decode(data);
  } on FormatException {
    return gbkDecodeWithReport(data).text;
  }
}

/// 是否带 UTF-8 BOM。
///
/// 显式剥是因为 GBK 分支不认它；UTF-8 分支即便不剥也看不出差别（`utf8.decode`
/// 自己会跳过）。见 [decodeText] 第 1 条。
bool _hasUtf8Bom(List<int> bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xEF &&
    bytes[1] == 0xBB &&
    bytes[2] == 0xBF;
