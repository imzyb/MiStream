/// 直播播放页的按键规则：按键 → 直播命令。
///
/// 为什么按键要用 [LiveKey] 而不是直接用 Flutter 的 `LogicalKeyboardKey`：
/// `package:flutter/services.dart` 在纯 Dart 测试里编不了（本项目的 widget
/// 测试跑不起来，见 `docs/PROGRESS_AUDIT_2026-09-19.md`），规则表若直接写
/// 在 Flutter 类型上，就只能靠人工点一遍验证。把「规则」与「按键名的翻译」
/// 分开之后，规则表（`resolveLiveKey`）是纯 Dart，能被用例盯住；app 层只剩
/// 一张机械的对照表。
///
/// 与播放器默认快捷键表（`player_shortcuts.dart`）的**边界**：
///
/// - [LiveKey.channelUp] / [LiveKey.channelDown]：直播下是**换台**（默认表里
///   方向键是音量）。频道列表是竖排的，方向与列表一致最不容易按错。
/// - 数字键：进频道号缓冲，攒够或超时后跳台。
/// - [LiveKey.commit]：立刻确认跳台。
/// - [LiveKey.cancel]：**只在数字缓冲非空时**接管（清缓冲）。空缓冲时返回
///   `null` 让给默认表，否则直播下就再也退不出全屏了。
/// - `shift` / `ctrl` 组合键一律返回 `null` 让给默认表 —— 这是音量的退路：
///   `Shift+↑/↓` 仍是音量加减。
library;

/// 直播页认得的按键。
///
/// 与具体平台的键值解耦，见库文档。
enum LiveKey {
  /// 上一个台。
  channelUp,

  /// 下一个台。
  channelDown,

  /// 确认跳台。
  commit,

  /// 取消跳台。
  cancel,

  /// 数字 `0`。
  digit0(0),

  /// 数字 `1`。
  digit1(1),

  /// 数字 `2`。
  digit2(2),

  /// 数字 `3`。
  digit3(3),

  /// 数字 `4`。
  digit4(4),

  /// 数字 `5`。
  digit5(5),

  /// 数字 `6`。
  digit6(6),

  /// 数字 `7`。
  digit7(7),

  /// 数字 `8`。
  digit8(8),

  /// 数字 `9`。
  digit9(9);

  const LiveKey([this.digit]);

  /// 数字键对应的数字；非数字键为 `null`。
  final int? digit;

  /// 是否为数字键。
  bool get isDigit => digit != null;
}

/// 直播页可执行的命令。
sealed class LiveCommand {
  /// 命令基类。
  const LiveCommand();
}

/// 上一个台。
class PreviousChannelCommand extends LiveCommand {
  /// 构造命令。
  const PreviousChannelCommand();
}

/// 下一个台。
class NextChannelCommand extends LiveCommand {
  /// 构造命令。
  const NextChannelCommand();
}

/// 数字键：把一位数字追加进频道号缓冲。
class LiveDigitCommand extends LiveCommand {
  /// 构造命令。
  const LiveDigitCommand(this.digit);

  /// 按下的数字（0..9）。
  final int digit;
}

/// 确认跳台。
class CommitChannelNumberCommand extends LiveCommand {
  /// 构造命令。
  const CommitChannelNumberCommand();
}

/// 取消跳台，清掉数字缓冲。
class CancelChannelNumberCommand extends LiveCommand {
  /// 构造命令。
  const CancelChannelNumberCommand();
}

/// 把一次按键解析成直播命令。
///
/// 返回 `null` 表示直播页不接管这个键，交给播放器默认快捷键表。
/// [hasPendingDigits] 决定 [LiveKey.cancel] 归谁 —— 见库文档的边界说明。
LiveCommand? resolveLiveKey(
  LiveKey key, {
  bool shift = false,
  bool ctrl = false,
  bool hasPendingDigits = false,
}) {
  // 组合键留给播放器默认表：这是直播下调节音量的唯一退路（Shift+↑/↓）。
  if (shift || ctrl) return null;

  final digit = key.digit;
  if (digit != null) return LiveDigitCommand(digit);

  return switch (key) {
    LiveKey.channelUp => const PreviousChannelCommand(),
    LiveKey.channelDown => const NextChannelCommand(),
    LiveKey.commit => const CommitChannelNumberCommand(),
    // 空缓冲时让给默认表（那里 Esc 是退出全屏）。
    LiveKey.cancel =>
      hasPendingDigits ? const CancelChannelNumberCommand() : null,
    // 数字键在上面处理掉了。
    _ => null,
  };
}
