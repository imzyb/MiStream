/// 当前媒体的技术信息。
library;

import 'package:meta/meta.dart';
import 'package:player_engine/src/hwdec.dart';
import 'package:player_engine/src/track.dart';

/// 色域（色彩原色）。
///
/// 对应 mpv 的 `video-params/primaries`。
enum ColorPrimaries {
  /// BT.709，绝大多数 SDR 内容。
  bt709('bt.709'),

  /// BT.2020，HDR 内容常用。
  bt2020('bt.2020'),

  /// BT.601（525 行，NTSC 系）。
  bt601525('bt.601-525'),

  /// BT.601（625 行，PAL 系）。
  bt601625('bt.601-625'),

  /// DCI-P3。
  dciP3('dci-p3'),

  /// 展示用 P3。
  displayP3('display-p3');

  const ColorPrimaries(this.mpvValue);

  /// mpv 属性取值。
  final String mpvValue;

  /// 按 mpv 取值反查，认不出返回 `null`。
  static ColorPrimaries? fromMpvValue(String value) {
    for (final item in ColorPrimaries.values) {
      if (item.mpvValue == value) return item;
    }
    return null;
  }
}

/// 传输函数（gamma 曲线）。
///
/// 对应 mpv 的 `video-params/gamma`。HDR 判定看的就是这个字段而不是色域：
/// BT.2020 的 SDR 内容是存在的，而 [pq] 与 [hlg] 才是 HDR 的充分条件。
enum TransferFunction {
  /// BT.1886，标准 SDR。
  bt1886('bt.1886'),

  /// sRGB。
  srgb('srgb'),

  /// PQ（SMPTE ST 2084），HDR10 用。
  pq('pq'),

  /// HLG（Hybrid Log-Gamma）。
  hlg('hlg'),

  /// 线性光。
  linear('linear');

  const TransferFunction(this.mpvValue);

  /// mpv 属性取值。
  final String mpvValue;

  /// 是否是 HDR 传输函数。
  bool get isHdr => this == TransferFunction.pq || this == TransferFunction.hlg;

  /// 按 mpv 取值反查，认不出返回 `null`。
  static TransferFunction? fromMpvValue(String value) {
    for (final item in TransferFunction.values) {
      if (item.mpvValue == value) return item;
    }
    return null;
  }
}

/// 当前媒体的技术信息，供「播放信息」浮层与诊断报告使用。
///
/// 字段直接对应 mpv 属性（`video-codec`、`width`、`container-fps`、
/// `video-bitrate`、`hwdec-current`、`video-params/*`），不做归并。
/// `docs/04-播放器设计.md` §3 特别要求暴露 [hwdecCurrent]——**硬解是否真正
/// 生效**是排查卡顿的第一手信息，而它与「请求了什么硬解方式」经常不一致：
/// 请求 `d3d11va` 而 mpv 静默回落到软解，画面照样出，只是 CPU 烧满。
@immutable
final class MediaInfo {
  /// 构造一份媒体信息。
  const MediaInfo({
    this.videoCodec,
    this.audioCodec,
    this.width,
    this.height,
    this.frameRate,
    this.videoBitrate,
    this.audioBitrate,
    this.primaries,
    this.transfer,
    this.hwdecCurrent,
    this.duration,
    this.tracks = const [],
  });

  /// 空信息，尚未探测出任何内容时的初值。
  static const empty = MediaInfo();

  /// 视频编码名，如 `h264`、`hevc`、`av1`。
  final String? videoCodec;

  /// 音频编码名。
  final String? audioCodec;

  /// 画面宽度（像素）。
  final int? width;

  /// 画面高度（像素）。
  final int? height;

  /// 帧率。
  final double? frameRate;

  /// 视频码率（bit/s）。
  final int? videoBitrate;

  /// 音频码率（bit/s）。
  final int? audioBitrate;

  /// 色域。
  final ColorPrimaries? primaries;

  /// 传输函数。
  final TransferFunction? transfer;

  /// mpv `hwdec-current` 的原始取值。
  ///
  /// 保留字符串而不是只存 [HwdecMethod]：mpv 可能给出我们还没收录的后端名，
  /// 那种情况下「显示一个我们不认识的名字」远好过「显示 null」——诊断信息
  /// 里出现 `vulkan-copy` 至少还能搜，出现空白就什么都没有了。
  final String? hwdecCurrent;

  /// 时长；直播流为 `null`。
  final Duration? duration;

  /// 全部轨道。
  final List<Track> tracks;

  /// 硬解是否真正生效。
  bool get isHardwareDecoding =>
      hwdecCurrent != null &&
      hwdecCurrent != HwdecMethod.none.mpvValue &&
      hwdecCurrent!.isNotEmpty;

  /// [hwdecCurrent] 对应的已知档位；认不出为 `null`。
  HwdecMethod? get hwdecMethod {
    final value = hwdecCurrent;
    return value == null ? null : HwdecMethod.fromMpvValue(value);
  }

  /// 是否是 HDR 内容。
  bool get isHdr => transfer?.isHdr ?? false;

  /// 按类型筛轨道。
  List<Track> tracksOf(TrackKind kind) =>
      tracks.where((t) => t.kind == kind).toList(growable: false);

  /// 复制并覆盖部分字段。
  ///
  /// 参数全部可空且**不支持置回 null**：媒体信息是逐步探测出来的，探测到的
  /// 字段只会从 null 变成有值，反过来把已知字段清空没有对应的真实事件。
  MediaInfo copyWith({
    String? videoCodec,
    String? audioCodec,
    int? width,
    int? height,
    double? frameRate,
    int? videoBitrate,
    int? audioBitrate,
    ColorPrimaries? primaries,
    TransferFunction? transfer,
    String? hwdecCurrent,
    Duration? duration,
    List<Track>? tracks,
  }) => MediaInfo(
    videoCodec: videoCodec ?? this.videoCodec,
    audioCodec: audioCodec ?? this.audioCodec,
    width: width ?? this.width,
    height: height ?? this.height,
    frameRate: frameRate ?? this.frameRate,
    videoBitrate: videoBitrate ?? this.videoBitrate,
    audioBitrate: audioBitrate ?? this.audioBitrate,
    primaries: primaries ?? this.primaries,
    transfer: transfer ?? this.transfer,
    hwdecCurrent: hwdecCurrent ?? this.hwdecCurrent,
    duration: duration ?? this.duration,
    tracks: tracks ?? this.tracks,
  );

  @override
  String toString() =>
      'MediaInfo($videoCodec ${width}x$height '
      'hwdec=${hwdecCurrent ?? '-'})';
}
