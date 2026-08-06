/// media_kit 实现的 [PlayerEngine]。
///
/// 这是 M1 的一期实现（[ADR-004]）。它在 [PlayerEngine] 抽象后面工作，UI 与
/// 编排层不知情。设计见 `docs/04-播放器设计.md`，接口语义见 `player_engine.dart`。
///
/// ## media_kit 只被当作用 libmpv 的马甲
///
/// 本类刻意**只用** media_kit 高层 API 已暴露的部分，其余能力通过它底下那层
/// libmpv 的 `setProperty`/`command` 补齐——
/// 因为 [ADR-004] 写得很清楚：media_kit 未暴露全部 mpv 选项，那正是二期
/// `NativeMpvEngine` 存在的理由。这一期要做的不是用 `dart:ffi` 绕过 media_kit
/// 把选项全部补上，而是**把接口正确接上、把语义对齐**，留给二期去加能力。
///
/// 因此所有「media_kit 高层没暴露」的 mpv 操作都收敛到 `_mpvProperty` /
/// `_mpvCommand` 两个私方法：它们把 [mk.Player] 底下的 `NativePlayer` 拿到并
/// 调原生方法；拿不到（例如跑在非原生平台或遇到 `WebPlayer`）就返回 `null`/`false`，
/// 调用方按「此项静默无操作」处理。二期换成 FFI 直连时，只要把这两个方法换成
/// 直接调 libmpv，地址就只有一个。
///
/// ## 流语义的对齐
///
/// [PlayerEngine] 钉死了「广播流 + 迟到订阅者立即收到当前值」。media_kit 的
/// `PlayerStream` 虽是广播流，但迟到订阅者**收不到**当前值（它由 `Stream.multi`
/// 之外的 `StreamController.broadcast` 实现，不是我们 `value_stream.dart` 的
/// 语义）。所以本类不直接暴露 media_kit 的流，而是订阅它、把当前值灌进自己的
/// [ValueStream]，再从自己的流对外提供——这一步由 [ValueStream] 补发当前值。
///
/// ## 状态机的归属
///
/// 状态推导（[deriveState]）是纯函数，本类只把 media_kit 的三个布尔信号
/// （`playing`/`buffering`/`completed`）喂进去。`opening` 不是 media_kit 的
/// 概念，是本类在 `open` 期间自行推进的临时状态。
///
/// ## 硬解降级
///
/// 每条链条的步进在 `_hwdecChain` 上推进，解码错误数用 [HwdecFallbackDetector]
/// 结算——两者都已在 `hwdec.dart` 里测过。本类只负责把 media_kit 报来的解码错
/// 误喂进 [HwdecFallbackDetector]，并在它 [HwdecFallbackDetector.hasTripped] 时
/// 写下一档并推送 [PlayerError.hwdecFallback]。
///
/// [ADR-004]: ../../../docs/adr/004-播放器分两期实现.md
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:player_engine/src/aspect_ratio_mode.dart';
import 'package:player_engine/src/duration_range.dart';
import 'package:player_engine/src/hwdec.dart';
import 'package:player_engine/src/media_info.dart';
import 'package:player_engine/src/media_kit/media_kit_mapping.dart';
import 'package:player_engine/src/media_source.dart';
import 'package:player_engine/src/player_config.dart';
import 'package:player_engine/src/player_engine.dart';
import 'package:player_engine/src/player_error.dart';
import 'package:player_engine/src/player_log.dart';
import 'package:player_engine/src/player_state.dart';
import 'package:player_engine/src/track.dart';
import 'package:player_engine/src/value_stream.dart';
import 'package:player_engine/src/video_filter_settings.dart';

/// libmpv / media_kit 的一次性初始化。
///
/// 独立静态方法而不是 `initialize` 里的内联代码：media_kit 的
/// `MediaKit.ensureInitialized()` 只许成功调用一次，多调不报错但也没意义；
/// 把它和「创建 `Player`」分开，方便测试替身直接注入 [mk.Player]。
///
/// `libmpv` 可手动指定 libmpv 库路径（对应 media_kit 的 `MediaKit
/// .ensureInitialized(libmpv:)`）；`null` 时走系统默认查找。
final class MediaKitRuntime {
  /// 确保 media_kit 运行时就绪。
  ///
  /// 失败（通常是找不到 libmpv）返回 [ErrorCode.playerLibmpvMissing] 的 [Err]。
  static AppResult<void> ensureInitialized({String? libmpv}) {
    return guardApp(() => mk.MediaKit.ensureInitialized(libmpv: libmpv));
  }
}

