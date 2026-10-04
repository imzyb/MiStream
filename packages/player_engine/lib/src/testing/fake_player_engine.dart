/// 内存实现的 [PlayerEngine]，供契约测试与上层单测使用。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:player_engine/src/aspect_ratio_mode.dart';
import 'package:player_engine/src/duration_range.dart';
import 'package:player_engine/src/media_info.dart';
import 'package:player_engine/src/media_source.dart';
import 'package:player_engine/src/player_config.dart';
import 'package:player_engine/src/player_engine.dart';
import 'package:player_engine/src/player_error.dart';
import 'package:player_engine/src/player_log.dart';
import 'package:player_engine/src/player_state.dart';
import 'package:player_engine/src/track.dart';
import 'package:player_engine/src/value_stream.dart';
import 'package:player_engine/src/video_filter_settings.dart';

/// 一个纯内存的 [PlayerEngine]。
///
/// 存在的理由有两个，缺一个都不足以让它进 `lib/`：
///
/// 1. **让契约测试非空转**。M1 阶段只有一个真实实现，契约套件若只对着它跑，
///    等于「用实现验证自己」。多一个独立写出来的实现同时满足同一套用例，才
///    能证明约束是写在接口上而不是碰巧成立的。
/// 2. **给上层单测用**。`PlayUseCase` 的回退链（`docs/04-播放器设计.md` §7）
///    要覆盖「起播失败就换下一个候选」，需要一个能**按指令失败**的引擎；真实
///    引擎做不到稳定复现这一点。
///
/// 时间不会自己流动：位置只在 [seek] 与 [advance] 时改变。给假引擎接真时钟
/// 会让每条用例都变成计时竞赛，而测状态机根本不需要真的等。
final class FakePlayerEngine implements PlayerEngine {
  /// 构造一个假引擎。
  ///
  /// [mediaDuration] 是打开任何媒体后报出的时长，[tracks] 是报出的轨道表。
  FakePlayerEngine({
    Duration mediaDuration = const Duration(minutes: 10),
    List<Track>? tracks,
    // ignore: prefer_initializing_formals — 命名参数不能以下划线开头
  }) : _mediaDuration = mediaDuration,
       _tracks = tracks ?? _defaultTracks;

  static final List<Track> _defaultTracks = [
    const Track(kind: TrackKind.video, id: TrackId.auto, codec: 'h264'),
    const Track(kind: TrackKind.audio, id: TrackId.auto, language: 'zh'),
    const Track(kind: TrackKind.subtitle, id: TrackId.auto, language: 'zh'),
  ];

  final Duration _mediaDuration;
  final List<Track> _tracks;

  final _state = ValueStream<PlayerState>(PlayerState.idle);
  final _position = ValueStream<Duration>(Duration.zero);
  final _duration = ValueStream<Duration>(Duration.zero);
  final _buffered = ValueStream<List<DurationRange>>(const []);
  final _mediaInfo = ValueStream<MediaInfo>(MediaInfo.empty);
  final _logs = StreamController<PlayerLog>.broadcast();
  final _errors = StreamController<PlayerError>.broadcast();

  PlayerConfig? _config;
  MediaSource? _source;
  bool _disposed = false;
  double _rate = 1;
  double _volume = 1;
  bool _muted = false;
  TrackId _videoTrack = TrackId.auto;
  TrackId _audioTrack = TrackId.auto;
  TrackId _subtitleTrack = TrackId.auto;
  Duration _subtitleDelay = Duration.zero;
  Duration _audioDelay = Duration.zero;
  AspectRatioMode _aspectRatio = const AspectRatioMode.auto();
  VideoFilterSettings _videoFilter = VideoFilterSettings.neutral;
  final List<Uri> _externalSubtitles = <Uri>[];

  AppError? _initializeFailure;
  AppError? _openFailure;

  final List<Duration> _seekTargets = <Duration>[];

  // -------------------------------------------------------------------
  // 测试钩子
  // -------------------------------------------------------------------

