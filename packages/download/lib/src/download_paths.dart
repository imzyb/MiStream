/// 下载目录名与保存路径的纯计算。
///
/// 放纯函数而不是塞在 UI 里：Windows 对文件名有一串隐藏规则（非法字符、结尾的
/// 点与空格会被吃掉、保留设备名），踩中任何一条的结果都是「落库的路径」与
/// 「盘上的实际路径」不一致 —— 续传与删除会去找一个不存在的目录，而且不报错。
library;

/// Windows 文件名里不允许出现的字符。
const _illegalChars = r'\/:*?"<>|';

/// Windows 保留的设备名。
///
/// 这些名字**不能**作为文件名或目录名，即使带扩展名也不行：`CON.mp4` 依然
/// 会被解释成控制台设备。真实的影片标题里出现 `CON` 的概率很低，但「整集标题
/// 就叫 AUX」这种源是存在的，而后果是创建目录直接失败。
const _reservedNames = {
  'con',
  'prn',
  'aux',
  'nul',
  'com1',
  'com2',
  'com3',
  'com4',
  'com5',
  'com6',
  'com7',
  'com8',
  'com9',
  'lpt1',
  'lpt2',
  'lpt3',
  'lpt4',
  'lpt5',
  'lpt6',
  'lpt7',
  'lpt8',
  'lpt9',
};

/// 目录名长度上限（按字符数，不按字节）。
///
/// Windows 的 `MAX_PATH` 是 260，而保存路径 = 应用数据目录 + `downloads/` +
/// 目录名 + 分片文件名。标题留 80 个字符，剩下的额度足够，也避免了中文标题
/// 按 UTF-8 算字节数时的溢出。
const kMaxDownloadNameLength = 80;

/// 把媒体标题清理成一个跨平台安全的目录名。
///
/// 规则依次是：非法字符与控制字符换成 `_`、去掉结尾的点与空格、截断到
/// [kMaxDownloadNameLength]、保留名加前缀、空结果回落到 [fallback]。
String sanitizeDownloadName(
  String title, {
  String fallback = 'download',
  int maxLength = kMaxDownloadNameLength,
}) {
  final chars = <String>[];
  for (final rune in title.runes) {
    if (rune < 0x20 || _illegalChars.contains(String.fromCharCode(rune))) {
      chars.add('_');
    } else {
      chars.add(String.fromCharCode(rune));
    }
  }

  // Windows 会悄悄吃掉结尾的点和空格：`"第1集."` 实际建成的是 `"第1集"`。
  // 不去掉的话，库里记的是带点的路径，盘上是不带点的 —— 两边对不上。
  while (chars.isNotEmpty && (chars.last == '.' || chars.last == ' ')) {
    chars.removeLast();
  }

  if (chars.length > maxLength) chars.removeRange(maxLength, chars.length);

  var name = chars.join();
  if (name.isEmpty) name = fallback;

  // 保留名判断要在**去掉扩展名之后**：`CON.mp4` 同样会被当成设备名。
  final stem = name.split('.').first.toLowerCase();
  if (_reservedNames.contains(stem)) name = '_$name';

  return name;
}
