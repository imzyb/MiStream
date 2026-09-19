/// `ResumePolicy` 的边界测试（ROADMAP M5 出口标准「关闭重开能从上次位置续播」）。
///
/// 这段逻辑原先内嵌在播放页 State 里，只能靠手工点界面验证；抽出来后
/// 边界条件（刚开头、接近片尾、时长为零）都能在这里精确覆盖。
library;

import 'package:mistream/application/resume_policy.dart';
import 'package:test/test.dart';

void main() {
  group('ResumePolicy.resolve 续播目标', () {
    const duration = Duration(minutes: 45);

    test('位置在中间时续播到该位置', () {
      final target = ResumePolicy.resolve(
        const ResumePoint(
          position: Duration(minutes: 12),
          duration: duration,
        ),
      );
      expect(target, const Duration(minutes: 12));
    });

    test('位置恰好等于最低阈值时可续播（边界含等于）', () {
      final target = ResumePolicy.resolve(
        ResumePoint(position: ResumePolicy.minPosition, duration: duration),
      );
      expect(target, ResumePolicy.minPosition);
    });

    test('位置不足 5s 不续播', () {
      final target = ResumePolicy.resolve(
        const ResumePoint(
          position: Duration(seconds: 4, milliseconds: 999),
          duration: duration,
        ),
      );
      expect(target, isNull);
    });

    test('位置为零不续播', () {
      final target = ResumePolicy.resolve(
        const ResumePoint(position: Duration.zero, duration: duration),
      );
      expect(target, isNull);
    });

    test('离结尾恰好 30s 时视为看完，不续播（边界含等于）', () {
      final target = ResumePolicy.resolve(
        ResumePoint(
          position: duration - ResumePolicy.endTail,
          duration: duration,
        ),
      );
      expect(target, isNull);
    });

    test('离结尾 29s 不续播', () {
      final target = ResumePolicy.resolve(
        ResumePoint(
          position: duration - const Duration(seconds: 29),
          duration: duration,
        ),
      );
      expect(target, isNull);
    });

    test('离结尾 31s 可续播', () {
      final target = ResumePolicy.resolve(
        ResumePoint(
          position: duration - const Duration(seconds: 31),
          duration: duration,
        ),
      );
      expect(target, isNotNull);
    });

    test('位置等于时长（已播完）不续播', () {
      final target = ResumePolicy.resolve(
        ResumePoint(position: duration, duration: duration),
      );
      expect(target, isNull);
    });

    test('时长为零时无法判断是否接近结尾，不续播', () {
      final target = ResumePolicy.resolve(
        const ResumePoint(
          position: Duration(minutes: 10),
          duration: Duration.zero,
        ),
      );
      expect(target, isNull);
    });

    test('无历史记录不续播', () {
      expect(ResumePolicy.resolve(null), isNull);
    });
  });

  group('ResumePolicy.shouldSeekAfterStart 首帧后是否执行 seek', () {
    const pending = Duration(minutes: 12);

    test('有播放证据且位置仍在开头时执行', () {
      expect(
        ResumePolicy.shouldSeekAfterStart(
          pending: pending,
          hasPlaybackEvidence: true,
          currentPosition: Duration.zero,
        ),
        isTrue,
      );
    });

    test('尚无播放证据时不执行', () {
      expect(
        ResumePolicy.shouldSeekAfterStart(
          pending: pending,
          hasPlaybackEvidence: false,
          currentPosition: Duration.zero,
        ),
        isFalse,
      );
    });

    test('位置已推进到阈值时不执行（避免打扰正在播放的画面）', () {
      expect(
        ResumePolicy.shouldSeekAfterStart(
          pending: pending,
          hasPlaybackEvidence: true,
          currentPosition: const Duration(seconds: 3),
        ),
        isFalse,
      );
    });

    test('位置刚好在阈值内仍执行（边界不含等于）', () {
      expect(
        ResumePolicy.shouldSeekAfterStart(
          pending: pending,
          hasPlaybackEvidence: true,
          currentPosition: const Duration(seconds: 2, milliseconds: 999),
        ),
        isTrue,
      );
    });

    test('无待续播目标时不执行', () {
      expect(
        ResumePolicy.shouldSeekAfterStart(
          pending: null,
          hasPlaybackEvidence: true,
          currentPosition: Duration.zero,
        ),
        isFalse,
      );
    });
  });
}
