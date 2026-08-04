/// `PlayerEngine` 抽象接口。
library;

import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:player_engine/src/aspect_ratio_mode.dart';
import 'package:player_engine/src/duration_range.dart';
import 'package:player_engine/src/media_info.dart';
import 'package:player_engine/src/media_source.dart';
import 'package:player_engine/src/player_config.dart';
import 'package:player_engine/src/player_error.dart';
import 'package:player_engine/src/player_log.dart';
import 'package:player_engine/src/player_state.dart';
import 'package:player_engine/src/track.dart';
import 'package:player_engine/src/video_filter_settings.dart';

/// 播放内核的统一接口，UI 与编排层只依赖它。
///
/// 设计参照系是 **mpv 的原生能力**，不是任何一个 Dart 封装库的 API 形状——
/// 这是 [ADR-004] 明确写下的缓解措施：抽象层若照抄了一期实现的形状，二期换
/// `NativeMpvEngine` 时会发现接口不够用，抽象层也就白做了。
///
/// ## 失败怎么表达
///
/// `docs/10-开发规范.md` §3.4 要求可预期失败走 `Result`，而
/// `docs/04-播放器设计.md` §3 的签名清一色是 `Future<void>`。两者冲突，这里
/// 按下面三条收敛（文档已同步）：
///
/// 1. **返回 [AppResult]**：[initialize]、[open]、[addExternalSubtitle]、
///    [screenshot]。这四个的失败是外部原因造成的、可预期的，且调用方**必须
///    分支处理**——`PlayUseCase` 的回退链（`docs/04` §7）整条都建立在
///    「[open] 失败了，换下一个候选」之上。
/// 2. **返回 `Future<void>`，只在调用顺序错误时抛 [StateError]**：其余传输
///    控制。未 [initialize] 就调、[dispose] 之后再调，都是编程错误而不是可
///    预期失败，按 §3.4「只有真正的编程错误才 throw」处理。
/// 3. **走 [errorStream]**：播放过程中发生的异步失败（解码错误、网络中断、
///    硬解降级）。它们不属于任何一次方法调用，没有返回值可挂。
///
/// 当前实现不支持的能力（见 `docs/04` §4 能力矩阵里标 `—` 的项）返回
/// [ErrorCode.unsupportedPlatform] 的 [Err]，而不是抛异常或静默无操作。
///
/// ## 流的订阅语义
///
/// 所有 `Stream` 都是**广播流**，且**迟到的订阅者立即收到当前值**。
/// `docs/04` §3 没写这一条，但它必须被钉死：播放页的组件是陆续挂载的，
/// 控制栏订阅 [stateStream] 时播放可能已经开始，拿不到当前值就会显示成
/// 「未播放」直到下一次状态变化——而正在稳定播放时，下一次状态变化可能是
/// 十分钟以后。
///
/// [dispose] 之后所有流关闭。
///
/// [ADR-004]: ../../../docs/adr/004-播放器分两期实现.md
abstract interface class PlayerEngine {
  /// 倍速下限（`docs/04-播放器设计.md` §3）。
  static const double minRate = 0.25;

  /// 倍速上限。
  static const double maxRate = 4;

  /// 音量上限。1.0 以上是软件增益，用于压得过低的片源。
  static const double maxVolume = 1.5;

  // -------------------------------------------------------------------
  // 生命周期
  // -------------------------------------------------------------------

  /// 初始化引擎。
  ///
  /// 失败原因通常是 [ErrorCode.playerLibmpvMissing]（找不到或校验不过）
  /// 与 [ErrorCode.playerInitFailed]。
  Future<AppResult<void>> initialize(PlayerConfig config);

  /// 释放引擎。之后任何调用都抛 [StateError]。
  ///
  /// 可重复调用而不报错——UI 的销毁路径可能被走两次，让它幂等比要求每个调用
  /// 方自己记「有没有 dispose 过」现实。
  Future<void> dispose();

  // -------------------------------------------------------------------
  // 媒体
  // -------------------------------------------------------------------

  /// 打开 [source]，可指定从 [startAt] 起播（续播）。
  ///
  /// 成功返回时状态已离开 [PlayerState.opening]。失败常见
  /// [ErrorCode.playerOpenFailed] 与 [ErrorCode.playerUnsupportedFormat]。
  Future<AppResult<void>> open(MediaSource source, {Duration? startAt});

  /// 关闭当前媒体，回到 [PlayerState.idle]。
  Future<void> close();

  // -------------------------------------------------------------------
  // 传输控制
  // -------------------------------------------------------------------

