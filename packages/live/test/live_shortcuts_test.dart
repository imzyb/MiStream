/// 直播页按键规则表的验证。
///
/// 这张表里有三个**会真的出错**的判断，用例就是冲它们来的：
/// 1. `Esc` 只在数字缓冲非空时接管 —— 无条件接管会让直播下退不出全屏；
/// 2. `Shift` / `Ctrl` 组合键必须让给播放器默认表 —— 否则直播下没有音量键；
/// 3. 十个数字键要各自对上自己的数字。
library;

import 'package:live/live.dart';
import 'package:test/test.dart';

void main() {
  group('方向键换台', () {
    test('↑ / PageUp 是上一个台', () {
      expect(
        resolveLiveKey(LiveKey.channelUp),
        isA<PreviousChannelCommand>(),
      );
    });

    test('↓ / PageDown 是下一个台', () {
      expect(
        resolveLiveKey(LiveKey.channelDown),
        isA<NextChannelCommand>(),
      );
    });

    test('上/下不是同一个命令', () {
      // 写反是最容易犯的错，而且按下去就有反馈，所以单列一条。
      expect(
        resolveLiveKey(LiveKey.channelUp),
        isNot(isA<NextChannelCommand>()),
      );
      expect(
        resolveLiveKey(LiveKey.channelDown),
        isNot(isA<PreviousChannelCommand>()),
      );
    });
  });

  group('数字键', () {
    test('十个数字键各自对上自己的数字', () {
      for (final key in LiveKey.values.where((k) => k.isDigit)) {
        final command = resolveLiveKey(key);
        expect(command, isA<LiveDigitCommand>(), reason: '$key 应当是数字键');
        expect((command! as LiveDigitCommand).digit, key.digit);
      }
    });

    test('0..9 齐备且不重不漏', () {
      final digits = {
        for (final key in LiveKey.values.where((k) => k.isDigit)) key.digit!,
      };
      expect(digits, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9});
    });

    test('数字键不受 hasPendingDigits 影响', () {
      expect(
        resolveLiveKey(LiveKey.digit1, hasPendingDigits: true),
        isA<LiveDigitCommand>(),
      );
      expect(
        resolveLiveKey(LiveKey.digit1, hasPendingDigits: false),
        isA<LiveDigitCommand>(),
      );
    });
  });

  group('确认与取消', () {
    test('Enter 是确认跳台', () {
      expect(
        resolveLiveKey(LiveKey.commit),
        isA<CommitChannelNumberCommand>(),
      );
    });

    test('Esc 在数字缓冲非空时接管（清缓冲）', () {
      expect(
        resolveLiveKey(LiveKey.cancel, hasPendingDigits: true),
        isA<CancelChannelNumberCommand>(),
      );
    });

    test('Esc 在缓冲为空时让给播放器默认表', () {
      // 无条件接管会让直播下再也退不出全屏 —— 默认表里 Esc 就是干这个的。
      expect(resolveLiveKey(LiveKey.cancel, hasPendingDigits: false), isNull);
      expect(resolveLiveKey(LiveKey.cancel), isNull);
    });
  });

  group('组合键让位', () {
    test('Shift 组合键全部返回 null（音量的退路）', () {
      // 直播下方向键被换台占了，Shift+↑/↓ 是唯一还剩的音量入口。
      for (final key in LiveKey.values) {
        expect(
          resolveLiveKey(key, shift: true),
          isNull,
          reason: 'Shift + $key 应当让给播放器默认表',
        );
      }
    });

    test('Ctrl 组合键全部返回 null', () {
      for (final key in LiveKey.values) {
        expect(resolveLiveKey(key, ctrl: true), isNull, reason: '$key');
      }
    });

    test('Shift 与 Ctrl 同时按下也让位', () {
      expect(
        resolveLiveKey(LiveKey.channelUp, shift: true, ctrl: true),
        isNull,
      );
    });
  });
}
