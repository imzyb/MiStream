/// [PlayerEngine] 的契约测试套件。
///
/// 每个实现都要跑同一套用例——这是 [ADR-004] 里「抽象层没有泄漏的唯一可验证
/// 证据」。M1 阶段由 `FakePlayerEngine` 跑，M1-b 起 `MediaKitEngine` 复用，
/// M15 的 `NativeMpvEngine` 再复用一次。
///
/// 套件放在 `test/` 而不是 `lib/`：两个实现按 `docs/04-播放器设计.md` §2 都
/// 住在本包内，同包的测试目录已经能共享，没必要为此让 `package:test` 变成
/// 生产依赖。
///
/// 用例只断言**与实现无关**的行为。凡是需要真实媒体才能验的（硬解是否生效、
/// HLS 能否起播、2 小时不涨内存），都属于 M1 出口标准里的手工验证项，不在
/// 这里。
///
/// [ADR-004]: ../../../../docs/adr/004-播放器分两期实现.md
library;

import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

/// 对 [createEngine] 造出的实现跑整套契约。
///
/// [createSource] 要返回一个该实现确实能打开的媒体；假引擎随便给，真引擎要
/// 给一个本地样本文件。[label] 只用于测试名。
void runPlayerEngineContract({
  required String label,
  required PlayerEngine Function() createEngine,
  required MediaSource Function() createSource,
}) {
  group('$label 契约', () {
    late PlayerEngine engine;

    setUp(() => engine = createEngine());
    tearDown(() => engine.dispose());

    Future<void> initialize() async {
      final result = await engine.initialize(const PlayerConfig());
      expect(result.isOk, isTrue, reason: 'initialize 应当成功');
    }

    Future<void> openMedia() async {
      await initialize();
      final result = await engine.open(createSource());
      expect(result.isOk, isTrue, reason: 'open 应当成功');
    }

    // 真引擎的状态是事件驱动、异步到达的：open 后状态不会立刻定型。
    // 契约只断言「最终能到达的目标状态」，用轮询等它到位；假引擎同步定量，
    // 首轮即命中，同一套用例照样通过。
    Future<void> waitForState(PlayerState target) async {
      for (var i = 0; i < 200 && engine.state != target; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(engine.state, target);
    }

    group('调用顺序纪律', () {
      test('未 initialize 就 open 抛 StateError', () {
        expect(() => engine.open(createSource()), throwsStateError);
      });

      test('未 open 就 play / pause / seek 抛 StateError', () async {
        await initialize();
        expect(engine.play, throwsStateError);
        expect(engine.pause, throwsStateError);
        expect(() => engine.seek(Duration.zero), throwsStateError);
      });

      test('dispose 之后任何调用都抛 StateError', () async {
        await initialize();
        await engine.dispose();

        expect(engine.isDisposed, isTrue);
        expect(
          () => engine.initialize(const PlayerConfig()),
          throwsStateError,
        );
        expect(() => engine.open(createSource()), throwsStateError);
      });

      test('dispose 幂等', () async {
        await initialize();
        await engine.dispose();
        await expectLater(engine.dispose(), completes);
      });
    });

    group('状态机', () {
      test('初始为 idle', () async {
        await initialize();
        expect(engine.state, PlayerState.idle);
      });

      test('open 成功后进入播放态', () async {
        await openMedia();
        expect(engine.state, PlayerState.playing);
        expect(engine.state.hasMedia, isTrue);
      });

      test('open 过程中经过 opening', () async {
        await initialize();
        final seen = <PlayerState>[];
        final subscription = engine.stateStream.listen(seen.add);

        await engine.open(createSource());
        // 等事件真的进入校验序列，而不是等 snapshot —— 快照先到、流还在投递，
        // 抢跑取 cancel 会把 playing 事件弄丢。观察 on the `seen` 本身即断言目标。
        for (var i = 0; i < 200 && !seen.contains(PlayerState.playing); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await subscription.cancel();

        expect(seen, contains(PlayerState.opening));
        expect(seen, contains(PlayerState.playing));
      });

      test('pause 与 play 之间可往返', () async {
        await openMedia();

        await engine.pause();
        expect(engine.state, PlayerState.paused);

        await engine.play();
        expect(engine.state, PlayerState.playing);
      });

      test('play 与 pause 幂等', () async {
        await openMedia();

        await engine.play();
        await engine.play();
        expect(engine.state, PlayerState.playing);

        await engine.pause();
        await engine.pause();
        expect(engine.state, PlayerState.paused);
      });

      test('close 回到 idle 并清空媒体信息', () async {
        await openMedia();
        await engine.close();

        expect(engine.state, PlayerState.idle);
        expect(engine.position, Duration.zero);
        expect(engine.mediaInfo.tracks, isEmpty);
      });
    });

    group('传输控制', () {
      test('seek 被钳制到 [0, duration]', () async {
        await openMedia();
        final duration = engine.duration;

        await engine.seek(const Duration(days: -1));
        expect(engine.position, Duration.zero);

        if (duration > Duration.zero) {
          await engine.seek(duration * 2);
          expect(engine.position, duration);
        }
      });

      test('倍速越界抛 ArgumentError', () async {
        await openMedia();

        expect(
          () => engine.setRate(PlayerEngine.minRate / 2),
          throwsArgumentError,
        );
        expect(
          () => engine.setRate(PlayerEngine.maxRate * 2),
          throwsArgumentError,
        );
      });

      test('倍速边界值可用', () async {
        await openMedia();

        await engine.setRate(PlayerEngine.minRate);
        expect(engine.rate, PlayerEngine.minRate);

        await engine.setRate(PlayerEngine.maxRate);
        expect(engine.rate, PlayerEngine.maxRate);
      });
    });

    group('音量', () {
      test('越界被钳制而不是抛异常', () async {
        await openMedia();

        await engine.setVolume(-1);
        expect(engine.volume, 0);

        await engine.setVolume(99);
        expect(engine.volume, PlayerEngine.maxVolume);
      });

      test('静音不改变音量值', () async {
        await openMedia();
        await engine.setVolume(0.7);

        await engine.setMuted(muted: true);
        expect(engine.isMuted, isTrue);
        expect(engine.volume, closeTo(0.7, 1e-9));

        await engine.setMuted(muted: false);
        expect(engine.isMuted, isFalse);
      });
    });

    group('轨道', () {
      test('可以关闭字幕', () async {
        await openMedia();
        await engine.selectSubtitleTrack(TrackId.disabled);

        final subtitles = engine.mediaInfo.tracksOf(TrackKind.subtitle);
        expect(subtitles.where((t) => t.isSelected), isEmpty);
      });

      test('选中的轨道在 mediaInfo 里被标记', () async {
        await openMedia();
        final audio = engine.mediaInfo.tracksOf(TrackKind.audio);
        if (audio.isEmpty) return;

        await engine.selectAudioTrack(audio.first.id);
        final selected = engine.mediaInfo
            .tracksOf(TrackKind.audio)
            .where((t) => t.isSelected);
        expect(selected, hasLength(1));
      });

      test('字幕与音频延迟可设置', () async {
        await openMedia();
        await expectLater(
          engine.setSubtitleDelay(const Duration(milliseconds: 200)),
          completes,
        );
        await expectLater(
          engine.setAudioDelay(const Duration(milliseconds: -200)),
          completes,
        );
      });
    });

    group('流语义', () {
      test('迟到的订阅者立即收到当前值', () async {
        await openMedia();

        await expectLater(
          engine.stateStream.first,
          completion(engine.state),
        );
        await expectLater(
          engine.positionStream.first,
          completion(engine.position),
        );
        await expectLater(
          engine.mediaInfoStream.first.then((i) => i.tracks.length),
          completion(engine.mediaInfo.tracks.length),
        );
      });

      test('同一条流可被多次订阅', () async {
        await openMedia();
        await waitForState(PlayerState.playing);

        final stream = engine.stateStream;
        // 订阅时补发的值是「此时」的当前值；两次订阅拿到的都是同一刻快照。
        final first = stream.first;
        final second = stream.first;

        final received = await Future.wait([first, second]);
        expect(received, hasLength(2));
        expect(received[0], same(received[1]));
      });

      test('position 随 seek 推进且不倒退到负值', () async {
        await openMedia();
        if (engine.duration == Duration.zero) return;

        final target = engine.duration ~/ 2;
        await engine.seek(target);
        expect(engine.position, target);
        expect(engine.position, greaterThanOrEqualTo(Duration.zero));
      });

      test('dispose 关闭全部流', () async {
        await openMedia();

        final states = engine.stateStream.toList();
        final logs = engine.logStream.toList();
        final errors = engine.errorStream.toList();

        await engine.dispose();

        await expectLater(states, completes);
        await expectLater(logs, completes);
        await expectLater(errors, completes);
      });
    });

    group('截图', () {
      test('没有媒体时返回 Err 而不是抛异常', () async {
        await initialize();
        final result = await engine.screenshot();
        expect(result.isErr, isTrue);
      });
    });
  });
}