  /// 开始或继续播放。已在播放时无操作。
  Future<void> play();

  /// 暂停。已暂停时无操作。
  Future<void> pause();

  /// 跳转到 [position]，超出 `[0, duration]` 的取值被钳制到边界。
  Future<void> seek(Duration position);

  /// 设置倍速，取值须落在 [minRate] 与 [maxRate] 之间。
  ///
  /// 越界抛 [ArgumentError]：倍速由 UI 的固定档位或快捷键产生，出现越界值
  /// 说明是调用方算错了，不是用户输入错了。
  Future<void> setRate(double rate);

  /// 逐帧步进。[backward] 为真则后退一帧。
  Future<void> stepFrame({bool backward = false});

  // -------------------------------------------------------------------
  // 音量
  // -------------------------------------------------------------------

  /// 设置音量，`0` 到 [maxVolume]，越界钳制到边界。
  ///
  /// 与 [setRate] 的处理不同：音量常来自滚轮与拖拽这类连续输入，在边界上
  /// 「多滚一格」是完全正常的操作，为此抛异常没有道理。
  Future<void> setVolume(double volume);

  /// 静音开关。静音不改变 [volume]。
  Future<void> setMuted({required bool muted});

  // -------------------------------------------------------------------
  // 轨道
  // -------------------------------------------------------------------

  /// 选择视频轨。
  Future<void> selectVideoTrack(TrackId id);

  /// 选择音频轨。
  Future<void> selectAudioTrack(TrackId id);

  /// 选择字幕轨。关闭字幕传 [TrackId.disabled]。
  ///
  /// `docs/04` §3 原签名是可空的 `TrackId?` 且以 `null` 表示关闭。既然
  /// [TrackId] 本身已经带了 mpv 的 `no` 语义，再叠一层 `null` 就有了两种
  /// 写法表达同一件事，调用方迟早两种都写。文档已同步。
  Future<void> selectSubtitleTrack(TrackId id);

  /// 加载外挂字幕并可选地立即选中。
  ///
  /// 失败为 [ErrorCode.playerSubtitleLoadFailed]。
  Future<AppResult<void>> addExternalSubtitle(
    Uri uri, {
    String? title,
    bool select = true,
  });

  /// 设置字幕延迟。正值表示字幕晚出现。
  Future<void> setSubtitleDelay(Duration delay);

  /// 设置音频延迟。正值表示声音晚出现。
  Future<void> setAudioDelay(Duration delay);

  // -------------------------------------------------------------------
  // 画面
  // -------------------------------------------------------------------

  /// 设置画面比例。
  Future<void> setAspectRatio(AspectRatioMode mode);

  /// 设置画面滤镜。
  Future<void> setVideoFilter(VideoFilterSettings settings);

  /// 截取当前帧的 PNG 数据。
  ///
  /// [withSubtitles] 为真则包含字幕。没有画面时返回
  /// [ErrorCode.invalidState] 的 [Err]。
  Future<AppResult<Uint8List>> screenshot({bool withSubtitles = false});

  // -------------------------------------------------------------------
  // 状态流
  // -------------------------------------------------------------------

  /// 播放状态。
  Stream<PlayerState> get stateStream;

  /// 播放位置，按 `PlayerConfig.positionUpdateInterval` 节流。
  Stream<Duration> get positionStream;

  /// 总时长。直播流上不会有事件。
  Stream<Duration> get durationStream;

  /// 已缓冲的区间。
  Stream<List<DurationRange>> get bufferedRanges;

  /// 媒体技术信息，随探测逐步补全。
  Stream<MediaInfo> get mediaInfoStream;

  /// 内核日志。
  Stream<PlayerLog> get logStream;

  /// 播放错误与降级事件。
  Stream<PlayerError> get errorStream;

  // -------------------------------------------------------------------
  // 同步快照
  // -------------------------------------------------------------------

  /// 当前状态。
  ///
  /// 与 [stateStream] 并存：编排层要做的是「现在是什么状态」的一次性判断，
  /// 为此订阅再取消一条流既啰嗦又容易漏掉取消。
  PlayerState get state;

  /// 当前播放位置。
  Duration get position;

  /// 当前媒体时长；未知为 [Duration.zero]。
  Duration get duration;

  /// 当前媒体信息。
  MediaInfo get mediaInfo;

  /// 当前倍速。
  double get rate;

  /// 当前音量。
  double get volume;

  /// 当前是否静音。
  bool get isMuted;

  /// 是否已 [dispose]。
  bool get isDisposed;
}
