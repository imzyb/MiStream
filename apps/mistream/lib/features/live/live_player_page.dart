/// 直播播放页：按序试频道的每条线路，起播后显示当前线路；支持方向键换台、
/// 数字键跳台。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:live/live.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mistream/app/app.dart' show AppScope;
import 'package:mistream/features/live/live_shortcuts.dart';
import 'package:mistream/features/player/player_controller.dart';
import 'package:mistream/features/player/player_page.dart';
import 'package:player_engine/player_engine.dart';

/// 直播播放页。
///
/// 与点播播放页的差别：不查 Spider API，直接按 [LiveChannel.allUrls] 的顺序
/// 试流 —— 真实直播源里同一频道挂多条地址是常态，第一条不通不代表这个台不能看。
///
/// 换台键在 [channels]（用户当前可见的那份列表）上走，所见即所切。
class LivePlayerPage extends StatefulWidget {
  /// 构造直播播放页。
  const LivePlayerPage({
    super.key,
    required this.channel,
    this.channels = const [],
  });

  /// 目标频道（含主地址与备用地址）。
  final LiveChannel channel;

  /// 用户当前可见的频道列表（已按分组筛选、已排序）。
  ///
  /// 为空表示调用方没给列表，此时换台键不生效 —— 只播这一个台，而不是自己
  /// 去猜一份列表出来。
  final List<LiveChannel> channels;

  @override
  State<LivePlayerPage> createState() => _LivePlayerPageState();
}

class _LivePlayerPageState extends State<LivePlayerPage> {
  /// 数字键跳台的确认窗口。
  ///
  /// 取 1200ms：太短则「1」「2」之间稍慢一点就被当成跳到 1 号台，太长则按完
  /// 要干等。遥控器场景下这是必然的取舍，所以 `Enter` 是立即确认的快捷方式。
  static const _numberCommitDelay = Duration(milliseconds: 1200);

  /// 提示浮层的停留时间。
  static const _noticeDuration = Duration(seconds: 2);

  PlayerController? _controller;
  MediaKitEngine? _engine;
  mkv.VideoController? _videoController;
  LiveChannelSwitcher? _switcher;
  LiveSwitchResult? _result;

  /// 当前正在播的频道；换台后会变。
  LiveChannel? _channel;

  /// 首次起播就失败：整页错误视图（此时没有任何画面可看）。
  String? _fatalError;

  /// 换台失败 / 频道不存在这类提示：走浮层，不夺走画面与键盘焦点。
  String? _notice;
  Timer? _noticeTimer;

  /// 换台/跳台在可见列表上的定位。
  LiveChannelNavigator? _navigator;

  /// 数字键缓冲与它的确认计时器。
  final ChannelNumberBuffer _numberBuffer = ChannelNumberBuffer();
  Timer? _numberTimer;

  /// 本频道的节目单（拉到才有）。
  LiveEpg? _epg;
  EpgFetcher? _epgFetcher;
  bool _depsReady = false;

  /// 当前频道。首次起播失败时 `_channel` 还没赋值，退回构造参数。
  LiveChannel get _current => _channel ?? widget.channel;

  @override
  void initState() {
    super.initState();
    _navigator = LiveChannelNavigator(widget.channels);
    unawaited(_init());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _epgFetcher = AppScope.of(context).liveEpgFetcher;
    unawaited(_loadEpg(_current));
  }

  // ------------------------------------------------------------ 起播与换台

  Future<void> _init() async {
    try {
      final engine = MediaKitEngine();
      _engine = engine;
      final initResult = await engine.initialize(const PlayerConfig());
      if (initResult.isErr) {
        _fail(initResult.errorOrNull!.message);
        return;
      }

      // 直播也必须在 open 前挂上 VideoController，否则画面是黑的。
      _videoController = mkv.VideoController(engine.player);
      _switcher = LiveChannelSwitcher(probe: _probe);
      await _startChannel(widget.channel, isInitial: true);
    } on Object catch (e) {
      _fail(e.toString());
    }
  }

