import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

void main() {
  group('AspectRatioMode', () {
    test('四个变体互不相等', () {
      const modes = <AspectRatioMode>[
        AspectRatioMode.auto(),
        AspectRatioMode.fill(),
        AspectRatioMode.stretch(),
        AspectRatioMode.ratio(16, 9),
      ];

      for (var i = 0; i < modes.length; i++) {
        for (var j = 0; j < modes.length; j++) {
          if (i == j) {
            expect(modes[i], modes[j]);
          } else {
            expect(modes[i], isNot(modes[j]));
          }
        }
      }
    });

    test('自定义比例按分量比较', () {
      expect(
        const AspectRatioMode.ratio(16, 9),
        const AspectRatioMode.ratio(16, 9),
      );
      expect(
        const AspectRatioMode.ratio(16, 9),
        isNot(const AspectRatioMode.ratio(4, 3)),
      );
    });

    test('自定义比例给出 mpv 取值', () {
      const mode = CustomAspectRatio(21, 9);

      expect(mode.mpvValue, '21/9');
    });

    test('分量必须为正', () {
      var width = 1;
      width = 0;

      expect(
        () => CustomAspectRatio(width, 9),
        throwsA(isA<AssertionError>()),
      );
    });

    test('可被穷尽匹配', () {
      String describe(AspectRatioMode mode) => switch (mode) {
        AutoAspectRatio() => 'auto',
        FillAspectRatio() => 'fill',
        StretchAspectRatio() => 'stretch',
        CustomAspectRatio(:final width, :final height) => '$width:$height',
      };

      expect(describe(const AspectRatioMode.auto()), 'auto');
      expect(describe(const AspectRatioMode.ratio(4, 3)), '4:3');
    });
  });

  group('VideoFilterSettings', () {
    test('默认全中性', () {
      expect(VideoFilterSettings.neutral.isNeutral, isTrue);
    });

    test('任一分量非零即不中性', () {
      expect(const VideoFilterSettings(gamma: 1).isNeutral, isFalse);
    });

    test('copyWith 只改指定分量', () {
      const settings = VideoFilterSettings(brightness: 10, contrast: 20);
      final updated = settings.copyWith(saturation: 30);

      expect(updated.brightness, 10);
      expect(updated.contrast, 20);
      expect(updated.saturation, 30);
    });

    test('取值范围沿用 mpv 的 -100 ~ 100', () {
      var value = 0;
      value = 101;

      expect(
        () => VideoFilterSettings(brightness: value),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => VideoFilterSettings(gamma: -value),
        throwsA(isA<AssertionError>()),
      );
    });

    test('边界值可用', () {
      expect(
        () => const VideoFilterSettings(brightness: 100, contrast: -100),
        returnsNormally,
      );
    });

    test('按内容比较', () {
      expect(
        const VideoFilterSettings(brightness: 5),
        const VideoFilterSettings(brightness: 5),
      );
      expect(
        const VideoFilterSettings(brightness: 5).hashCode,
        const VideoFilterSettings(brightness: 5).hashCode,
      );
    });
  });

  group('PlayerState', () {
    test('缓冲算在播放中', () {
      // 用户视角里缓冲是播放的一部分，控制栏此时应显示「暂停」按钮。
      expect(PlayerState.buffering.isPlaying, isTrue);
      expect(PlayerState.playing.isPlaying, isTrue);
      expect(PlayerState.paused.isPlaying, isFalse);
    });

    test('idle 与 error 没有媒体', () {
      expect(PlayerState.idle.hasMedia, isFalse);
      expect(PlayerState.error.hasMedia, isFalse);
      expect(PlayerState.paused.hasMedia, isTrue);
    });

    test('ended 与 error 是终态', () {
      expect(PlayerState.ended.isTerminal, isTrue);
      expect(PlayerState.error.isTerminal, isTrue);
      expect(PlayerState.playing.isTerminal, isFalse);
    });
  });

  group('PlayerLogLevel', () {
    test('mpv 级别名可映射', () {
      expect(PlayerLogLevel.fromMpvLevel('warn'), PlayerLogLevel.warn);
      expect(PlayerLogLevel.fromMpvLevel('v'), PlayerLogLevel.debug);
      expect(PlayerLogLevel.fromMpvLevel('fatal'), PlayerLogLevel.fatal);
    });

    test('认不出的级别当 info，不丢日志', () {
      expect(PlayerLogLevel.fromMpvLevel('未来的新级别'), PlayerLogLevel.info);
    });
  });
}
