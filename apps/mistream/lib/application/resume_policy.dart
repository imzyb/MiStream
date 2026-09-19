/// 续播位置的决策逻辑。
///
/// 抽成独立对象的原因：这段判断原先内嵌在播放页的 `State` 里，依赖
/// `globalRouterAssembly` 全局变量与 widget 生命周期，导致「关闭重开能否
/// 续播」（ROADMAP M5 出口标准）只能靠手工点界面验证，写不了自动化测试。
///
/// 这里只做纯决策——给一个历史记录，回答「要不要续播、续到哪」，不碰
/// 数据库、不碰播放器。播放页把决策结果交给控制器执行。
library;

import 'package:meta/meta.dart';

/// 一条待续播的进度。
@immutable
final class ResumePoint {
  /// 构造续播点。
  const ResumePoint({required this.position, required this.duration});

  /// 上次离开时的播放位置。
  final Duration position;

  /// 该媒体的总时长。
  final Duration duration;
}

/// 续播决策规则（`docs/04` §10）。
///
/// 两条边界刻意不续播：
/// - **位置不足 [minPosition]**：刚开头几秒没必要快进一下，反而多一次
///   seek 扰动起播。
/// - **离结尾不足 [endTail]**：等于已经看完，下次应当从头开始，否则用户
///   一进来就撞上片尾。
abstract final class ResumePolicy {
  /// 低于此位置不续播。
  static const Duration minPosition = Duration(seconds: 5);

  /// 距结尾不足此距离视为已看完，不续播。
  static const Duration endTail = Duration(seconds: 30);

  /// 判断 [point] 是否应当续播，是则返回目标位置。
  ///
  /// 时长为零（内核未报出时长）时不续播：无法判断「是否接近结尾」，
  /// 贸然 seek 可能落到片尾。
  static Duration? resolve(ResumePoint? point) {
    if (point == null) return null;
    if (point.duration <= Duration.zero) return null;
    if (point.position < minPosition) return null;
    if (point.position >= point.duration - endTail) return null;
    return point.position;
  }

  /// 首帧到达后是否还应当执行续播 seek。
  ///
  /// 仅在「已确认开始播放」且「位置仍在开头」时执行一次。位置已经跑起来
  /// （超过 [stillAtStart]）说明内核自己恢复了进度或用户已手动操作，此时
  /// 再 seek 是打扰。
  static bool shouldSeekAfterStart({
    required Duration? pending,
    required bool hasPlaybackEvidence,
    required Duration currentPosition,
    Duration stillAtStart = const Duration(seconds: 3),
  }) {
    if (pending == null) return false;
    if (!hasPlaybackEvidence) return false;
    // 位置字段可能是估算值，容差小于目标位置时视为尚未推进。
    return currentPosition < stillAtStart;
  }
}