  /// 起播 / 换台到 [channel]。
  ///
  /// 首次起播与后续换台走**同一条路**：两条路各写一遍的话，「换台」这条迟早
  /// 会漏掉某个状态更新（线路标签、节目单、错误清理）。
  Future<void> _startChannel(
    LiveChannel channel, {
    bool isInitial = false,
  }) async {
    final switcher = _switcher;
    final engine = _engine;
    if (switcher == null || engine == null) return;

    // 换台时先清掉上一台的节目单：留着会让标题写「正在播 <上一台的节目>」，
    // 比不显示更误导。
    if (!isInitial && mounted) {
      setState(() => _epg = null);
    }

    final result = await switcher.switchTo(channel);
    if (!mounted) return;

    switch (result.status) {
      case LiveSwitchStatus.playing:
        setState(() {
          _channel = channel;
          _result = result;
          _fatalError = null;
          _notice = null;
          // 控制器与引擎同生命周期：换台只是换流，不必重建控制器（重建会
          // 丢掉音量/静音这些用户设置）。
          _controller ??= PlayerController(engine: engine)..attach();
        });
        unawaited(_loadEpg(channel));
      case LiveSwitchStatus.exhausted:
        if (isInitial) {
          setState(() => _result = result);
          _fail('所有线路都试过了，都播不了（共 ${result.lineCount} 条）');
        } else {
          // 换台失败**不夺走画面**：此时屏幕是黑的，但键盘还得能用，用户要
          // 能接着按 ↑/↓ 换回去。
          setState(() {
            _channel = channel;
            _result = result;
          });
          _showNotice('该频道 ${result.lineCount} 条线路都播不了');
        }
      case LiveSwitchStatus.cancelled:
        // 已被后续换台作废（或页面关了），什么都不用做。
        break;
    }
  }

  /// 试播一条线路：能打开就算通。
  ///
  /// 这是能做到的最好的近似 —— `open` 成功不等于画面已经出来，真正等首帧
  /// 需要播放器的帧回调（本环境跑不了 widget 测试，也就无法覆盖）。所以
  /// 「换台时保留上一路画面直到新流首帧」这条出口标准**尚未实现**：它需要
  /// 双播放器交替 + 首帧回调，属于 UI 层的活，不是这个类能兜住的。
  Future<bool> _probe(String url) async {
    final engine = _engine;
    if (engine == null) return false;
    try {
      final result = await engine.open(
        MediaSource(uri: Uri.parse(url), isLive: true),
      );
      return result.isOk;
    } on Object {
      return false;
    }
  }

  /// 拉某个频道的节目单。
  ///
  /// 与播放**并行**，不阻塞起播：EPG 是锦上添花，源站不收录这个台、接口挂了、
  /// 配置里根本没给 `epg` 都是常态，任何一种都不该让用户看不了电视。
  Future<void> _loadEpg(LiveChannel channel) async {
    final fetcher = _epgFetcher;
    if (fetcher == null || !fetcher.hasTemplates) return;
    try {
      final epg = await fetcher.loadFor(channel.id, channel.name);
      if (!mounted || epg == null) return;
      // 请求在飞的时候用户可能已经换台了：把上一台的节目单写到新台的标题上
      // 比不显示更糟，所以按频道 id 复核一次。
      if (channel.id != _current.id) return;
      setState(() => _epg = epg);
    } on Object {
      // 见上。
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _fatalError = message);
  }

  // ---------------------------------------------------------------- 键盘

  /// 页面级按键钩子：先问直播表，`null` 则让给播放器默认表。
  bool _handleKey(KeyEvent event) {
    final liveKey = liveKeyOf(event.logicalKey);
    if (liveKey == null) return false;
    final command = resolveLiveKey(
      liveKey,
      shift: HardwareKeyboard.instance.isShiftPressed,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      hasPendingDigits: !_numberBuffer.isEmpty,
    );
    if (command == null) return false;
    _runLiveCommand(command);
    return true;
  }

  void _runLiveCommand(LiveCommand command) {
    switch (command) {
      case PreviousChannelCommand():
        unawaited(_stepChannel(-1));
      case NextChannelCommand():
        unawaited(_stepChannel(1));
      case LiveDigitCommand(:final digit):
        setState(() {
          _numberBuffer.push(digit);
          _notice = null;
        });
        _restartNumberTimer();
      case CommitChannelNumberCommand():
        _commitChannelNumber();
      case CancelChannelNumberCommand():
        _cancelChannelNumber();
    }
  }

