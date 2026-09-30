/// GBK / GB18030 解码。
///
/// 国内视频站点与老直播源大量仍在用 GBK 输出。两个消费方：
///
/// * **drpy 宿主 API `gbkDecode`** —— 脚本拿到的是**字节**，直接按 UTF-8 解
///   会得到乱码或抛 `FormatException`，这是真实源里最常见的失败点之一。
/// * **HTTP 拉取层** —— 源站响应头没给 charset 时按内容猜编码，见
///   `text_decoder.dart` 的 `decodeText`。
///
/// 所以本模块在 `packages/text_codec` 而不是 `runtimes/spider_js`：
/// 码表只该有一份，`runtimes/spider_js/lib/src/drpy/gbk.dart` 现在只是一个
/// 转出口，保住 `package:spider_js/src/drpy/gbk.dart` 这条老路径。
///
/// ## 与 `utf8.decode(allowMalformed: true)` 的区别
///
/// GBK 汉字两字节都落在 `0x81`~`0xFE` 区间，UTF-8 解码器看到它们会判为非法
/// 起始字节并输出替换字符。也就是说**宽容模式也不能救**，必须有真正的码表。
///
/// ## 容错策略
///
/// 解码器**永不抛异常**，这与 `req` 的语义一致（脚本不该因为一个坏字节丢掉
/// 整页）。无法映射的位置输出 U+FFFD，并可选地把出错字节上报给调用方。
library;

import 'dart:typed_data';

import 'package:text_codec/src/gbk_table.dart';

/// 一次解码的统计，用于判断「这页到底是不是 GBK」。
///
/// 探测场景（响应头没给 charset）需要它：解出来全是替换字符就说明猜错了编码。
class GbkDecodeReport {
  /// 构造统计结果。
  const GbkDecodeReport({
    required this.total,
    required this.mapped,
    required this.unmapped,
  });

  /// 输入字节总数。
  final int total;

  /// 成功映射的字节数。
  final int mapped;

  /// 未能映射的字节数。
  final int unmapped;

  /// 未映射字节占比，`0.0` ~ `1.0`。
  double get unmappedRatio => total == 0 ? 0 : unmapped / total;

  @override
  String toString() =>
      'GbkDecodeReport(total: $total, mapped: $mapped, unmapped: $unmapped)';
}

/// GBK 解码结果。
class GbkDecodeResult {
  /// 构造解码结果。
  const GbkDecodeResult(this.text, this.report);

  /// 解码后的字符串，未映射位置已替换为 U+FFFD。
  final String text;

  /// 解码统计。
  final GbkDecodeReport report;
}

/// 把 [bytes] 按 GBK 解码。
///
/// 单字节区 `0x00`~`0x7F` 与 ASCII 一致，直接透传；`0x80` 单独出现按
/// 未映射处理（GBK 里 `0x80` 是欧元符号的旧写法，实际源里几乎见不到，
/// 与其猜不如标出来）。首字节落在双字节区时向后取一字节组双字节码位；
/// 若尾字节非法（`0x00`~`0x3F` 或 `0x7F`）则把首字节判为未映射，并**不消费**
/// 后续字节——这样错位只会脏一个字符，不会让整页后续内容全部错位。
GbkDecodeResult gbkDecodeWithReport(List<int> bytes) {
  final buffer = StringBuffer();
  var mapped = 0;
  var unmapped = 0;

  var i = 0;
  while (i < bytes.length) {
    final b1 = bytes[i] & 0xFF;

    if (b1 < 0x80) {
      buffer.writeCharCode(b1);
      mapped++;
      i++;
      continue;
    }

    final hasTrail = i + 1 < bytes.length;
    if (b1 < gbkLeadMin || b1 > gbkLeadMax || !hasTrail) {
      buffer.write(gbkUnmapped);
      unmapped++;
      i++;
      continue;
    }

    final b2 = bytes[i + 1] & 0xFF;
    if (b2 < gbkTrailMin || b2 > gbkTrailMax || b2 == 0x7F) {
      // 尾字节非法：只判首字节坏，不越位消费，避免连锁错位。
      buffer.write(gbkUnmapped);
      unmapped++;
      i++;
      continue;
    }

    final ch = _lookup(b1, b2);
    if (ch == null) {
      buffer.write(gbkUnmapped);
      unmapped++;
    } else {
      buffer.write(ch);
      mapped += 2;
    }
    i += 2;
  }

  return GbkDecodeResult(
    buffer.toString(),
    GbkDecodeReport(total: bytes.length, mapped: mapped, unmapped: unmapped),
  );
}

