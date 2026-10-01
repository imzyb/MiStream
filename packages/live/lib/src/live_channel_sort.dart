import 'package:live/src/live_channel.dart';

/// 频道列表的排序方式。
///
/// 刻意**不提供「按频道号」**这一档：[LiveChannel.channelNumber] 在本项目的
/// 整条链路里没有任何生产者 —— `LiveParser` 不产出它，真实 txt/m3u 源里也
/// 没有对应字段。提供一个永远退化成源顺序的档位，只会让用户以为排序坏了。
/// 名字里带的序号（`CCTV1`、`CCTV-2`）由 [LiveChannelSortOrder.byName] 的
/// 自然序处理。
enum LiveChannelSortOrder {
  /// 保持源里的顺序（默认）。
  ///
  /// 真实直播源的顺序是人工编排过的（`CCTV1` → `CCTV2` → …），比任何自动
  /// 排序都更贴近用户的预期，所以默认不动它。
  source('源顺序'),

  /// 按名称自然序。
  byName('按名称'),

  /// 收藏的频道排在最前，其余保持源顺序。
  favoritesFirst('收藏优先');

  const LiveChannelSortOrder(this.label);

  /// 给用户看的名字。
  final String label;
}

/// 把持久化的名字还原成排序方式。
///
/// 认不出来（旧库、手工改坏、枚举改名）时回退到 [LiveChannelSortOrder.source]
/// 而不抛异常：排序偏好是可选增强，一条脏数据不该让直播页打不开。
LiveChannelSortOrder liveChannelSortOrderFromName(String? name) {
  for (final order in LiveChannelSortOrder.values) {
    if (order.name == name) return order;
  }
  return LiveChannelSortOrder.source;
}

/// 按 [order] 排出一份**新**列表。
///
/// 两条容易踩的规则：
///
/// 1. **必须是稳定排序**。Dart 的 `List.sort` 不保证稳定，所以这里显式用
///    「原始下标」做兜底比较键 —— 否则同名前缀的频道（`CCTV1` 与 `CCTV-1`
///    在自然序下相等）每次排序的相对位置都可能变，列表看起来在随机抖动，
///    而且 `getChannels()` 每次返回的顺序不一样会让上层做 diff 时反复重建。
/// 2. **不改动入参**。`source` 档也返回副本：调用方拿到的是「当前视图」，
///    与仓库里那份原始列表共用同一个对象的话，任何原地修改都会互相污染。
List<LiveChannel> sortLiveChannels(
  List<LiveChannel> channels,
  LiveChannelSortOrder order, {
  Set<String> favorites = const {},
}) {
  if (order == LiveChannelSortOrder.source || channels.length < 2) {
    return List<LiveChannel>.of(channels);
  }

  // 下标一起带上，既做稳定排序的兜底键，也避免 `indexOf` 的 O(n²)。
  final indexed = <({int index, LiveChannel channel})>[
    for (var i = 0; i < channels.length; i++) (index: i, channel: channels[i]),
  ];

  indexed.sort((a, b) {
    final primary = switch (order) {
      LiveChannelSortOrder.byName => compareChannelNames(
        a.channel.name,
        b.channel.name,
      ),
      // 「收藏优先」只需要一个二值比较：收藏的（1）排在不收藏的（0）前面。
      // 写成 `b - a` 而不是 `a - b`，因为这里是在算「a 应该往后挪多少」。
      LiveChannelSortOrder.favoritesFirst =>
        (favorites.contains(b.channel.id) ? 1 : 0) -
            (favorites.contains(a.channel.id) ? 1 : 0),
      LiveChannelSortOrder.source => 0,
    };
    if (primary != 0) return primary;
    return a.index.compareTo(b.index);
  });

  return [for (final entry in indexed) entry.channel];
}

/// 自然序比较：**连续的数字段按数值比**，其余按 UTF-16 码点比。
///
/// 为什么不直接用 `String.compareTo`：那是逐码点比较，`CCTV10` 会排在
/// `CCTV2` 前面（`'1' < '2'`），而真实频道名里 `CCTV1` … `CCTV17` 是最常见
/// 的一类。自然序让 `CCTV2 < CCTV10`，符合人的直觉。
///
/// 中文名走码点序（不是拼音序）：做拼音序需要一份拼音表，收益与成本不成
/// 正比；中文台名之间本来也没有「谁该在前面」的公认答案。
int compareChannelNames(String a, String b) {
  var i = 0;
  var j = 0;

  while (i < a.length && j < b.length) {
    final unitA = a.codeUnitAt(i);
    final unitB = b.codeUnitAt(j);

    if (_isDigit(unitA) && _isDigit(unitB)) {
      final startA = i;
      final startB = j;
      while (i < a.length && _isDigit(a.codeUnitAt(i))) {
        i++;
      }
      while (j < b.length && _isDigit(b.codeUnitAt(j))) {
        j++;
      }

      final digitsA = _stripLeadingZeros(a.substring(startA, i));
      final digitsB = _stripLeadingZeros(b.substring(startB, j));
      // 先比位数（去掉前导零之后），位数多的数值一定更大 —— 这样就不必把
      // 超长数字串转成 int（真实台名里的数字不可能溢出，但没必要留这个坑）。
      if (digitsA.length != digitsB.length) {
        return digitsA.length < digitsB.length ? -1 : 1;
      }
      final byValue = digitsA.compareTo(digitsB);
      if (byValue != 0) return byValue;

      // 数值相等但写法不同（`01` vs `1`）：按原长度短的在前，保证结果确定。
      final lengthA = i - startA;
      final lengthB = j - startB;
      if (lengthA != lengthB) return lengthA < lengthB ? -1 : 1;
      continue;
    }

    if (unitA != unitB) return unitA < unitB ? -1 : 1;
    i++;
    j++;
  }

  final restA = a.length - i;
  final restB = b.length - j;
  if (restA != restB) return restA < restB ? -1 : 1;
  return 0;
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// 去掉前导零，但至少保留一位（`"000"` → `"0"`）。
String _stripLeadingZeros(String digits) {
  var start = 0;
  while (start < digits.length - 1 && digits.codeUnitAt(start) == 0x30) {
    start++;
  }
  return digits.substring(start);
}
