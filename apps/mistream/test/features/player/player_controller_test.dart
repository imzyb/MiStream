import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/features/player/player_controller.dart';
import 'package:player_engine/player_engine.dart';
import 'package:player_engine/testing.dart' show FakePlayerEngine;

/// 受控制的假时钟：测试自动隐藏判定时手动拨动时间。
class _FakeClock {
  _FakeClock(this.now);
  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

void main() {
  late FakePlayerEngine engine;
  late _FakeClock clock;
  late PlayerController controller;

  Future<void> initPlaying() async {
    await engine.initialize(const PlayerConfig());
    await engine.open(MediaSource(uri: Uri.parse('https://example.com/v.mp4')));
    controller.attach();
    // 让引擎进入稳定播放态。
    await pumpEventQueue();
  }

  setUp(() {
    engine = FakePlayerEngine();
    clock = _FakeClock(DateTime(2026));
    controller = PlayerController(engine: engine, clock: clock.call);
  });

  tearDown(() {
    controller.dispose();
  });

  group('attach 同步状态', () {
    test('订阅后立即拿到引擎初始状态', () async {
      controller.attach();
      expect(controller.state, PlayerState.idle);
      expect(controller.duration, Duration.zero);

      await engine.initialize(const PlayerConfig());
      await engine.open(MediaSource(uri: Uri.parse('https://e.com/v.mp4')));
      await pumpEventQueue();

      expect(controller.state, PlayerState.playing);
      expect(controller.duration, const Duration(minutes: 10));
      expect(controller.isPlaying, isTrue);
      expect(controller.isConnecting, isFalse);
    });

    test('attach 幂等：重复调用只订阅一次', () async {
      controller
        ..attach()
        ..attach();
      expect(controller.hasSubscribed, isTrue);
    });
  });

  group('shouldHideControls — docs/04 §10、docs/09 §5.5', () {
    test('播放中超过 3 秒无操作 → 该藏', () async {
      await initPlaying();
      controller.poke(); // 记一次交互
      expect(controller.shouldHideControls(clock.call()), isFalse);

      clock.advance(const Duration(seconds: 3));
      expect(controller.shouldHideControls(clock.call()), isTrue);

      controller.hideControls();
      expect(controller.isControlVisible, isFalse);
      // 已隐藏后不再「该藏」
      clock.advance(const Duration(seconds: 10));
      expect(controller.shouldHideControls(clock.call()), isFalse);
    });

    test('暂停时不隐藏', () async {
      await initPlaying();
      await controller.togglePlayPause();
      await pumpEventQueue();
      controller.poke();
      clock.advance(const Duration(minutes: 5));
      expect(controller.shouldHideControls(clock.call()), isFalse);
    });

    test('无媒体（idle）时不隐藏', () {
      controller.showControls();
      clock.advance(const Duration(minutes: 5));
      expect(controller.shouldHideControls(clock.call()), isFalse);
    });
  });

  group('命令转引擎调用', () {
    test('togglePlayPause 播放中→暂停', () async {
      await initPlaying();
      await controller.togglePlayPause();
      await pumpEventQueue();
      expect(engine.state, PlayerState.paused);
    });

    test('togglePlayPause 暂停→播放', () async {
      await initPlaying();
      await controller.togglePlayPause();
      await pumpEventQueue();
      await controller.togglePlayPause();
      await pumpEventQueue();
      expect(engine.state, PlayerState.playing);
    });

    test('seekTo 超出时长被钳制', () async {
      await initPlaying();
      await controller.seekTo(const Duration(minutes: 99));
      await pumpEventQueue();
      expect(engine.position, const Duration(minutes: 10));
    });

    test('adjustVolumeBy 越界钳制到 [0, maxVolume]', () async {
      await initPlaying();
      await controller.adjustVolumeBy(100);
      await pumpEventQueue();
      expect(engine.volume, PlayerEngine.maxVolume);

      await controller.adjustVolumeBy(-100);
      await pumpEventQueue();
      expect(engine.volume, 0);
    });
  });

  group('notice — 非致命事件（硬解降级）', () {
    test('非致命错误存入 notice，不进 fatalError', () async {
      await initPlaying();
      engine.emitError(PlayerError.hwdecFallback(from: 'd3d11va', to: 'no'));
      await pumpEventQueue();
      expect(controller.fatalError, isNull);
      expect(controller.notice, isNotNull);
      expect(controller.notice!.code, ErrorCode.playerHwdecFallback);
      expect(controller.isPlaying, isTrue); // 播放不被打断
    });

    test('consumeNotice 清空 hint', () async {
      await initPlaying();
      engine.emitError(PlayerError.hwdecFallback(from: 'd3d11va', to: 'no'));
      await pumpEventQueue();
      controller.consumeNotice();
      expect(controller.notice, isNull);
    });

    test('致命错误仍进 fatalError 且 State 转 error', () async {
      await initPlaying();
      engine.emitError(
        const PlayerError(
          error: LocalError(
            code: ErrorCode.playerOpenFailed,
            message: 'open failed',
          ),
        ),
      );
      await pumpEventQueue();
      expect(controller.fatalError, isNotNull);
      expect(controller.notice, isNull);
      expect(controller.state, PlayerState.error);
    });
  });
}

/// 让异步流事件都派发完。
Future<void> pumpEventQueue() => Future<void>.delayed(Duration.zero);