/// `gbkDecode(bytes)`：只取解码后的字符串。
///
/// drpy 脚本的用法是 `gbkDecode(res.body)`（body 为字节数组）或
/// `gbkDecode(str)`（body 被上游当字符串传下来）。两种都接受。
///
/// 传进来的若已是**文本**（含超出单字节的码位），原样返回，不做任何转换——
/// 否则 `gbkDecode('中文')` 会把 UTF-8 字节再按 GBK 解一遍，得到 `涓枃`。
String gbkDecode(Object? input) {
  if (input is String && _looksLikeText(input)) return input;
  return gbkDecodeWithReport(_coerceToBytes(input)).text;
}

/// 判断字符串是否已是解码后的文本而非「单字节字节串」。
///
/// 判据：存在码位 > 0xFF。drpy 里把裸字节当字符串传时用的 latin1 口径，
/// 每个码位必然 <= 0xFF；真实文本几乎不可能全落在该区间（除非纯 ASCII，
/// 而纯 ASCII 两种口径结果相同，无需区分）。
bool _looksLikeText(String s) {
  for (final unit in s.codeUnits) {
    if (unit > 0xFF) return true;
  }
  return false;
}

/// 把脚本传来的值归一成字节序列。
///
/// 字符串的情况需要特别处理：QuickJS 侧的字符串按 UTF-8 传入 Dart，若脚本已经
/// 用 `latin1` 之类的口径把原始字节映射成码位（每个码位 < 256），需要把它们
/// **还原**成单字节。这正是 drpy 里 `gbkDecode(response.body)` 的常见前置状态，
/// 因为 `req` 的 `buffer` 选项开启时 body 是裸字节。
///
/// 调用方须先用 [_looksLikeText] 排除「已是文本」的情况，本函数只处理
/// 字节数组与单字节字节串。
///
/// 注意不能用 `input is List<int>` 判断：JSON 解码、QuickJS 桥接等路径产出的
/// 是 `List<dynamic>`，`is List<int>` 为 false。这个坑很隐蔽——判断失效会静默
/// 返回空串而不是报错。
Uint8List _coerceToBytes(Object? input) {
  if (input == null) return Uint8List(0);

  if (input is List) {
    final out = Uint8List(input.length);
    for (var i = 0; i < input.length; i++) {
      final v = input[i];
      out[i] = v is int ? v & 0xFF : 0;
    }
    return out;
  }

  if (input is String) {
    final units = input.codeUnits;
    final out = Uint8List(units.length);
    for (var i = 0; i < units.length; i++) {
      out[i] = units[i] & 0xFF;
    }
    return out;
  }

  return Uint8List(0);
}

/// 查码表。
///
/// 下标算术与 `gbk_table.dart` 的排列方式严格对应：按首字节分块，块内按
/// 尾字节升序、跳过 `0x7F`。
String? _lookup(int b1, int b2) {
  final row = b1 - gbkLeadMin;
  if (row < 0) return null;
  // 尾字节 >= 0x80 时要跳过 0x7F 占的位置，故先算原始偏移再减一。
  var col = b2 - gbkTrailMin;
  if (b2 > 0x7F) col -= 1;
  if (col < 0 || col >= gbkRowWidth) return null;

  final index = row * gbkRowWidth + col;
  if (index < 0 || index >= gbkTable.length) return null;

  final ch = gbkTable[index];
  if (ch == gbkUnmapped) return null;
  return ch;
}
