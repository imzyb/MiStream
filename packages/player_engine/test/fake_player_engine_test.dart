import 'package:core_domain/core_domain.dart';
import 'package:player_engine/player_engine.dart';
import 'package:player_engine/testing.dart';
import 'package:test/test.dart';

void main() {
  late FakePlayerEngine engine;

  setUp(() => engine = FakePlayerEngine());
  tearDown(() => engine.dispose());

  Future<void> open() async {
    await engine.initialize(const PlayerConfig());
    await engine.open(MediaSource(uri: Uri.parse('https://e.com/a.mp4')));
  }

  group('可编程的失败', () {
    test('failNextOpen 只作用一次', () async {
      await engine.initialize(const PlayerConfig());
      engine.failNextOpen(
        const LocalError(
          code: ErrorCode.playerOpenFailed,
          message: '第一个候选打不开',
        ),
      );

      final first = await engine.open(
        MediaSource(uri: Uri.parse('https://e.com/1.mp4')),
      );
      expect(first.isErr, isTrue);
      expect(first.errorOrNull?.code, ErrorCode.playerOpenFailed);
      expect(engine.state, PlayerState.error);

      // 回退链的下一个候选必须还能起来，否则用例退化成「全都失败」。
      final second = await engine.open(
        MediaSource(uri: Uri.parse('https://e.com/2.mp4')),
      );
      expect(second.isOk, isTrue);
      expect(engine.state, PlayerState.playing);
    });

    test('failNextInitialize 让 initialize 返回 Err', () async {
      engine.failNextInitialize(
        const LocalError(
          code: ErrorCode.playerLibmpvMissing,
          message: '找不到 libmpv',
        ),
      );

      final result = await engine.initialize(const PlayerConfig());
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.playerLibmpvMissing);
    });

    test('open 失败时向 errorStream 发一条致命错误', () async {
      await engine.initialize(const PlayerConfig());
      final errors = <PlayerError>[];
      final subscription = engine.errorStream.listen(errors.add);

      engine.failNextOpen(
        const LocalError(code: ErrorCode.playerOpenFailed, message: '403'),
      );
      await engine.open(MediaSource(uri: Uri.parse('https://e.com/x.mp4')));
      await pumpEventQueue();
      await subscription.cancel();

      expect(errors, hasLength(1));
      expect(errors.single.isFatal, isTrue);
      expect(errors.single.code, ErrorCode.playerOpenFailed);
    });
  });

  group('时间推进', () {
    test('advance 推进位置', () async {
      await open();
      engine.advance(const Duration(minutes: 1));
      expect(engine.position, const Duration(minutes: 1));
    });

    test('推进到时长即进入 ended', () async {
      await open();
      engine.advance(const Duration(hours: 1));

      expect(engine.state, PlayerState.ended);
      expect(engine.state.isTerminal, isTrue);
      expect(engine.position, engine.duration);
    });

    test('ended 之后 seek 回去能继续播', () async {
      await open();
      engine.advance(const Duration(hours: 1));
      expect(engine.state, PlayerState.ended);

      await engine.seek(const Duration(minutes: 1));
      expect(engine.state, PlayerState.playing);
    });

    test('ended 状态下 play 不改变状态', () async {
      await open();
      engine.advance(const Duration(hours: 1));

      await engine.play();
      expect(engine.state, PlayerState.ended);
    });
  });

  group('降级事件', () {
    test('非致命错误不改变播放状态', () async {
      await open();
      final errors = <PlayerError>[];
      final subscription = engine.errorStream.listen(errors.add);

      engine.emitError(
        PlayerError.hwdecFallback(from: 'd3d11va', to: 'no'),
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(engine.state, PlayerState.playing);
      expect(errors.single.isFatal, isFalse);
      expect(errors.single.code, ErrorCode.playerHwdecFallback);
      expect(errors.single.error.detail['from'], 'd3d11va');
    });

    test('致命错误把状态推到 error', () async {
      await open();
      engine.emitError(
        const PlayerError(
          error: LocalError(
            code: ErrorCode.playerUnsupportedFormat,
            message: '不支持的编码',
          ),
        ),
      );

      expect(engine.state, PlayerState.error);
    });
  });

  group('外挂字幕', () {
    test('加载后进入列表并被选中', () async {
      await open();
      final uri = Uri.parse('file:///subs/a.srt');

      final result = await engine.addExternalSubtitle(uri);
      expect(result.isOk, isTrue);
      expect(engine.externalSubtitles, [uri]);
      expect(engine.subtitleTrack.number, 1);
    });

    test('select 为 false 时不改变当前字幕轨', () async {
      await open();
      final before = engine.subtitleTrack;

      await engine.addExternalSubtitle(
        Uri.parse('file:///subs/b.srt'),
        select: false,
      );
      expect(engine.subtitleTrack, before);
    });

    test('空地址返回字幕加载失败', () async {
      await open();
      final result = await engine.addExternalSubtitle(Uri());

      expect(result.isErr, isTrue);
      expect(
        result.errorOrNull?.code,
        ErrorCode.playerSubtitleLoadFailed,
      );
    });
  });

  group('直播源', () {
    test('直播没有时长', () async {
      await engine.initialize(const PlayerConfig());
      await engine.open(
        MediaSource(uri: Uri.parse('https://e.com/live.m3u8'), isLive: true),
      );

      expect(engine.duration, Duration.zero);
      expect(engine.mediaInfo.duration, isNull);
    });
  });

  group('起播位置', () {
    test('startAt 生效', () async {
      await engine.initialize(const PlayerConfig());
      await engine.open(
        MediaSource(uri: Uri.parse('https://e.com/a.mp4')),
        startAt: const Duration(minutes: 3),
      );

      expect(engine.position, const Duration(minutes: 3));
    });

    test('startAt 超出时长被钳制', () async {
      await engine.initialize(const PlayerConfig());
      await engine.open(
        MediaSource(uri: Uri.parse('https://e.com/a.mp4')),
        startAt: const Duration(days: 1),
      );

      expect(engine.position, engine.duration);
    });
  });

  group('画面设置', () {
    test('比例与滤镜被记住', () async {
      await open();

      await engine.setAspectRatio(const AspectRatioMode.ratio(4, 3));
      await engine.setVideoFilter(
        const VideoFilterSettings(brightness: 10),
      );

      expect(engine.aspectRatio, const AspectRatioMode.ratio(4, 3));
      expect(engine.videoFilter.brightness, 10);
      expect(engine.videoFilter.isNeutral, isFalse);
    });
  });

  group('截图', () {
    test('有媒体时返回 PNG magic number', () async {
      await open();
      final result = await engine.screenshot();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.take(4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}
