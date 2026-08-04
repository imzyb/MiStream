/// 缓冲区间。
library;

import 'package:meta/meta.dart';

/// 一段左闭右闭的时间区间。
///
/// `docs/04-播放器设计.md` §3 原本把缓冲进度写成 `List<Duration>`，但一个区间
/// 需要起止两个值，单个 [Duration] 表达不了——播放器在网络流上经常同时持有多
/// 段不连续的缓冲（seek 之后旧段还没被丢弃），扁平的 [Duration] 列表既分不清
/// 哪两个是一对，也表达不了「从哪儿到哪儿」。文档已同步为本类型。
@immutable
final class DurationRange {
  /// 构造一个区间。[start] 不得晚于 [end]。
  ///
  /// 刻意不是 `const` 构造：断言里的 `<=` 不是常量表达式，标成 `const` 会让
  /// 常量上下文里的调用直接编译失败。缓冲区间全部来自运行期，不需要常量。
  // ignore: prefer_const_constructors_in_immutables — 见上方构造函数注释
  DurationRange(this.start, this.end) : assert(start <= end, 'start 不能晚于 end');

  /// 区间起点。
  final Duration start;

  /// 区间终点。
  final Duration end;

  /// 区间长度。
  Duration get length => end - start;

  /// 区间是否为空（起止相同）。
  bool get isEmpty => start == end;

  /// [position] 是否落在区间内（含端点）。
  bool contains(Duration position) => position >= start && position <= end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DurationRange && other.start == start && other.end == end);

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() =>
      'DurationRange(${start.inMilliseconds}ms '
      '- ${end.inMilliseconds}ms)';
}