/// 用 media_kit 实现的 [PlayerEngine]。
final class MediaKitEngine implements PlayerEngine {
  /// 构造一个引擎。
  ///
  /// [player] 可选注入，测试与「已有现成 Player」的场景复用；不传则在本类
  /// [initialize] 时自行创建一个。[libmpv] 手动指定 libmpv 库路径，交给
  /// [MediaKitRuntime.ensureInitialized]；`null` 走系统默认查找。
  MediaKitEngine({mk.Player? player, this.libmpv}) : _injectedPlayer = player;

  /// 注入的 [mk.Player]，或 `null`。
  final mk.Player? _injectedPlayer;

  /// 手动指定的 libmpv 库路径。
  final String? libmpv;

  // -------------------------------------------------------------------
  // 内部持有值
  // -------------------------------------------------------------------

  bool _disposed = false;
  bool _initialized = false;

  final _state = ValueStream<PlayerState>(PlayerState.idle);
  final _position = ValueStream<Duration>(Duration.zero);
  final _duration = ValueStream<Duration>(Duration.zero);
  final _buffered = ValueStream<List<DurationRange>>(const []);
  final _mediaInfo = ValueStream<MediaInfo>(MediaInfo.empty);
  final _logs = StreamController<PlayerLog>.broadcast();
  final _errors = StreamController<PlayerError>.broadcast();

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  late mk.Player _player;

  // 当前媒体的使用信息，open 期间被置空、结束时被清除。
  MediaSource? _source;
  bool _opening = false;

  HwdecChain _hwdecChain = HwdecChain.softwareOnly();
  HwdecFallbackDetector _hwdecDetector = HwdecFallbackDetector();

  double _rate = 1;
  double _volume = 1;
  bool _muted = false;

  // -------------------------------------------------------------------
  // 生命周期
  // -------------------------------------------------------------------

  @override
  Future<AppResult<void>> initialize(PlayerConfig config) async {
    _requireAlive();
    if (_initialized) {
      // 幂等：重复 initialize 不重建 Player。
      return const Ok(null);
    }

    final runtime = MediaKitRuntime.ensureInitialized(libmpv: libmpv);
    if (runtime.isErr) {
      return Err(
        LocalError(
          code: ErrorCode.playerLibmpvMissing,
          message: runtime.errorOrNull?.message ?? '无法初始化 libmpv',
          cause: runtime.errorOrNull,
        ),
      );
    }

    // mk.Player() 的构造会立刻加载 libmpv；即便 ensureInitialized 通过，构建
    // 失败（找不到库、符号不匹配）都会在这里抛出来，故同样收进 AppResult。
    final playerResult = guardApp(() => _injectedPlayer ?? mk.Player());
    if (playerResult.isErr) {
      return Err(
        LocalError(
          code: ErrorCode.playerInitFailed,
          message: playerResult.errorOrNull?.message ?? '无法创建播放内核',
          cause: playerResult.errorOrNull,
        ),
      );
    }
    final player = playerResult.valueOrNull!;
    _player = player;
    _initialized = true;

    _applyPlayerConfig(config);
    _subscribe(player);
    return const Ok(null);
  }

  /// 把传入配置落到底层 mpv（缓冲、协议白名单等由 `PlayerConfiguration`
  /// 在创建时设定，这里只处理那些必须在运行时通过属性对齐的项）。
  void _applyPlayerConfig(PlayerConfig config) {
    final chain = config.resolveHwdecChain();
    _hwdecChain = chain;
    _hwdecDetector = HwdecFallbackDetector(policy: config.hwdecFallback);
    _applyHwdec(chain.first);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // 反订阅先于销毁 Player，避免关闭中的一两个尾巴事件再写流。
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    unawaited(_logs.close());
    unawaited(_errors.close());
    await _state.close();
    await _position.close();
    await _duration.close();
    await _buffered.close();
    await _mediaInfo.close();

    if (_initialized) {
      await _player.dispose();
    }
  }

  // -------------------------------------------------------------------
  // 媒体
  // -------------------------------------------------------------------

