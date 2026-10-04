/// 频道排序的验证。
///
/// 盯住的是三件事：**自然序**（`CCTV2` 要排在 `CCTV10` 前）、**稳定性**
/// （Dart 的 `List.sort` 不稳定，同键频道的相对顺序必须由我们自己兜住）、
/// **不改动入参**（排序结果不该和仓库里那份共用可变对象）。
library;

import 'package:live/live.dart';
import 'package:test/test.dart';

LiveChannel _ch(String name, {String? id, int? number}) => LiveChannel(
  id: id ?? name,
  name: name,
  url: 'http://a/${id ?? name}.m3u8',
  channelNumber: number,
);

List<String> _names(List<LiveChannel> channels) => [
  for (final c in channels) c.name,
];

void main() {
  group('compareChannelNames — 自然序', () {
    test('数字段按数值比，而不是逐码点', () {
      // 逐码点比较会把 CCTV10 排在 CCTV2 前面（'1' < '2'），这是最常见的一类
      // 台名，排错了一眼就能看出来。
      expect(compareChannelNames('CCTV2', 'CCTV10'), isNegative);
      expect(compareChannelNames('CCTV10', 'CCTV2'), isPositive);
      expect(compareChannelNames('CCTV9', 'CCTV10'), isNegative);
    });

    test('数值相等但写法不同时短的在前，且自反为 0', () {
      expect(compareChannelNames('CCTV01', 'CCTV1'), isPositive);
      expect(compareChannelNames('CCTV1', 'CCTV01'), isNegative);
      // 完全相同必须返回 0，否则排序会变成不稳定的。
      expect(compareChannelNames('CCTV1', 'CCTV1'), 0);
    });

    test('前导零不改变数值大小关系', () {
      expect(compareChannelNames('CCTV007', 'CCTV10'), isNegative);
      expect(compareChannelNames('CCTV10', 'CCTV007'), isPositive);
      expect(compareChannelNames('000', '0'), isPositive);
    });

    test('非数字部分按码点序，且前缀短的排前面', () {
      expect(compareChannelNames('CCTV', 'CCTV1'), isNegative);
      expect(compareChannelNames('HBO', 'HBO2'), isNegative);
      expect(compareChannelNames('A', 'B'), isNegative);
    });

    test('中文名走码点序（确定性优先，不做拼音序）', () {
      // 只断言「确定性 + 反对称」，不断言谁在前 —— 码点序对中文没有语义，
      // 写死期望值等于把实现细节钉在测试里。
      final forward = compareChannelNames('湖南卫视', '浙江卫视');
      final backward = compareChannelNames('浙江卫视', '湖南卫视');
      expect(forward, -backward);
      expect(compareChannelNames('湖南卫视', '湖南卫视'), 0);
    });

    test('数字在中间也认', () {
      expect(compareChannelNames('CCTV-2', 'CCTV-10'), isNegative);
      expect(compareChannelNames('CCTV-2高清', 'CCTV-10高清'), isNegative);
    });
  });

  group('sortLiveChannels — source 档', () {
    test('保持源顺序', () {
      final source = [_ch('CCTV10'), _ch('CCTV2'), _ch('CCTV1')];
      final sorted = sortLiveChannels(source, LiveChannelSortOrder.source);
      expect(_names(sorted), ['CCTV10', 'CCTV2', 'CCTV1']);
    });

    test('返回的是副本，改它不影响入参', () {
      final source = [_ch('A'), _ch('B')];
      final sorted = sortLiveChannels(source, LiveChannelSortOrder.source);
      sorted.clear();
      expect(source, hasLength(2));
    });

    test('空列表与单元素都不炸', () {
      expect(sortLiveChannels([], LiveChannelSortOrder.byName), isEmpty);
      expect(
        _names(sortLiveChannels([_ch('A')], LiveChannelSortOrder.byName)),
        ['A'],
      );
    });
  });

  group('sortLiveChannels — byName 档', () {
    test('CCTV1..CCTV12 按数值排好', () {
      final source = [
        _ch('CCTV10'),
        _ch('CCTV2'),
        _ch('CCTV12'),
        _ch('CCTV1'),
      ];
      final sorted = sortLiveChannels(source, LiveChannelSortOrder.byName);
      expect(_names(sorted), ['CCTV1', 'CCTV2', 'CCTV10', 'CCTV12']);
    });

    test('排序是稳定的：同键频道保持源顺序', () {
      // 自然序下 `CCTV1` 与 `CCTV01` 的数值相等但长度不同，所以用真正相等
      // 的键：同名但不同地址的频道（真实源里同名会合并，这里手工造）。
      final a = _ch('CCTV1', id: 'a');
      final b = _ch('CCTV1', id: 'b');
      final c = _ch('CCTV1', id: 'c');
      final sorted = sortLiveChannels([a, b, c], LiveChannelSortOrder.byName);
      expect([for (final x in sorted) x.id], ['a', 'b', 'c']);
    });

    test('稳定性在长列表上也成立（同名前缀混排）', () {
      final source = [
        for (var i = 0; i < 6; i++) _ch('CCTV1', id: 'x$i'),
        _ch('CCTV2', id: 'y'),
      ];
      final sorted = sortLiveChannels(source, LiveChannelSortOrder.byName);
      expect(_names(sorted).first, 'CCTV1');
      expect(sorted.last.id, 'y');
      expect(
        [for (final x in sorted.take(6)) x.id],
        ['x0', 'x1', 'x2', 'x3', 'x4', 'x5'],
      );
    });

    test('不改动入参', () {
      final source = [_ch('CCTV10'), _ch('CCTV2')];
      sortLiveChannels(source, LiveChannelSortOrder.byName);
      expect(_names(source), ['CCTV10', 'CCTV2']);
    });
  });

  group('sortLiveChannels — favoritesFirst 档', () {
    test('收藏的排最前，收藏之间保持源顺序', () {
      final source = [
        _ch('A', id: 'a'),
        _ch('B', id: 'b'),
        _ch('C', id: 'c'),
        _ch('D', id: 'd'),
      ];
      final sorted = sortLiveChannels(
        source,
        LiveChannelSortOrder.favoritesFirst,
        favorites: {'c', 'b'},
      );
      expect([for (final x in sorted) x.id], ['b', 'c', 'a', 'd']);
    });

    test('没有收藏时等价于源顺序', () {
      final source = [_ch('A', id: 'a'), _ch('B', id: 'b')];
      final sorted = sortLiveChannels(
        source,
        LiveChannelSortOrder.favoritesFirst,
      );
      expect([for (final x in sorted) x.id], ['a', 'b']);
    });

    test('收藏了不在列表里的 id 不影响结果', () {
      final source = [_ch('A', id: 'a'), _ch('B', id: 'b')];
      final sorted = sortLiveChannels(
        source,
        LiveChannelSortOrder.favoritesFirst,
        favorites: {'不存在'},
      );
      expect([for (final x in sorted) x.id], ['a', 'b']);
    });
  });

  group('liveChannelSortOrderFromName', () {
    test('认得出全部枚举名', () {
      for (final order in LiveChannelSortOrder.values) {
        expect(liveChannelSortOrderFromName(order.name), order);
      }
    });

    test('未知名 / null / 空串回退到源顺序', () {
      expect(
        liveChannelSortOrderFromName('byPinyin'),
        LiveChannelSortOrder.source,
      );
      expect(liveChannelSortOrderFromName(null), LiveChannelSortOrder.source);
      expect(liveChannelSortOrderFromName(''), LiveChannelSortOrder.source);
    });

    test('每个档位都有非空的中文标签', () {
      for (final order in LiveChannelSortOrder.values) {
        expect(order.label, isNotEmpty);
      }
    });
  });
}
