/// 播放器向外发出的错误事件。
library;

import 'package:core_domain/core_domain.dart';
import 'package:meta/meta.dart';

/// 一次播放错误。
///
/// 包着 [AppError] 而不是直接发 [AppError]：播放错误比一般错误多两条上层必须
/// 知道的信息——**是否已经把播放打断**，以及**发生在哪一路、哪个位置**。
///
/// [isFatal] 尤其关键。硬解降级（[ErrorCode.playerHwdecFallback]）走的也是这
/// 条流，但它不是失败而是需要告知用户的降级事件（`docs/04-播放器设计.md` §5
/// 规则 2 要求「在 UI 明确提示，而不是静默黑屏」）。UI 拿 [isFatal] 决定是弹
/// 错误卡片还是飘一条提示，拿不到这个位就只能按错误码去 `if`，每加一个非致
/// 命事件都要改 UI。
@immutable
final class PlayerError {
  /// 构造一次播放错误。
  const PlayerError({
    required this.error,
    this.isFatal = true,
    this.source,
    this.position,
  });

  /// 硬解降级事件的便捷构造。
  ///
  /// 这是唯一一个「不是失败」的常见事件，给它一个具名构造，避免每个实现各写
  /// 一遍 `PlayerError(error: LocalError(code: ...), isFatal: false)`。
  factory PlayerError.hwdecFallback({
    required String from,
    required String to,
    Uri? source,
  }) => PlayerError(
    error: LocalError(
      code: ErrorCode.playerHwdecFallback,
      message: '硬解 $from 不可用，已降级到 $to',
      detail: {'from': from, 'to': to},
    ),
    isFatal: false,
    source: source,
  );

  /// 错误本体，带错误码。
  final AppError error;

  /// 播放是否因此终止。
  ///
  /// `true` 时播放状态已经或即将变为 `PlayerState.error`。
  final bool isFatal;

  /// 出错时正在播放的地址。
  final Uri? source;

  /// 出错时的播放位置。
  final Duration? position;

  /// 错误码，转发自 [error]。
  ErrorCode get code => error.code;

  @override
  String toString() =>
      'PlayerError(${error.code}, fatal=$isFatal): ${error.message}';
}