  /// 历次 seek 的目标位置（按发生顺序，已钳制到 `[0, duration]`）。
  ///
  /// 续播验收需要断言「确实 seek 到了历史位置」，而不只看最终 position——
  /// 后者可能被后续操作覆盖。
  List<Duration> get seekTargets => List.unmodifiable(_seekTargets);

  /// seek 发生的次数。
  int get seekCount => _seekTargets.length;

  /// 最近一次 seek 的目标位置；从未 seek 为 `null`。
  Duration? get lastSeekTarget =>
      _seekTargets.isEmpty ? null : _seekTargets.last;

  /// 让下一次 [initialize] 以 [error] 失败。
  void failNextInitialize(AppError error) {
    _requireAlive();
    _initializeFailure = error;
  }

  /// 让下一次 [open] 以 [error] 失败。
  ///
  /// 只作用一次：`PlayUseCase` 的回退链要测的正是「第一个候选失败、第二个
  /// 成功」，如果失败是粘住的，第二个候选也起不来，用例就退化成「全都失败」。
  void failNextOpen(AppError error) {
    _requireAlive();
    _openFailure = error;
  }

  /// 手动推进播放位置。到达时长即进入 [PlayerState.ended]。
  ///
  /// 不计入 [seekTargets]：这是模拟内核自行推进，而非外部下发 seek 命令。
  void advance(Duration delta) {
    _requireOpen();
    _seekTo(_position.value + delta, record: false);
  }

  /// 手动发一条内核日志。
  void emitLog(PlayerLog log) {
    if (_disposed) return;
    _logs.add(log);
  }

  /// 手动发一条错误或降级事件。
  ///
  /// [PlayerError.isFatal] 为真时状态转到 [PlayerState.error]；非致命事件
  /// （典型是硬解降级）不改变状态。
  void emitError(PlayerError error) {
    if (_disposed) return;
    _errors.add(error);
    if (error.isFatal) _state.emitIfChanged(PlayerState.error);
  }

  /// 覆盖当前媒体信息，用于测「播放信息浮层」这类只读展示。
  void setMediaInfo(MediaInfo info) => _mediaInfo.emit(info);

  /// 当前已加载的外挂字幕。
  List<Uri> get externalSubtitles => List.unmodifiable(_externalSubtitles);

  /// 当前选中的字幕轨。
  TrackId get subtitleTrack => _subtitleTrack;

  /// 当前选中的音频轨。
  TrackId get audioTrack => _audioTrack;

  /// 当前选中的视频轨。
  TrackId get videoTrack => _videoTrack;

  /// 当前字幕延迟。
  Duration get subtitleDelay => _subtitleDelay;

  /// 当前音频延迟。
  Duration get audioDelay => _audioDelay;

  /// 当前画面比例。
  AspectRatioMode get aspectRatio => _aspectRatio;

  /// 当前画面滤镜。
  VideoFilterSettings get videoFilter => _videoFilter;

  /// 当前生效的配置；未 [initialize] 时为 `null`。
  PlayerConfig? get config => _config;

  /// 当前打开的媒体；未打开时为 `null`。
  MediaSource? get source => _source;

  // -------------------------------------------------------------------
  // 生命周期
  // -------------------------------------------------------------------

  @override
  Future<AppResult<void>> initialize(PlayerConfig config) async {
    _requireAlive();
    final failure = _initializeFailure;
    if (failure != null) {
      _initializeFailure = null;
      return Err(failure);
    }
    _config = config;
    return const Ok(null);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([
      _state.close(),
      _position.close(),
      _duration.close(),
      _buffered.close(),
      _mediaInfo.close(),
      _logs.close(),
      _errors.close(),
    ]);
  }

  // -------------------------------------------------------------------
  // 媒体
  // -------------------------------------------------------------------

