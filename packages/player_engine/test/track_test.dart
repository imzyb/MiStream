import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

void main() {
  group('TrackId', () {
    test('轨道号从 1 开始', () {
      expect(TrackId(1).mpvValue, '1');
      expect(TrackId(3).number, 3);
    });

    test('小于 1 的轨道号被拒', () {
      expect(() => TrackId(0), throwsArgumentError);
      expect(() => TrackId(-1), throwsArgumentError);
    });

    test('auto 与 disabled 有 mpv 语义而不是下标', () {
      expect(TrackId.auto.mpvValue, 'auto');
      expect(TrackId.disabled.mpvValue, 'no');
      expect(TrackId.auto.number, isNull);
      expect(TrackId.disabled.number, isNull);
      expect(TrackId.auto.isAuto, isTrue);
      expect(TrackId.disabled.isDisabled, isTrue);
    });

    test('按取值比较', () {
      expect(TrackId(2), TrackId(2));
      expect(TrackId(2).hashCode, TrackId(2).hashCode);
      expect(TrackId(2), isNot(TrackId(3)));
      expect(TrackId.auto, isNot(TrackId.disabled));
    });
  });

  group('TrackKind', () {
    test('各自对应一个 mpv 属性', () {
      expect(TrackKind.video.mpvProperty, 'vid');
      expect(TrackKind.audio.mpvProperty, 'aid');
      expect(TrackKind.subtitle.mpvProperty, 'sid');
    });
  });

  group('Track.displayName', () {
    test('优先用标题', () {
      const track = Track(
        id: TrackId.auto,
        kind: TrackKind.audio,
        title: '国语',
        language: 'zh',
        codec: 'aac',
      );

      expect(track.displayName, '国语');
    });

    test('没有标题时退到语言', () {
      const track = Track(
        id: TrackId.auto,
        kind: TrackKind.audio,
        language: 'ja',
        codec: 'aac',
      );

      expect(track.displayName, 'ja');
    });

    test('只剩编码时用编码', () {
      const track = Track(
        id: TrackId.auto,
        kind: TrackKind.audio,
        codec: 'flac',
      );

      expect(track.displayName, 'flac');
    });

    test('什么都没有也不会是空白', () {
      final track = Track(id: TrackId(2), kind: TrackKind.subtitle);

      expect(track.displayName, '轨道 2');
      expect(track.displayName.trim(), isNotEmpty);
    });
  });
}