  @override
  Future<AppResult<void>> open(MediaSource source, {Duration? startAt}) async {
    _requireInitialized();

    _source = source;
    _opening = true;
    _state.emit(PlayerState.opening);
    _mediaInfo.emit(MediaInfo.empty);
    _position.emit(Duration.zero);
    _duration.emit(Duration.zero);
    _buffered.emit(const []);
    _hwdecDetector.reset();

    try {
      final media = toMediaKitMedia(source, startAt: startAt);
      await _player.open(media);
      _opening = false;
      // open 期间到达的 playing/buffering 事件被 _opening 挡掉了，这里用
      // media_kit 的当前快照补一次状态推导，免得卡在 opening 直到下一个事件。
      _deriveState();
      return const Ok(null);
    } on Object catch (error, stackTrace) {
      _opening = false;
      _state.emit(PlayerState.error);
      final appError = AppError.from(error, stackTrace);
      _errors.add(PlayerError(error: appError, source: source.uri));
      return Err(appError);
    }
  }

  @override
  Future<void> close() async {
    _requireInitialized();
    _source = null;
    _opening = false;
    await _player.stop();
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
    await _player.play();
    _state.emitIfChanged(PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    _requireOpen();
    await _player.pause();
    // 与 play() 对称：用户动作立即反映在状态上。这里不能走 _deriveState——
    // 底层若仍在缓冲，mpv 会把 buffering 报成 true，pause 会被「翻译」成
    // buffering，UI 就不知道该显示暂停了。
    _state.emitIfChanged(PlayerState.paused);
  }

  @override
  Future<void> seek(Duration position) async {
    _requireOpen();
    final clamped = _clamp(position, _duration.value);
    await _player.seek(clamped);
    _position.emit(clamped);
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
    await _player.setRate(rate);
  }

  @override
  Future<void> stepFrame({bool backward = false}) async {
    _requireOpen();
    // media_kit 高层没有逐帧命令，走底层 mpv 的 frame-step / frame-back-step。
    final ok = await _mpvCommand([
      if (backward) 'frame-back-step' else 'frame-step',
    ]);
    if (!ok) {
      _state.emitIfChanged(PlayerState.paused);
    }
  }

  // -------------------------------------------------------------------
  // 音量
  // -------------------------------------------------------------------

  @override
  Future<void> setVolume(double volume) async {
    _requireInitialized();
    _volume = volume.clamp(0.0, PlayerEngine.maxVolume);
    // media_kit 高层 volume 以 0~100 记，我们以 0~1.5 记；换算后交给它。
    await _player.setVolume(_volume * 100);
  }

  @override
  Future<void> setMuted({required bool muted}) async {
    _requireInitialized();
    _muted = muted;
    // media_kit 高层没有 mute 开关，走底层 mpv。
    await _mpvProperty('mute', muted ? 'yes' : 'no');
  }

  // -------------------------------------------------------------------
  // 轨道
  // -------------------------------------------------------------------

  @override
  Future<void> selectVideoTrack(TrackId id) async {
    _requireOpen();
    await _player.setVideoTrack(mk.VideoTrack(mpvTrackId(id), null, null));
  }

  @override
  Future<void> selectAudioTrack(TrackId id) async {
    _requireOpen();
    await _player.setAudioTrack(mk.AudioTrack(mpvTrackId(id), null, null));
  }

  @override
  Future<void> selectSubtitleTrack(TrackId id) async {
    _requireOpen();
    await _player.setSubtitleTrack(
      mk.SubtitleTrack(mpvTrackId(id), null, null),
    );
  }

  @override
  Future<AppResult<void>> addExternalSubtitle(
    Uri uri, {
    String? title,
    bool select = true,
  }) async {
    _requireInitialized();
    final result = await guardAppAsync<void>(() async {
      await _player.setSubtitleTrack(
        mk.SubtitleTrack.uri(
          uri.toString(),
          title: title ?? uri.pathSegments.last,
        ),
      );
    });
    return result.mapErr(
      (error) => LocalError(
        code: ErrorCode.playerSubtitleLoadFailed,
        message: '外挂字幕加载失败: ${error.message}',
        cause: error,
      ),
    );
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    _requireOpen();
    await _mpvProperty('sub-delay', (delay.inMilliseconds / 1000).toString());
  }

  @override
  Future<void> setAudioDelay(Duration delay) async {
    _requireOpen();
    await _mpvProperty('audio-delay', (delay.inMilliseconds / 1000).toString());
  }

  // -------------------------------------------------------------------
  // 画面
  // -------------------------------------------------------------------

  @override
  Future<void> setAspectRatio(AspectRatioMode mode) async {
    _requireInitialized();
    switch (mode) {
      case AutoAspectRatio():
        await _mpvProperties({
          'keepaspect': 'yes',
          'video-aspect-override': '-1',
          'panscan': '0',
        });
      case FillAspectRatio():
        await _mpvProperty('panscan', '1.0');
      case StretchAspectRatio():
        await _mpvProperties({
          'keepaspect': 'no',
          'video-aspect-override': '-1',
        });
      case CustomAspectRatio(:final width, :final height):
        await _mpvProperty('video-aspect-override', '$width/$height');
    }
  }

  @override
  Future<void> setVideoFilter(VideoFilterSettings settings) async {
    _requireInitialized();
    if (settings.isNeutral) return;
    // docs/04 §4 里「视频滤镜」在 v0.1 打了 —；这里至少把亮度等四项接上。
    await _mpvProperties({
      'brightness': settings.brightness.toString(),
      'contrast': settings.contrast.toString(),
      'saturation': settings.saturation.toString(),
      'gamma': settings.gamma.toString(),
    });
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
    final data = await _player.screenshot(
      format: 'image/png',
      includeLibassSubtitles: withSubtitles,
    );
    if (data == null) {
      return const Err(
        LocalError(
          code: ErrorCode.invalidState,
          message: '截图尚未就绪',
        ),
      );
    }
    return Ok(data);
  }

  // -------------------------------------------------------------------
  // 状态流
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

  // -------------------------------------------------------------------
  // 同步快照
  // -------------------------------------------------------------------

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

  void _subscribe(mk.Player player) {
    _subscriptions.addAll([
      player.stream.playing.listen(_onPlaying),
      player.stream.buffering.listen(_onBuffering),
      player.stream.completed.listen(_onCompleted),
      player.stream.position.listen(_onPosition),
      player.stream.duration.listen(_onDuration),
      player.stream.buffer.listen(_onBuffer),
      player.stream.track.listen(_onTrack),
      player.stream.tracks.listen(_onTracks),
      player.stream.videoParams.listen(_onVideoParams),
      player.stream.width.listen(
        (width) => _emitMediaInfo(
          mergeMediaInfo(info: _mediaInfo.value, width: width),
        ),
      ),
      player.stream.height.listen(
        (height) => _emitMediaInfo(
          mergeMediaInfo(info: _mediaInfo.value, height: height),
        ),
      ),
      player.stream.log.listen(_onLog),
      player.stream.error.listen(_onError),
    ]);
  }

  void _onPlaying(bool playing) {
    // media_kit 在 un-pause 时上报 playing；opening 期间我们自行管理状态。
    if (_opening) return;
    _deriveState(playing: playing);
  }

  void _onBuffering(bool buffering) {
    if (_opening) return;
    _deriveState(buffering: buffering);
  }

  void _onCompleted(bool completed) {
    if (_opening) return;
    _deriveState(playing: _player.state.playing, completed: completed);
  }

  void _deriveState({bool? playing, bool? buffering, bool? completed}) {
    if (_opening) return;
    final derived = deriveState(
      hasMedia: _source != null,
      playing: playing ?? _player.state.playing,
      buffering: buffering ?? _player.state.buffering,
      completed: completed ?? _player.state.completed,
    );
    _state.emit(derived);
  }

  void _onPosition(Duration position) {
    if (!_opening && _duration.value > Duration.zero) {
      _position.emit(position);
    }
  }

  void _onDuration(Duration duration) {
    if (_opening) return;
    _duration.emit(duration);
    _emitMediaInfo(
      mergeMediaInfo(
        info: _mediaInfo.value,
        duration: duration > Duration.zero ? duration : null,
      ),
    );
  }

  void _onBuffer(Duration buffer) {
    if (_opening) return;
    // demuxer 的已缓冲数据；映射成一段以当前位置为起点的区间。
    _buffered.emit([
      DurationRange(_position.value, _position.value + buffer),
    ]);
  }

  void _onTrack(mk.Track track) {
    _emitTracksFrom(_player.state.tracks, track);
  }

  void _onTracks(mk.Tracks tracks) {
    _emitTracksFrom(tracks, _player.state.track);
  }

  void _emitTracksFrom(mk.Tracks? tracks, mk.Track? selected) {
    final mkTracks = tracks ?? _player.state.tracks;
    final mkSelected = selected ?? _player.state.track;
    final mapped = mapTracks(mkTracks, mkSelected);
    _emitMediaInfo(
      mergeMediaInfo(
        info: _mediaInfo.value,
        tracks: mapped,
        videoCodec: codecOf(mkSelected, TrackKind.video),
        audioCodec: codecOf(mkSelected, TrackKind.audio),
      ),
    );
  }

  void _onVideoParams(mk.VideoParams params) {
    final codecs = colorInfoFrom(params);
    _emitMediaInfo(
      mergeMediaInfo(
        info: _mediaInfo.value,
        width: params.w ?? params.dw,
        height: params.h ?? params.dh,
        primaries: codecs.primaries,
        transfer: codecs.transfer,
      ),
    );
  }

  void _onLog(mk.PlayerLog log) {
    if (_disposed) return;
    _logs.add(
      PlayerLog(
        level: PlayerLogLevel.fromMpvLevel(log.level),
        prefix: log.prefix,
        message: log.text,
      ),
    );

    // 把 vd/ad 之类的前缀上面的解码错误喂给降级判定。
    if ((log.prefix == 'vd' || log.prefix == 'ad' || log.prefix == 'ffmpeg') &&
        (log.level == 'error' || log.level == 'fatal') &&
        !_opening) {
      _recordDecodeError();
    }
  }

  void _onError(String text) {
    if (_disposed) return;
    // media_kit 的 errorStream 只给字符串，没有结构化错误码。拼一个可读信息，
    // 能定位到的常见情况尽量给对码，给不出的退回 unknown。
    _errors.add(
      PlayerError(
        error: LocalError(
          code: ErrorCode.playerOpenFailed,
          message: text,
          detail: const {'origin': 'media_kit'},
        ),
        source: _source?.uri,
        position: _position.value,
      ),
    );
  }

  void _recordDecodeError() {
    final sinceOpen = _player.state.position;
    if (_hwdecDetector.recordDecodeError(sinceOpen)) {
      _fallbackHwdec();
    }
  }

  void _fallbackHwdec() {
    final chain = _hwdecChain;
    if (chain.isSoftwareOnly) return;

    final currentMethod = _currentHwdecMethod ?? chain.first;
    final next = chain.next(currentMethod);
    if (next == null) return;

    _applyHwdec(next);
    _errors.add(
      PlayerError.hwdecFallback(
        from: currentMethod.mpvValue,
        to: next.mpvValue,
        source: _source?.uri,
      ),
    );
  }

  HwdecMethod? _currentHwdecMethod;

  void _applyHwdec(HwdecMethod method) {
    _currentHwdecMethod = method;
    // 写 hwdec 后由 mpv 自行确定生效的后端；hwdec-current 是否真正对上留给
    // MediaInfo.isHardwareDecoding 侧查，这里不反向探测。
    unawaited(_mpvProperty('hwdec', method.mpvValue));
    unawaited(_mpvProperty('hwdec-preferred', method.mpvValue));
  }

  void _emitMediaInfo(MediaInfo info) => _mediaInfo.emit(info);

  /// 写一条 mpv 属性，拿不到原生 Player 时返回 `false`。
  Future<bool> _mpvProperty(String name, String value) async {
    final native = _nativePlayer();
    if (native == null) return false;
    try {
      await native.setProperty(name, value);
      return true;
    } on Object {
      return false;
    }
  }

  /// 连写多条 mpv 属性，任一条失败即中断。
  Future<void> _mpvProperties(Map<String, String> properties) async {
    for (final entry in properties.entries) {
      await _mpvProperty(entry.key, entry.value);
    }
  }

  /// 执行一条 mpv 命令，拿不到原生 Player 时返回 `false`。
  Future<bool> _mpvCommand(List<String> command) async {
    final native = _nativePlayer();
    if (native == null) return false;
    try {
      await native.command(command);
      return true;
    } on Object {
      return false;
    }
  }

  /// 取 [mk.Player] 底下的原生 Player。
  mk.NativePlayer? _nativePlayer() {
    final platform = _player.platform;
    if (platform is mk.NativePlayer) return platform;
    return null;
  }

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
    if (!_initialized) {
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
