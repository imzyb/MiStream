import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ReconnectPolicy', () {
    // docs/04 §6：1s/2s/4s/8s，上限 5 次。
    test('按 2 的幂递增并封顶', () {
      const policy = ReconnectPolicy();

      expect(policy.delayForAttempt(1), const Duration(seconds: 1));
      expect(policy.delayForAttempt(2), const Duration(seconds: 2));
      expect(policy.delayForAttempt(3), const Duration(seconds: 4));
      expect(policy.delayForAttempt(4), const Duration(seconds: 8));
      expect(policy.delayForAttempt(5), const Duration(seconds: 8));
    });

    test('超过上限即不再重连', () {
      const policy = ReconnectPolicy();

      expect(policy.delayForAttempt(6), isNull);
    });

    test('次数从 1 开始', () {
      const policy = ReconnectPolicy();

      expect(() => policy.delayForAttempt(0), throwsArgumentError);
    });

    test('none 表示完全不重连', () {
      expect(ReconnectPolicy.none.isEnabled, isFalse);
      expect(ReconnectPolicy.none.delayForAttempt(1), isNull);
    });
  });

  group('PlayerConfig', () {
    test('点播与直播的缓冲上限不同', () {
      const config = PlayerConfig();

      expect(config.cacheBytesFor(isLive: false), 64 * 1024 * 1024);
      expect(config.cacheBytesFor(isLive: true), 16 * 1024 * 1024);
    });

    test('默认位置上报间隔约 4Hz', () {
      const config = PlayerConfig();

      expect(config.positionUpdateInterval, const Duration(milliseconds: 250));
    });

    test('未指定硬解链时回落到平台默认', () {
      const config = PlayerConfig();

      final chain = config.resolveHwdecChain();
      expect(chain.methods.last, HwdecMethod.none);
    });

    test('指定了硬解链就用指定的那条', () {
      final config = PlayerConfig(
        hwdec: HwdecChain.forPlatform(HwdecPlatform.linux),
      );

      expect(
        config.resolveHwdecChain(),
        HwdecChain.forPlatform(HwdecPlatform.linux),
      );
    });

    test('copyWith 只改指定字段', () {
      const config = PlayerConfig();
      final changed = config.copyWith(keepAudioPitch: false);

      expect(changed.keepAudioPitch, isFalse);
      expect(changed.vodCacheBytes, config.vodCacheBytes);
      expect(changed.logLevel, config.logLevel);
    });

    test('缓冲上限必须为正', () {
      var bytes = 1;
      bytes = 0;

      expect(
        () => PlayerConfig(vodCacheBytes: bytes),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
