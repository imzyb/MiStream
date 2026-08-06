/// media_kit 与我们领域模型的纯映射逻辑。
///
/// 单独一个文件、全部纯函数，不碰 `Player`、不碰 libmpv：轨道表、状态机、
/// 媒体信息的换算可以被 `dart test` 直接测，不需要机器上有 libmpv DLL。
/// `MediaKitEngine` 只负责把它们接到真实事件流上。
///
/// 命名约定：media_kit 的类型统一加 `mk` 前缀（`mk.Tracks`、`mk.Track`、
/// `mk.VideoParams`），与 `player_engine` 的 `Track` / `PlayerState` 区分开。
library;

import 'package:media_kit/media_kit.dart' as mk;
import 'package:player_engine/src/media_info.dart';
import 'package:player_engine/src/media_source.dart';
import 'package:player_engine/src/player_state.dart';
import 'package:player_engine/src/track.dart';

/// 把 [source] 映射为 media_kit 的 [mk.Media]。
///
/// `headers` 原样交给 media_kit，由它在 `on_load` 钩子里写成
/// `http-header-fields`——这是 `docs/04-播放器设计.md` §6「请求头透传」的落点，
/// UA / Referer / Cookie 一个都不能少。
mk.Media toMediaKitMedia(MediaSource source, {Duration? startAt}) {
  return mk.Media(
    source.uri.toString(),
    httpHeaders: source.headers.isEmpty ? null : Map.of(source.headers),
    start: startAt,
  );
}

/// 从 media_kit 的三个布尔信号推导 [PlayerState]。
///
/// [hasMedia] 为假时无论信号如何都回 [PlayerState.idle]——`dispose` 之后
/// 内核还可能发来一两个尾巴事件，不该把已关闭的引擎又拖回某个状态。
///
/// 优先级：结束时 [PlayerState.ended] 优先于一切（mpv 停在结尾时
/// `playing` 与 `buffering` 都可能短暂为真，不能先被它们抢走）；其次是缓冲；
/// `playing == true` 时是播放；其余有媒体的场景一律视为暂停——media_kit 没有
/// 单独的「暂停」信号，暂停在它那里就是 `playing == false`。
PlayerState deriveState({
  required bool hasMedia,
  required bool playing,
  required bool buffering,
  required bool completed,
}) {
  if (!hasMedia) return PlayerState.idle;
  if (completed) return PlayerState.ended;
  if (buffering) return PlayerState.buffering;
  if (playing) return PlayerState.playing;
  return PlayerState.paused;
}

/// 把 media_kit 的轨道表映射成我们的 [Track] 列表。
///
/// media_kit 的轨道列表头部固定有两行伪轨道：`auto` 与 `no`。它们是「选择
/// 操作」而不是真实存在的媒体轨道，写进 [MediaInfo.tracks] 会让 UI 的下拉菜单
/// 出现两行无法理解的选项（「轨道 0」）。这里剔除它们；选中状态仍按 id 对齐。
List<Track> mapTracks(mk.Tracks mkTracks, mk.Track mkSelected) {
  return [
    ..._mapKind(
      mkTracks.video,
      TrackKind.video,
      mkSelected.video.id,
      (t) => (
        id: t.id,
        title: t.title,
        language: t.language,
        codec: t.codec,
        isDefault: t.isDefault,
      ),
    ),
    ..._mapKind(
      mkTracks.audio,
      TrackKind.audio,
      mkSelected.audio.id,
      (t) => (
        id: t.id,
        title: t.title,
        language: t.language,
        codec: t.codec,
        isDefault: t.isDefault,
      ),
    ),
    ..._mapKind(
      mkTracks.subtitle,
      TrackKind.subtitle,
      mkSelected.subtitle.id,
      (t) => (
        id: t.id,
        title: t.title,
        language: t.language,
        codec: t.codec,
        isDefault: t.isDefault,
      ),
    ),
  ];
}

typedef _TrackFields = ({
  String id,
  String? title,
  String? language,
  String? codec,
  bool? isDefault,
});

