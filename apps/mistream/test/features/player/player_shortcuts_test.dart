import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/features/player/player_shortcuts.dart';

void main() {
  group('resolvePlayerKey — docs/04 §9 快捷键表', () {
    test('Space 与 K 是播放/暂停', () {
      expect(
        resolvePlayerKey(LogicalKeyboardKey.space),
        isA<TogglePlayPauseCommand>(),
      );
      expect(
        resolvePlayerKey(LogicalKeyboardKey.keyK),
        isA<TogglePlayPauseCommand>(),
      );
    });

    test('←/→ 默认 ±5s，Shift 后 ±1s', () {
      final left =
          resolvePlayerKey(LogicalKeyboardKey.arrowLeft)! as SeekCommand;
      final right =
          resolvePlayerKey(LogicalKeyboardKey.arrowRight)! as SeekCommand;
      expect(left.delta, const Duration(seconds: -5));
      expect(right.delta, const Duration(seconds: 5));

      final leftShift =
          resolvePlayerKey(LogicalKeyboardKey.arrowLeft, shift: true)!
              as SeekCommand;
      final rightShift =
          resolvePlayerKey(LogicalKeyboardKey.arrowRight, shift: true)!
              as SeekCommand;
      expect(leftShift.delta, const Duration(seconds: -1));
      expect(rightShift.delta, const Duration(seconds: 1));
    });

    test('J/L 是 ±10s', () {
      final j = resolvePlayerKey(LogicalKeyboardKey.keyJ)! as SeekCommand;
      final l = resolvePlayerKey(LogicalKeyboardKey.keyL)! as SeekCommand;
      expect(j.delta, const Duration(seconds: -10));
      expect(l.delta, const Duration(seconds: 10));
    });

    test('↑/↓ 是音量 ±5%', () {
      final up =
          resolvePlayerKey(LogicalKeyboardKey.arrowUp)! as AdjustVolumeCommand;
      final down =
          resolvePlayerKey(LogicalKeyboardKey.arrowDown)!
              as AdjustVolumeCommand;
      expect(up.delta, 0.05);
      expect(down.delta, -0.05);
    });

    test('M 是静音', () {
      expect(
        resolvePlayerKey(LogicalKeyboardKey.keyM),
        isA<ToggleMuteCommand>(),
      );
    });

    test('F/Esc 是全屏相关', () {
      expect(
        resolvePlayerKey(LogicalKeyboardKey.keyF),
        isA<ToggleFullscreenCommand>(),
      );
      expect(
        resolvePlayerKey(LogicalKeyboardKey.escape),
        isA<ExitFullscreenCommand>(),
      );
    });

    test('[ / ] 是倍速 ±1 档，Backspace 重置', () {
      final dec =
          resolvePlayerKey(LogicalKeyboardKey.bracketLeft)!
              as AdjustRateCommand;
      final inc =
          resolvePlayerKey(LogicalKeyboardKey.bracketRight)!
              as AdjustRateCommand;
      expect(dec.steps, -1);
      expect(inc.steps, 1);
      expect(
        resolvePlayerKey(LogicalKeyboardKey.backspace),
        isA<ResetRateCommand>(),
      );
    });

    test(', / . 是逐帧', () {
      final back =
          resolvePlayerKey(LogicalKeyboardKey.comma)! as StepFrameCommand;
      final fwd =
          resolvePlayerKey(LogicalKeyboardKey.period)! as StepFrameCommand;
      expect(back.backward, isTrue);
      expect(fwd.backward, isFalse);
    });

    test('S 是截图', () {
      expect(
        resolvePlayerKey(LogicalKeyboardKey.keyS),
        isA<ScreenshotCommand>(),
      );
    });

    test('无映射的键返回 null', () {
      expect(resolvePlayerKey(LogicalKeyboardKey.keyA), isNull);
      expect(resolvePlayerKey(LogicalKeyboardKey.enter), isNull);
    });

    test('Ctrl 组合键（上/下一集）骨架期归为未接线', () {
      expect(
        resolvePlayerKey(LogicalKeyboardKey.arrowLeft, ctrl: true),
        isA<NotYetWiredCommand>(),
      );
    });

    test('V/B/Z/X/I 未接线但键位保留', () {
      for (final key in [
        LogicalKeyboardKey.keyV,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyZ,
        LogicalKeyboardKey.keyX,
        LogicalKeyboardKey.keyI,
      ]) {
        expect(
          resolvePlayerKey(key),
          isA<NotYetWiredCommand>(),
          reason: '$key 应占住键位',
        );
      }
    });
  });
}
