/// 剧集序号（0-based）—— 全链路唯一的「第几集」表示。
///
/// ## 为什么需要这个类型
///
/// 「第几集」在链路上以**字符串 id** 的形式传递：详情页把剧集列表的下标编码成
/// `VodEpisode.id`，播放页再用它回查 `vod_play_url` 里的同一位置。这个约定
/// 此前在两个包里各写了一份，而且**不一致**：详情端用「非空剧集的计数」
/// （`eps.length`），播放端用 `split('#')` 的下标。源数据里只要出现空段
/// （如 `第1集$u1##第4集$u4`），两边立刻错位——用户点第 3 集，播放端取到的是
/// 空串，整条线路被判成「无地址」丢弃。
///
/// 约定收进这里之后只剩一份实现：生成端与消费端不会各自漂移。
///
/// ## 越界为什么不回退
///
/// [resolveIn] 在越界时返回 `null`，而不是退回第一集。**静默回退是危险的**：
/// 用户点第 5 集、而线路只有 3 集时悄悄播第 1 集，用户不会知道自己看的是哪一集，
/// 进度也会记到错误的位置上。宁可让调用方明确处理「这一集不存在」。
library;

import 'package:meta/meta.dart';

/// 剧集序号，0-based。
///
/// 不可变值对象，相等性按 [value] 判定，可直接用作 Map 键或放进 Set。
@immutable
final class EpisodeIndex {
  /// 以序号构造。
  ///
  /// 直接构造不会校验负值；从外部输入构造请走 [EpisodeIndex.parse] 或
  /// [EpisodeIndex.of]，它们会把负数归一成 [first]。
  const EpisodeIndex(this.value);

  /// 第一集，也是「没指定哪一集」时的兜底值。
  static const EpisodeIndex first = EpisodeIndex(0);

  /// 序号，0-based。
  final int value;

  /// 解析详情页传来的剧集 id（[EpisodeIndex] 的字符串形态）。
  ///
  /// `null`、空串、非数字一律归为 [first]：这些都是「没指定哪一集」的形态，
  /// 播第一集是唯一合理的解释。负数同样归 [first]——那一定是上游算错了，
  /// 而不是想表达「倒数第几集」。
  factory EpisodeIndex.parse(String? raw) {
    if (raw == null || raw.isEmpty) return first;
    return EpisodeIndex.of(int.tryParse(raw) ?? 0);
  }

  /// 以整数序号构造；负数归一成 [first]。
  ///
  /// 主要用于把 `History.episodeIndex` 这类落库字段还原成值对象——库里存的是
  /// 裸整数，可能被旧版本或异常路径写成负数。
  factory EpisodeIndex.of(int raw) => raw < 0 ? first : EpisodeIndex(raw);

  /// 编码回详情页使用的字符串 id。
  String get asId => '$value';

  /// 在长度为 [length] 的剧集列表里定位本序号；越界返回 `null`。
  ///
  /// [length] 为 0（该线路一集都没有）时同样返回 `null`。
  ///
  /// 返回值仍是 [EpisodeIndex] 而不是 `int`，是为了让调用方**必须先处理
  /// `null`** 才能取到下标——越界这件事无法被无声跳过。
  EpisodeIndex? resolveIn(int length) => value < length ? this : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is EpisodeIndex && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'EpisodeIndex($value)';
}
