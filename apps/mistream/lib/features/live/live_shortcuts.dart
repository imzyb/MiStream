/// Flutter 按键 → [LiveKey] 的对照表。
///
/// 这里**只有翻译，没有规则** —— 「哪个键做什么」全在 `package:live` 的
/// `resolveLiveKey` 里，那边是纯 Dart、有用例覆盖（`live_shortcuts_test.dart`）。
/// 之所以要分成两层：`package:flutter/services.dart` 在纯 Dart 测试里编不了，
/// 规则写在这一层就等于永远只有人工验证。
///
/// 这一层唯一容易出的错是「漏认某个键位」（比如忘了小键盘数字），所以下面
/// 用两张显式的表而不是手写十来个 `case`。
library;

import 'package:flutter/services.dart';
import 'package:live/live.dart';

/// 主键盘数字行 `0..9`，下标即数字。
const List<LogicalKeyboardKey> _mainRowDigits = [
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// 小键盘数字 `0..9`，下标即数字。
///
/// 必须认：遥控器、带数字区的键盘、以及「用方向键区当数字键」的遥控器都会
/// 走小键盘码。
const List<LogicalKeyboardKey> _numpadDigits = [
  LogicalKeyboardKey.numpad0,
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

/// 数字 → `LiveKey` 的查表。
///
/// 不用「`LiveKey.digit0.index + 数字`」这种算术：那依赖「十个数字键在枚举里
/// 连续排列」这个隐含约定，将来有人插一个新键位就会静默错位。直接查表，错了
/// 一眼能看出来。
final Map<int, LiveKey> _digitKeys = {
  for (final key in LiveKey.values)
    if (key.digit != null) key.digit!: key,
};

/// 把 Flutter 按键翻译成 [LiveKey]；直播页不认的键返回 `null`。
LiveKey? liveKeyOf(LogicalKeyboardKey key) {
  final main = _mainRowDigits.indexOf(key);
  if (main >= 0) return _digitKeys[main];

  final numpad = _numpadDigits.indexOf(key);
  if (numpad >= 0) return _digitKeys[numpad];

  if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.pageUp) {
    return LiveKey.channelUp;
  }
  if (key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.pageDown) {
    return LiveKey.channelDown;
  }
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter) {
    return LiveKey.commit;
  }
  if (key == LogicalKeyboardKey.escape) return LiveKey.cancel;

  return null;
}