  @override
  Future<AppResult<void>> open(MediaSource source, {Duration? startAt}) async {
    _requireInitialized();

    _state.emit(PlayerState.opening);

    final failure = _openFailure;
    if (failure != null) {
      _openFailure = null;
      _state.emit(PlayerState.error);
      _errors.add(PlayerError(error: failure, source: source.uri));
      return Err(failure);
    }

    _source = source;
    _externalSubtitles
      ..clear()
      ..addAll(source.externalSubtitles);

    final duration = source.isLive ? Duration.zero : _mediaDuration;
    _duration.emit(duration);
    _mediaInfo.emit(
      MediaInfo(
        videoCodec: 'h264',
        audioCodec: 'aac',
        width: 1920,
        height: 1080,
        frameRate: 25,
        hwdecCurrent: 'no',
        duration: source.isLive ? null : duration,
        tracks: _tracksWithSelection(),
      ),
    );

    final start = _clamp(startAt ?? Duration.zero, duration);
    _position.emit(start);
    _buffered.emit([DurationRange(start, start)]);

    _state
      ..emit(PlayerState.buffering)
      ..emit(PlayerState.playing);
    return const Ok(null);
  }

  @override
  Future<void> close() async {
    _requireInitialized();
    _source = null;
    _externalSubtitles.clear();
    _position.emit(Duration.zero);
    _duration.emit(Duration.zero);
    _buffered.emit(const []);
    _mediaInfo.emit(MediaInfo.empty);
    _state.emit(PlayerState.idle);
  }

  // -------------------------------------------------------------------
  // 传输控制
  // -------------------------------------------------------------------

