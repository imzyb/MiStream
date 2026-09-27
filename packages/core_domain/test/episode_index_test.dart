/// [EpisodeIndex] 的单测。
///
/// 这个值对象是详情页与播放页之间「第几集」的唯一约定，所以两条边界必须钉死：
/// **输入侧**任何脏值都要收敛到第一集，**输出侧**越界必须返回 `null` 而不是
/// 悄悄退回第一集（回退会让用户看错集却毫无察觉）。
library;

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('EpisodeIndex.parse', () {
    test('正常序号按原值解析', () {
      expect(EpisodeIndex.parse('0').value, 0);
      expect(EpisodeIndex.parse('5').value, 5);
      expect(EpisodeIndex.parse('999').value, 999);
    });

    test('null 与空串都归为第一集', () {
      // 从收藏进入播放页时没有集号，这是最常见的形态。
      expect(EpisodeIndex.parse(null), EpisodeIndex.first);
      expect(EpisodeIndex.parse(''), EpisodeIndex.first);
    });

    test('非数字归为第一集', () {
      // 旧数据或错误用法可能把线路名当集号传进来（如 'lzm3u8'）。
      expect(EpisodeIndex.parse('abc'), EpisodeIndex.first);
      expect(EpisodeIndex.parse('lzm3u8'), EpisodeIndex.first);
      expect(EpisodeIndex.parse('1.5'), EpisodeIndex.first);
    });

    test('负数归为第一集', () {
      expect(EpisodeIndex.parse('-1'), EpisodeIndex.first);
      expect(EpisodeIndex.parse('-99'), EpisodeIndex.first);
    });
  });

  group('EpisodeIndex.of', () {
    test('非负整数原样保留', () {
      expect(EpisodeIndex.of(0).value, 0);
      expect(EpisodeIndex.of(7).value, 7);
    });

    test('负数归为第一集', () {
      // 库里存的是裸整数，可能被旧版本或异常路径写成负数。
      expect(EpisodeIndex.of(-1), EpisodeIndex.first);
      expect(EpisodeIndex.of(-100), EpisodeIndex.first);
    });
  });

  group('asId', () {
    test('编码成详情页使用的字符串形态', () {
      expect(EpisodeIndex.first.asId, '0');
      expect(const EpisodeIndex(3).asId, '3');
    });

    test('与 parse 往返一致', () {
      for (final i in [0, 1, 12, 500]) {
        expect(EpisodeIndex.parse(EpisodeIndex(i).asId), EpisodeIndex(i));
      }
    });
  });

  group('resolveIn', () {
    test('落在范围内时返回自身', () {
      const index = EpisodeIndex(2);
      expect(index.resolveIn(3), index);
      expect(EpisodeIndex.first.resolveIn(1), EpisodeIndex.first);
    });

    test('越界返回 null，不回退到第一集', () {
      // 这是本类型存在的核心原因：宁可让调用方明确报错，也不能让用户点第 5 集
      // 却看到第 1 集。
      expect(const EpisodeIndex(3).resolveIn(3), isNull);
      expect(const EpisodeIndex(99).resolveIn(3), isNull);
    });

    test('空列表里连第一集也不存在', () {
      // 该线路一集都没有时，第一集同样是越界。
      expect(EpisodeIndex.first.resolveIn(0), isNull);
    });
  });

  group('相等性', () {
    test('按序号相等', () {
      expect(const EpisodeIndex(2), const EpisodeIndex(2));
      expect(const EpisodeIndex(2), isNot(EpisodeIndex.first));
      expect(const EpisodeIndex(2).hashCode, const EpisodeIndex(2).hashCode);
    });

    test('可安全用作 Set 元素', () {
      // 逐个 add 而不是写字面量：字面量里的重复项会被 lint 当成笔误拦下，
      // 而这里要验的恰恰是「重复项被去重」。
      final set = <EpisodeIndex>{};
      set.add(EpisodeIndex.first);
      set.add(const EpisodeIndex(1));
      set.add(const EpisodeIndex(1));
      expect(set, hasLength(2));
    });

    test('toString 便于诊断', () {
      expect(const EpisodeIndex(4).toString(), 'EpisodeIndex(4)');
    });
  });
}
