import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

void main() {
  group('硬解是否真正生效', () {
    // docs/04 §3：hwdec-current 是排查卡顿的第一手信息。「请求了硬解」与
    // 「硬解真的在跑」经常不一致——请求 d3d11va 而 mpv 静默回落到软解，画面
    // 照样出，只是 CPU 烧满。
    test("hwdec-current 为 'no' 即软解", () {
      const info = MediaInfo(hwdecCurrent: 'no');

      expect(info.isHardwareDecoding, isFalse);
      expect(info.hwdecMethod, HwdecMethod.none);
    });

    test('具体后端名即硬解生效', () {
      const info = MediaInfo(hwdecCurrent: 'd3d11va-copy');

      expect(info.isHardwareDecoding, isTrue);
      expect(info.hwdecMethod, HwdecMethod.d3d11vaCopy);
    });

    test('还没探测出来时不算硬解', () {
      const info = MediaInfo.empty;

      expect(info.isHardwareDecoding, isFalse);
      expect(info.hwdecMethod, isNull);
    });

    test('认不出的后端名仍算硬解，且原样保留', () {
      const info = MediaInfo(hwdecCurrent: 'vulkan-copy');

      // 诊断信息里出现 vulkan-copy 至少还能搜，出现空白就什么都没有了。
      expect(info.isHardwareDecoding, isTrue);
      expect(info.hwdecMethod, isNull);
      expect(info.hwdecCurrent, 'vulkan-copy');
    });
  });

  group('HDR 判定', () {
    test('看传输函数而不是色域', () {
      // BT.2020 的 SDR 内容是存在的。
      const sdrWideGamut = MediaInfo(
        primaries: ColorPrimaries.bt2020,
        transfer: TransferFunction.bt1886,
      );
      expect(sdrWideGamut.isHdr, isFalse);

      const hdr10 = MediaInfo(
        primaries: ColorPrimaries.bt2020,
        transfer: TransferFunction.pq,
      );
      expect(hdr10.isHdr, isTrue);
    });

    test('HLG 也是 HDR', () {
      expect(TransferFunction.hlg.isHdr, isTrue);
      expect(TransferFunction.pq.isHdr, isTrue);
      expect(TransferFunction.srgb.isHdr, isFalse);
    });

    test('未知时不算 HDR', () {
      expect(MediaInfo.empty.isHdr, isFalse);
    });
  });

  group('mpv 取值反查', () {
    test('色域', () {
      expect(ColorPrimaries.fromMpvValue('bt.2020'), ColorPrimaries.bt2020);
      expect(ColorPrimaries.fromMpvValue('未知'), isNull);
    });

    test('传输函数', () {
      expect(TransferFunction.fromMpvValue('pq'), TransferFunction.pq);
      expect(TransferFunction.fromMpvValue('未知'), isNull);
    });

    test('取值互不重复', () {
      expect(
        ColorPrimaries.values.map((e) => e.mpvValue).toSet(),
        hasLength(ColorPrimaries.values.length),
      );
      expect(
        TransferFunction.values.map((e) => e.mpvValue).toSet(),
        hasLength(TransferFunction.values.length),
      );
    });
  });

  group('轨道筛选', () {
    final info = MediaInfo(
      tracks: [
        const Track(id: TrackId.auto, kind: TrackKind.video),
        Track(id: TrackId(1), kind: TrackKind.audio),
        Track(id: TrackId(2), kind: TrackKind.audio),
        Track(id: TrackId(3), kind: TrackKind.subtitle),
      ],
    );

    test('按类型筛出对应轨道', () {
      expect(info.tracksOf(TrackKind.audio), hasLength(2));
      expect(info.tracksOf(TrackKind.video), hasLength(1));
      expect(info.tracksOf(TrackKind.subtitle), hasLength(1));
    });
  });

  group('copyWith', () {
    test('只覆盖传入的字段', () {
      const info = MediaInfo(videoCodec: 'h264', width: 1920, height: 1080);
      final updated = info.copyWith(hwdecCurrent: 'd3d11va');

      expect(updated.videoCodec, 'h264');
      expect(updated.width, 1920);
      expect(updated.hwdecCurrent, 'd3d11va');
    });

    test('不支持把已知字段清回 null', () {
      // 媒体信息是逐步探测出来的，字段只会从 null 变成有值；反过来清空没有
      // 对应的真实事件。
      const info = MediaInfo(videoCodec: 'h264');

      expect(info.copyWith().videoCodec, 'h264');
    });
  });
}