  @override
  Future<void> play() async {
    _requireOpen();
    if (_state.value == PlayerState.ended) return;
    _state.emitIfChanged(PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    _requireOpen();
    if (_state.value == PlayerState.ended) return;
    _state.emitIfChanged(PlayerState.paused);
  }

  @override
  Future<void> seek(Duration position) async {
    _requireOpen();
    _seekTo(position);
  }

  @override
  Future<void> setRate(double rate) async {
    _requireInitialized();
    if (rate < PlayerEngine.minRate || rate > PlayerEngine.maxRate) {
      throw ArgumentError.value(
        rate,
        'rate',
        '倍速须在 ${PlayerEngine.minRate} ~ ${PlayerEngine.maxRate} 之间',
      );
    }
    _rate = rate;
  }

  @override
  Future<void> stepFrame({bool backward = false}) async {
    _requireOpen();
    const frame = Duration(milliseconds: 40);
    _seekTo(
      backward ? _position.value - frame : _position.value + frame,
      record: false,
    );
    _state.emitIfChanged(PlayerState.paused);
  }

  // -------------------------------------------------------------------
  // 音量
  // -------------------------------------------------------------------

  @override
  Future<void> setVolume(double volume) async {
    _requireInitialized();
    _volume = volume.clamp(0.0, PlayerEngine.maxVolume);
  }

  @override
  Future<void> setMuted({required bool muted}) async {
    _requireInitialized();
    _muted = muted;
  }

  // -------------------------------------------------------------------
  // 轨道
  // -------------------------------------------------------------------

  @override
  Future<void> selectVideoTrack(TrackId id) async {
    _requireOpen();
    _videoTrack = id;
    _refreshTracks();
  }

  @override
  Future<void> selectAudioTrack(TrackId id) async {
    _requireOpen();
    _audioTrack = id;
    _refreshTracks();
  }

  @override
  Future<void> selectSubtitleTrack(TrackId id) async {
    _requireOpen();
    _subtitleTrack = id;
    _refreshTracks();
  }

  @override
  Future<AppResult<void>> addExternalSubtitle(
    Uri uri, {
    String? title,
    bool select = true,
  }) async {
    _requireOpen();
    if (!uri.hasScheme && uri.path.isEmpty) {
      return const Err(
        LocalError(
          code: ErrorCode.playerSubtitleLoadFailed,
          message: '字幕地址为空',
        ),
      );
    }
    _externalSubtitles.add(uri);
    if (select) {
      _subtitleTrack = TrackId(_externalSubtitles.length);
    }
    _refreshTracks();
    return const Ok(null);
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    _requireOpen();
    _subtitleDelay = delay;
  }

  @override
  Future<void> setAudioDelay(Duration delay) async {
    _requireOpen();
    _audioDelay = delay;
  }

  // -------------------------------------------------------------------
  // 画面
  // -------------------------------------------------------------------

  @override
  Future<void> setAspectRatio(AspectRatioMode mode) async {
    _requireInitialized();
    _aspectRatio = mode;
  }

  @override
  Future<void> setVideoFilter(VideoFilterSettings settings) async {
    _requireInitialized();
    _videoFilter = settings;
  }

  @override
  Future<AppResult<Uint8List>> screenshot({bool withSubtitles = false}) async {
    _requireInitialized();
    if (_source == null) {
      return const Err(
        LocalError(
          code: ErrorCode.invalidState,
          message: '没有画面可截取',
        ),
      );
    }
    // PNG magic number，足以让调用方的「这是不是图片」判断成立。
    return Ok(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]));
  }

  // -------------------------------------------------------------------
  // 流与快照
  // -------------------------------------------------------------------

  @override
  Stream<PlayerState> get stateStream => _state.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration> get durationStream => _duration.stream;

  @override
  Stream<List<DurationRange>> get bufferedRanges => _buffered.stream;

  @override
  Stream<MediaInfo> get mediaInfoStream => _mediaInfo.stream;

  @override
  Stream<PlayerLog> get logStream => _logs.stream;

  @override
  Stream<PlayerError> get errorStream => _errors.stream;

  @override
  PlayerState get state => _state.value;

  @override
  Duration get position => _position.value;

  @override
  Duration get duration => _duration.value;

  @override
  MediaInfo get mediaInfo => _mediaInfo.value;

  @override
  double get rate => _rate;

  @override
  double get volume => _volume;

  @override
  bool get isMuted => _muted;

  @override
  bool get isDisposed => _disposed;

  // -------------------------------------------------------------------
  // 内部
  // -------------------------------------------------------------------

  void _seekTo(Duration target, {bool record = true}) {
    final clamped = _clamp(target, _duration.value);
    if (record) _seekTargets.add(clamped);
    _position.emit(clamped);
    _buffered.emit([DurationRange(Duration.zero, clamped)]);

    if (_duration.value > Duration.zero && clamped >= _duration.value) {
      _state.emitIfChanged(PlayerState.ended);
    } else if (_state.value == PlayerState.ended) {
      _state.emit(PlayerState.playing);
    }
  }

  void _refreshTracks() => _mediaInfo.emit(
    _mediaInfo.value.copyWith(tracks: _tracksWithSelection()),
  );

  List<Track> _tracksWithSelection() => [
    for (final track in _tracks)
      Track(
        id: track.id,
        kind: track.kind,
        title: track.title,
        language: track.language,
        codec: track.codec,
        isDefault: track.isDefault,
        isForced: track.isForced,
        isExternal: track.isExternal,
        isSelected: _selectedFor(track.kind) == track.id,
      ),
  ];

  TrackId _selectedFor(TrackKind kind) => switch (kind) {
    TrackKind.video => _videoTrack,
    TrackKind.audio => _audioTrack,
    TrackKind.subtitle => _subtitleTrack,
  };

  static Duration _clamp(Duration value, Duration max) {
    if (value < Duration.zero) return Duration.zero;
    if (max > Duration.zero && value > max) return max;
    return value;
  }

  void _requireAlive() {
    if (_disposed) {
      throw StateError('引擎已 dispose，不能再调用');
    }
  }

  void _requireInitialized() {
    _requireAlive();
    if (_config == null) {
      throw StateError('必须先 initialize');
    }
  }

  void _requireOpen() {
    _requireInitialized();
    if (_source == null) {
      throw StateError('必须先 open 一个媒体');
    }
  }
}
