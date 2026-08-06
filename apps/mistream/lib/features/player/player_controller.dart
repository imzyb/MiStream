/// 播放器 UI 与内核之间的桥：把 `PlayerEngine` 的流压成一处同步状态 + 一组命令。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:player_engine/player_engine.dart';

/// 把 [PlayerEngine] 绑定到 UI 的控制器。
///
/// 《架构》§2 里 UI 只依赖 `PlayerEngine` 抽象；但每个 widget 各自订阅六条流、
/// 各自维护一份副本，是转发样板，且容易漏取消。这里把「订阅 → 同步状态」和
/// 「命令 → 调引擎」收敛成单一入口，widget 用 [ChangeNotifier] 的
/// `Listenable` 接口消费。
///
/// ## 不处理什么
///
/// - 播放编排（选源、换线路回退）在 application 层，不在本类。
/// - 自动隐藏的**计时器**放在 widget 层（它由指针/按键事件驱动，是交互而非
///   状态），本类只提供判断「该不该现在隐藏」的纯逻辑 [shouldHideControls]，让
///   计时逻辑可以不挂 widget 树单独测。
class PlayerController extends ChangeNotifier {
  /// 绑定一个引擎。[autoHideDelay] 是控制栏无操作隐藏的时长（`docs/04` §10）。
  ///
  /// [clock] 是测试钩子：注入一个可控时钟即可让「多久没操作」的判定脱离真实
  /// 时间。不存在无副作用的构造。
  PlayerController({
    required this.engine,
    this.autoHideDelay = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// 播放内核抽象，UI 只依赖它。
  final PlayerEngine engine;

  /// 控制栏无操作隐藏时长。
  final Duration autoHideDelay;

  final DateTime Function() _now;

  final List<StreamSubscription<Object?>> _subs = [];

  PlayerState _state = PlayerState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  List<DurationRange> _buffered = const [];
  double _volume = 1;
  bool _muted = false;
  double _rate = 1;
  PlayerError? _fatalError;
  PlayerError? _notice;

  bool _controlsVisible = true;
  DateTime? _lastInteraction;

  /// 当前播放状态。
  PlayerState get state => _state;

  /// 当前播放位置。
  Duration get position => _position;

  /// 当前媒体时长；未知为 [Duration.zero]。
  Duration get duration => _duration;

  /// 已缓冲区间。
  List<DurationRange> get buffered => _buffered;

  /// 当前音量。
  double get volume => _volume;

  /// 当前是否静音。
  bool get isMuted => _muted;

  /// 当前倍速。
  double get rate => _rate;

  /// 最近一次致命错误；`null` 表示正常播放。
  PlayerError? get fatalError => _fatalError;

  /// 最近一次**非致命**事件（如硬解降级）。
  ///
  /// 与 [fatalError] 的分工在 `player_error.dart`：非致命事件不打断播放，UI 用
  /// 它飘一条提示而不是弹错误卡片。`docs/04` §5 规则 2 明确要求硬解降级「在 UI
  /// 明确提示」，不能静默。
  ///
  /// 事件消费后由 UI 调 [consumeNotice] 清空；不清空时这里保留最新一条，方便
  /// 测试「最后一次提示了什么」。
  PlayerError? get notice => _notice;

  /// 消费 [notice]（UI 已展示）。
  void consumeNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  /// 控制栏当前应显示。
  bool get isControlVisible => _controlsVisible;

  /// 显示控制栏并重置无操作计时。
  void showControls() {
    _controlsVisible = true;
    _markInteraction();
  }

  /// 隐藏控制栏。暂停/加载/出错等不该隐藏的场景下调用是安全的空操作。
  void hideControls() {
    if (_lockVisible) return;
    _controlsVisible = false;
    _markInteraction();
  }

  /// 是否已加载媒体（区别于空闲与失败终止）。
  bool get hasMedia => _state.hasMedia;

  /// 是否正在推进播放（[PlayerState.buffering] 也算）。
  bool get isPlaying => _state.isPlaying;

  /// 控制栏是否不应自动隐藏：加载中、已结束、出错都不藏，免得用户对着空白
  /// 不知所以。
  bool get _lockVisible =>
      !hasMedia || _state == PlayerState.paused || _state == PlayerState.ended;

  /// 连接中应当显示加载提示的状态。
  bool get isConnecting =>
      _state == PlayerState.opening || _state == PlayerState.buffering;

  /// 是否已绑定引擎并订阅流（初始化完成且未释放）。
  bool get hasSubscribed => _subs.isNotEmpty;

  /// 开始订阅引擎流。引擎流是广播流且迟到订阅者立即收到当前值，因此订阅后
  /// 立即读一遍引擎快照即可拿到完整初始状态。
  ///
  /// 幂等：重复调用只订阅一次。
  void attach() {
    if (_subs.isNotEmpty) return;
    final e = engine;
    _subs.addAll([
      e.stateStream.listen(
        (s) {
          _state = s;
          // 错误状态由 errorStream 写 _fatalError；这里只清除「错误已过去」时
          // 的残留（比如换源 open 成功后）。进入 error 态时不能清——事件先后
          // 顺序是 errorStream 先、stateStream 后，谁后到谁说话，得让错误卡片
          // 留住。
          if (s != PlayerState.error) _fatalError = null;
          // 新起播（opening）时清掉上一条提示，避免残留。
          if (s == PlayerState.opening) _notice = null;
          notifyListeners();
        },
        onDone: _syncFromEngine,
      ),
      e.positionStream.listen(
        (p) {
          _position = p;
          notifyListeners();
        },
        onError: _ignore,
      ),
      e.durationStream.listen(
        (d) {
          _duration = d;
          notifyListeners();
        },
        onError: _ignore,
      ),
      e.bufferedRanges.listen(
        (b) {
          _buffered = b;
          notifyListeners();
        },
        onError: _ignore,
      ),
      e.errorStream.listen(
        (err) {
          if (err.isFatal) {
            _fatalError = err;
          } else {
            _notice = err;
          }
          notifyListeners();
        },
        onError: _ignore,
      ),
    ]);
    _state = e.state;
    _position = e.position;
    _duration = e.duration;
    _volume = e.volume;
    _muted = e.isMuted;
    _rate = e.rate;
    _fatalError = null;
    notifyListeners();
  }

  /// 引擎流关闭时被调：引擎已释放，停订阅并通知。
  void _syncFromEngine() {
    _subs.clear();
    notifyListeners();
  }

  void _ignore(Object? _) {}

  /// 播放/暂停切换。
  Future<void> togglePlayPause() async {
    _markInteraction();
    if (_state == PlayerState.playing || _state == PlayerState.buffering) {
      await engine.pause();
    } else if (_state == PlayerState.paused || _state == PlayerState.ended) {
      await engine.play();
    }
  }

  /// 跳转到相对当前位置偏移 [delta] 的位置。
  Future<void> seekBy(Duration delta) => seekTo(_position + delta);

  /// 跳转到 [target]（钳制到 `[0, duration]`）。
  Future<void> seekTo(Duration target) async {
    _markInteraction();
    await engine.seek(_clamp(target));
  }

  /// 设置音量，钳制到 `[0, maxVolume]`。
  Future<void> setVolume(double value) async {
    _markInteraction();
    await engine.setVolume(value.clamp(0.0, PlayerEngine.maxVolume));
  }

  /// 相对音量增减。
  Future<void> adjustVolumeBy(double delta) async {
    await setVolume(_volume + delta);
  }

  /// 静音开关。
  Future<void> toggleMute() async {
    _markInteraction();
    await engine.setMuted(muted: !_muted);
  }

  /// 设置倍速，越界抛 [ArgumentError]（由引擎强制）。
  Future<void> setRate(double value) async {
    _markInteraction();
    await engine.setRate(value);
  }

  /// 递增/递减一档倍速，钳制到引擎上下限。
  Future<void> adjustRateBy(double delta) async {
    _markInteraction();
    final next = (_rate + delta).clamp(
      PlayerEngine.minRate,
      PlayerEngine.maxRate,
    );
    await engine.setRate(next);
  }

  Duration _clamp(Duration target) {
    if (target < Duration.zero) return Duration.zero;
    if (_duration > Duration.zero && target > _duration) return _duration;
    return target;
  }

  /// 记录一次用户交互，供「该隐藏吗」判断。
  void poke() => _markInteraction();

  void _markInteraction() {
    _lastInteraction = _now();
    notifyListeners();
  }

  /// 「无操作」计时器到点后调用的判定：该隐藏吗？
  ///
  /// 规则（`docs/04` §10、`docs/09` §5.5）：暂停/结束/无媒体/连接中不隐藏；
  /// 播放中自 [lastInteraction] 起超过 [autoHideDelay] 未操作则隐藏。
  ///
  /// 纯判定、无副作用；widget 层计时器到点后调用它、为真时再调 [hideControls]。
  /// 这样判与做分离，两道逻辑都各有测试入口。
  bool shouldHideControls(DateTime now) =>
      _controlsVisible &&
      !_lockVisible &&
      (_lastInteraction == null ||
          now.difference(_lastInteraction!) >= autoHideDelay);

  /// 上次交互的时间；从未交互为 `null`。
  DateTime? get lastInteraction => _lastInteraction;

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    super.dispose();
  }
}