  /// 在可见列表上走 [step] 步换台。
  Future<void> _stepChannel(int step) async {
    final navigator = _navigator;
    if (navigator == null || navigator.isEmpty) {
      _showNotice('没有可切换的频道');
      return;
    }
    // 当前频道不在可见列表里（换了分组筛选）时 `indexOfId` 返回 null，
    // 交给 `moveFrom` 按「从第一个台出发」处理。
    final index = navigator.indexOfId(_current.id);
    final target = navigator.channelAt(navigator.moveFrom(index ?? -1, step));
    if (target == null) return;
    await _startChannel(target);
  }

  /// 确认数字缓冲里的频道号并跳台。
  void _commitChannelNumber() {
    _numberTimer?.cancel();
    _numberTimer = null;
    final number = _numberBuffer.value;
    if (mounted) {
      setState(() => _numberBuffer.clear());
    } else {
      _numberBuffer.clear();
    }
    if (number == null) return;

    final navigator = _navigator;
    final target = navigator == null
        ? null
        : navigator.channelAt(navigator.indexForNumber(number));
    if (target == null) {
      // 明确说「没有这个台」，而不是偷偷跳去第一个台。
      _showNotice('没有 $number 号频道');
      return;
    }
    if (target.id == _current.id) return;
    unawaited(_startChannel(target));
  }

  void _cancelChannelNumber() {
    _numberTimer?.cancel();
    _numberTimer = null;
    if (mounted) setState(() => _numberBuffer.clear());
  }

  void _restartNumberTimer() {
    _numberTimer?.cancel();
    _numberTimer = Timer(_numberCommitDelay, _commitChannelNumber);
  }

  void _showNotice(String message) {
    if (!mounted) return;
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(_noticeDuration, () {
      if (mounted) setState(() => _notice = null);
    });
  }

  @override
  void dispose() {
    // 作废还在跑的换台循环，否则它会在页面销毁后继续往播放器里塞流。
    _switcher?.cancel();
    _numberTimer?.cancel();
    _noticeTimer?.cancel();
    _controller?.dispose();
    final engine = _engine;
    if (engine != null) unawaited(engine.dispose());
    super.dispose();
  }

  // ---------------------------------------------------------------- 渲染

  @override
  Widget build(BuildContext context) {
    final fatalError = _fatalError;
    if (fatalError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  fatalError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => context.pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    final videoController = _videoController;
    if (controller == null || videoController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      children: [
        PlayerPage(
          controller: controller,
          videoArea: ColoredBox(
            color: Colors.black,
            child: mkv.Video(controller: videoController, controls: null),
          ),
          title: _title(),
          onKey: _handleKey,
        ),
        _buildOverlay(),
      ],
    );
  }

  /// 换台提示浮层。
  ///
  /// 刻意**不做成对话框**：数字键还在继续按，任何模态层都会抢走键盘焦点，
  /// 让「按 1 2 跳到 12 号台」在第二步就断了。
  Widget _buildOverlay() {
    final number = _numberBuffer.text;
    final notice = _notice;
    if (number.isEmpty && notice == null) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (notice != null) _pill(Text(notice)),
          if (number.isNotEmpty) ...[
            if (notice != null) const SizedBox(height: 8),
            _pill(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '跳转到频道 $number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter 确认 · Esc 取消 · Shift+↑/↓ 调音量',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  /// 标题带上当前线路与正在播的节目 —— 出口标准要求「UI 显示当前线路」，
  /// 节目单则是 EPG 唯一的用户可见出口。
  String _title() {
    final parts = <String>[_current.name];
    final label = _result?.lineLabel ?? '';
    if (label.isNotEmpty) parts.add(label);
    final program = _epg?.currentProgram;
    if (program != null && program.title.isNotEmpty) {
      parts.add('正在播 ${program.title}');
    }
    return parts.join(' · ');
  }
}
