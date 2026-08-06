/// 快捷键：单次按键 → 播放器命令的映射。
///
/// 与 `docs/04-播放器设计.md` §9 的快捷键表一一对应。刻意做成纯函数（不依赖
/// widget、不触碰引擎），让这张表能脱离 Flutter widget 树单独测——查表不值得
/// 挂进 widget 测试里才验。
library;

import 'package:flutter/services.dart';

/// 播放器可执行的命令。
///
/// 命令只描述该做什么，不规定怎么做——执行落在 UI 层调 `PlayerController`；
/// 这里只管「哪个键 → 哪个动作」的查表。骨架期没有数据表（轨道/剧集）可编排
/// 的按键映射到 [NotYetWiredCommand]，占住行为位，等数据层就位再接线。
sealed class PlayerCommand {
  /// 命令基类。
  const PlayerCommand();
}

/// 播放/暂停。
class TogglePlayPauseCommand extends PlayerCommand {
  /// 构造命令。
  const TogglePlayPauseCommand();
}

/// 相对当前位置跳转 [delta]。
class SeekCommand extends PlayerCommand {
  /// 构造命令。
  const SeekCommand(this.delta);

  /// 相对偏移量。
  final Duration delta;
}

/// 音量增减。正数加大，负数减小（单位：0..1 的倍率）。
class AdjustVolumeCommand extends PlayerCommand {
  /// 构造命令。
  const AdjustVolumeCommand(this.delta);

  /// 音量增量。
  final double delta;
}

/// 切换静音。
class ToggleMuteCommand extends PlayerCommand {
  /// 构造命令。
  const ToggleMuteCommand();
}

/// 进入/退出全屏（由 UI 判断当前形态，取反）。
class ToggleFullscreenCommand extends PlayerCommand {
  /// 构造命令。
  const ToggleFullscreenCommand();
}

/// 退出全屏。
class ExitFullscreenCommand extends PlayerCommand {
  /// 构造命令。
  const ExitFullscreenCommand();
}

/// 倍速调整一档。[steps] 为正加快、为负放慢；每档 0.25。
class AdjustRateCommand extends PlayerCommand {
  /// 构造命令。
  const AdjustRateCommand(this.steps);

  /// 档位数（每档 0.25）。
  final int steps;
}

/// 倍速重置回 1.0。
class ResetRateCommand extends PlayerCommand {
  /// 构造命令。
  const ResetRateCommand();
}

/// 逐帧步进。[backward] 为真则后退一帧。
class StepFrameCommand extends PlayerCommand {
  /// 构造命令。
  const StepFrameCommand({this.backward = false});

  /// 是否后退一帧。
  final bool backward;
}

/// 截图。
class ScreenshotCommand extends PlayerCommand {
  /// 构造命令。
  const ScreenshotCommand();
}

/// 切换字幕开/关。
class ToggleSubtitleCommand extends PlayerCommand {
  /// 构造命令。
  const ToggleSubtitleCommand();
}

/// 已按表占位、但数据层未就绪的按键。
///
/// 骨架阶段不存在轨道表/播放列表/剧集上下文，切轨（`B` / `Shift+V`）、字幕
/// 延迟（`Z`/`X`）、切换集数（`Ctrl+←/→`）、播放信息浮层（`I`）都无法执行。
/// 统一归到这里，UI 层给一句「此功能将在后续版本提供」。避免键位无声消失，
/// 又不用在骨架期做出不可能出货的行为。
class NotYetWiredCommand extends PlayerCommand {
  /// 构造命令。
  const NotYetWiredCommand();
}

/// 把一次按键解析成命令。
///
/// 返回 `null` 表示该键没有映射。Ctrl 类的「上/下一集」在骨架期无数据，归入
/// [NotYetWiredCommand]。
PlayerCommand? resolvePlayerKey(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool ctrl = false,
}) {
  // Ctrl 组合键：骨架期全部未接线。
  if (ctrl) return const NotYetWiredCommand();

  switch (key) {
    case LogicalKeyboardKey.space:
    case LogicalKeyboardKey.keyK:
      return const TogglePlayPauseCommand();

    case LogicalKeyboardKey.arrowLeft:
      return shift
          ? const SeekCommand(Duration(seconds: -1))
          : const SeekCommand(Duration(seconds: -5));
    case LogicalKeyboardKey.arrowRight:
      return shift
          ? const SeekCommand(Duration(seconds: 1))
          : const SeekCommand(Duration(seconds: 5));
    case LogicalKeyboardKey.keyJ:
      return const SeekCommand(Duration(seconds: -10));
    case LogicalKeyboardKey.keyL:
      return const SeekCommand(Duration(seconds: 10));

    case LogicalKeyboardKey.arrowUp:
      return const AdjustVolumeCommand(0.05);
    case LogicalKeyboardKey.arrowDown:
      return const AdjustVolumeCommand(-0.05);
    case LogicalKeyboardKey.keyM:
      return const ToggleMuteCommand();

    case LogicalKeyboardKey.keyF:
      return const ToggleFullscreenCommand();
    case LogicalKeyboardKey.escape:
      return const ExitFullscreenCommand();

    case LogicalKeyboardKey.bracketLeft:
      return const AdjustRateCommand(-1);
    case LogicalKeyboardKey.bracketRight:
      return const AdjustRateCommand(1);
    case LogicalKeyboardKey.backspace:
      return const ResetRateCommand();

    case LogicalKeyboardKey.comma:
      return const StepFrameCommand(backward: true);
    case LogicalKeyboardKey.period:
      return const StepFrameCommand();

    case LogicalKeyboardKey.keyS:
      return const ScreenshotCommand();

    case LogicalKeyboardKey.keyV:
    case LogicalKeyboardKey.keyB:
    case LogicalKeyboardKey.keyZ:
    case LogicalKeyboardKey.keyX:
    case LogicalKeyboardKey.keyI:
      return const NotYetWiredCommand();

    default:
      return null;
  }
}
