/// media_kit 纯映射（`media_kit_mapping.dart`）与共享的 `ValueStream` 的测试。
///
/// 这些是 `MediaKitEngine` 里唯一能脱离 libmpv 直接测的部分——轨道表、状态机、
/// 媒体信息的换算全部是纯函数。真实打开媒体的那部分（[M1 出口标准]里的手工验收
/// 项）不在 `dart test` 里跑。
///
/// [M1 出口标准]: ../../../ROADMAP.md
library;

import 'package:media_kit/media_kit.dart' as mk;
import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

void main() {
  group('deriveState', () {
    test('没有媒体时无论信号如何都回 idle', () {
      expect(
        deriveState(
          hasMedia: false,
          playing: true,
          buffering: true,
          completed: true,
        ),
        PlayerState.idle,
      );
    });

    test('ended 优先于 playing 与 buffering', () {
      expect(
        deriveState(
          hasMedia: true,
          playing: true,
          buffering: true,
          completed: true,
        ),
        PlayerState.ended,
      );
    });

    test('buffering 优先于 playing', () {
      expect(
        deriveState(
          hasMedia: true,
          playing: true,
          buffering: true,
          completed: false,
        ),
        PlayerState.buffering,
      );
    });

    test('playing 为真即播放', () {
      expect(
        deriveState(
          hasMedia: true,
          playing: true,
          buffering: false,
          completed: false,
        ),
        PlayerState.playing,
      );
    });

    test('有媒体但不播放不缓冲视为暂停', () {
      expect(
        deriveState(
          hasMedia: true,
          playing: false,
          buffering: false,
          completed: false,
        ),
        PlayerState.paused,
      );
    });
  });

  group('mapTracks', () {
    test('剔除 auto 与 no 两行伪轨道', () {
      final tracks = mapTracks(
        const mk.Tracks(
          video: [
            mk.VideoTrack('auto', null, null),
            mk.VideoTrack('no', null, null),
            mk.VideoTrack('1', '主视频', 'zh', codec: 'h264'),
          ],
        ),
        const mk.Track(
          video: mk.VideoTrack('1', null, null),
        ),
      );

      expect(tracks, hasLength(1));
      expect(tracks.single.kind, TrackKind.video);
      expect(tracks.single.id, TrackId(1));
      expect(tracks.single.isSelected, isTrue);
    });

    test('选中状态按 id 对齐，可记录 auto 选中', () {
      final tracks = mapTracks(
        const mk.Tracks(
          audio: [
            mk.AudioTrack('auto', null, null),
            mk.AudioTrack('no', null, null),
            mk.AudioTrack('1', null, 'zh'),
            mk.AudioTrack('2', null, 'en'),
          ],
        ),
        const mk.Track(
          audio: mk.AudioTrack('2', null, null),
        ),
      );

      final audio = tracks.where((t) => t.kind == TrackKind.audio);
      expect(audio, hasLength(2));
      expect(audio.firstWhere((t) => t.id == TrackId(2)).isSelected, isTrue);
    });
  });

  group('toMediaKitMedia', () {
    test('头为空时不带 httpHeaders', () {
      final media = toMediaKitMedia(
        MediaSource(uri: Uri.parse('https://example.com/v.mp4')),
      );
      expect(media.uri, 'https://example.com/v.mp4');
      expect(media.httpHeaders, isNull);
    });

    test('头原样透传', () {
      const headers = {'User-Agent': 'xx', 'Referer': 'https://r/'};
      final media = toMediaKitMedia(
        MediaSource(
          uri: Uri.parse('https://example.com/v.mp4'),
          headers: headers,
        ),
      );
      expect(media.httpHeaders, headers);
    });

    test('startAt 映射到 start', () {
      final media = toMediaKitMedia(
        MediaSource(uri: Uri.parse('https://example.com/v.mp4')),
        startAt: const Duration(seconds: 30),
      );
      expect(media.start, const Duration(seconds: 30));
    });
  });

  group('trackIdFromMpv', () {
    test('auto 与 no 各有语义', () {
      expect(trackIdFromMpv('auto'), TrackId.auto);
      expect(trackIdFromMpv('no'), TrackId.disabled);
    });

    test('数字映射为轨道号', () {
      expect(trackIdFromMpv('7'), TrackId(7));
    });

    test('认不出的取值回落到 auto 而不是崩', () {
      expect(trackIdFromMpv('garbage'), TrackId.auto);
    });
  });

  group('mpvTrackId', () {
    test('与 TrackId 互为反向', () {
      expect(mpvTrackId(TrackId.auto), 'auto');
      expect(mpvTrackId(TrackId.disabled), 'no');
      expect(mpvTrackId(TrackId(3)), '3');
    });
  });

  group('mergeMediaInfo', () {
    test('只覆盖传入的字段', () {
      final info = mergeMediaInfo(
        info: const MediaInfo(videoCodec: 'h264', width: 1920),
        height: 1080,
        duration: const Duration(seconds: 60),
      );
      expect(info.videoCodec, 'h264');
      expect(info.width, 1920);
      expect(info.height, 1080);
      expect(info.duration, const Duration(seconds: 60));
    });

    test('多次调用增量合并', () {
      final first = mergeMediaInfo(
        info: MediaInfo.empty,
        width: 1920,
        height: 1080,
      );
      final second = mergeMediaInfo(
        info: first,
        duration: const Duration(seconds: 90),
      );
      expect(second.width, 1920);
      expect(second.height, 1080);
      expect(second.duration, const Duration(seconds: 90));
    });
  });

  group('colorInfoFrom', () {
    test('色域与传输函数从字符串反查', () {
      final info = colorInfoFrom(
        const mk.VideoParams(primaries: 'bt.2020', gamma: 'pq'),
      );
      expect(info.primaries, ColorPrimaries.bt2020);
      expect(info.transfer, TransferFunction.pq);
    });

    test('认不出的取值回 null', () {
      final info = colorInfoFrom(
        const mk.VideoParams(
          primaries: 'future-primaries',
          gamma: 'future-gamma',
        ),
      );
      expect(info.primaries, isNull);
      expect(info.transfer, isNull);
    });
  });

  group('codecOf', () {
    test('取当前选中轨的编码', () {
      const selected = mk.Track(
        video: mk.VideoTrack('1', null, null, codec: 'hevc'),
        audio: mk.AudioTrack('1', null, null, codec: 'aac'),
      );
      expect(codecOf(selected, TrackKind.video), 'hevc');
      expect(codecOf(selected, TrackKind.audio), 'aac');
    });
  });

  group('ValueStream', () {
    test('订阅即收到当前值', () async {
      final stream = ValueStream<int>(0)..emit(42);
      await expectLater(stream.stream.first, completion(42));
    });

    test('emitIfChanged 值不变时不推送', () async {
      final vs = ValueStream<int>(1);
      final events = <int>[];
      final sub = vs.stream.listen(events.add);
      vs
        ..emitIfChanged(1)
        ..emitIfChanged(2);
      await pumpEventQueue();
      await sub.cancel();

      expect(events, [1, 2]);
    });

    test('多路订阅各自收到', () async {
      final vs = ValueStream<int>(5);
      final a = vs.stream.first;
      final b = vs.stream.first;
      await expectLater(a, completion(5));
      await expectLater(b, completion(5));
    });
  });
}