List<Track> _mapKind<T>(
  List<T> tracks,
  TrackKind kind,
  String selectedId,
  _TrackFields Function(T track) fields,
) {
  final result = <Track>[];
  for (final t in tracks) {
    final f = fields(t);
    if (f.id == 'auto' || f.id == 'no') continue;
    result.add(
      Track(
        id: trackIdFromMpv(f.id),
        kind: kind,
        title: f.title,
        language: f.language,
        codec: f.codec,
        isDefault: f.isDefault ?? false,
        isSelected: f.id == selectedId,
      ),
    );
  }
  return result;
}

/// 把 mpv 的轨道号字符串转成 [TrackId]。
///
/// `auto` 与 `no` 是 mpv 的字面取值；数字是轨道号。出现别的东西（理论不该有）
/// 时退到 [TrackId.auto]——把它硬塞成一个不存在的轨道号只会让选择命令失败。
TrackId trackIdFromMpv(String id) {
  if (id == 'auto') return TrackId.auto;
  if (id == 'no') return TrackId.disabled;
  final number = int.tryParse(id);
  if (number != null && number >= 1) return TrackId(number);
  return TrackId.auto;
}

/// 把 mpv 的轨道号字符串转成 media_kit 的轨道选择操作。
///
/// 与 [trackIdFromMpv] 相反的方向：给 `setVideoTrack` 这类方法一个「能写进
/// mpv `vid`/`aid`/`sid` 属性」的取值。我们的 [TrackId] 存的就是 mpv 原值，
/// 直接透传即可。
String mpvTrackId(TrackId id) => id.mpvValue;

/// 把 [mk.VideoParams] 与播放器快照合并进 [info]。
///
/// 媒体信息是逐步探测出来的，media_kit 的 `video-params` 事件与 `duration`
/// 事件到达顺序不定，所以这里是增量合并而不是重新构造。
MediaInfo mergeMediaInfo({
  required MediaInfo info,
  String? videoCodec,
  String? audioCodec,
  int? width,
  int? height,
  double? frameRate,
  int? videoBitrate,
  int? audioBitrate,
  Duration? duration,
  String? hwdecCurrent,
  ColorPrimaries? primaries,
  TransferFunction? transfer,
  List<Track>? tracks,
}) {
  return info.copyWith(
    videoCodec: videoCodec ?? info.videoCodec,
    audioCodec: audioCodec ?? info.audioCodec,
    width: width ?? info.width,
    height: height ?? info.height,
    frameRate: frameRate ?? info.frameRate,
    videoBitrate: videoBitrate ?? info.videoBitrate,
    audioBitrate: audioBitrate ?? info.audioBitrate,
    hwdecCurrent: hwdecCurrent ?? info.hwdecCurrent,
    primaries: primaries ?? info.primaries,
    transfer: transfer ?? info.transfer,
    duration: duration,
    tracks: tracks,
  );
}

/// 从 [mk.VideoParams] 里取色域与传输函数。
///
/// media_kit 的 `video-params` 里这两项是字符串（对应 mpv 的
/// `video-params/primaries` 与 `video-params/gamma`），这里反查成我们的枚举，
/// 认不出一律回 `null`——没收录的新取值不该让播放中断。
({ColorPrimaries? primaries, TransferFunction? transfer}) colorInfoFrom(
  mk.VideoParams params,
) {
  return (
    primaries: params.primaries == null
        ? null
        : ColorPrimaries.fromMpvValue(params.primaries!),
    transfer: params.gamma == null
        ? null
        : TransferFunction.fromMpvValue(params.gamma!),
  );
}

/// 从选中的轨道里取编码名。
///
/// media_kit 的 `codec` 字段挂在轨道上而不是 `video-params` 里，取当前选中
/// 轨的值即可；没选中任何轨时返回 `null`。
String? codecOf(mk.Track selected, TrackKind kind) {
  return switch (kind) {
    TrackKind.video => selected.video.codec,
    TrackKind.audio => selected.audio.codec,
    TrackKind.subtitle => selected.subtitle.codec,
  };
}
