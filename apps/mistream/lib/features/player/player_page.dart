/// 播放器页面：装配视频区 + 控制栏 + 自动隐藏 + 键盘快捷键。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mistream/features/player/player_controller.dart';
import 'package:mistream/features/player/player_shortcuts.dart';
import 'package:mistream/features/player/widgets/player_control_bar.dart';
import 'package:mistream/features/player/widgets/player_states.dart';

/// 播放器页面。
///
/// 组装三件事：
///
/// 1. **视频区**——[videoArea] 是具体渲染内核的挂载点（一期 `media_kit_video`、
///    二期自研纹理）。骨架期传入一个占位容器即可，本类不关心画面怎么来的。
/// 2. **控制栏**——3 秒无操作自动隐藏，鼠标移动/按键唤出；暂停/加载/出错时
///    不隐藏（`docs/04` §10、`docs/09` §5.5）。
/// 3. **键盘快捷键**——见 `docs/04` §9，映射表在 [resolvePlayerKey]。
///
/// 自动隐藏的计时器与指针/按键事件在**这里**做（它们属于交互形态而非播放状
/// 态）；「该不该藏」的纯判定在 [PlayerController.shouldHideControls]，两者
/// 分离让判定逻辑可脱离 widget 树单独测。
class PlayerPage extends StatefulWidget {
  /// 构造播放器页面。
  const PlayerPage({
    super.key,
    required this.controller,
    required this.videoArea,
    this.onToggleFullscreen,
    this.onScreenshot,
    this.title,
  });

  /// 播放控制器。
  final PlayerController controller;

  /// 视频渲染区。骨架期传占位容器，接入具体内核后传 `Video` widget。
  final Widget videoArea;

  /// 全屏切换；null 表示未接线（骨架期可留空）。
  final VoidCallback? onToggleFullscreen;

  /// 截图；null 表示未接线。
  final Future<void> Function()? onScreenshot;

  /// 正在播放的媒体标题。
  final String? title;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerController _controller = widget.controller;
  Timer? _hideTimer;
  final Stopwatch _stageElapsed = Stopwatch();
  bool _fullscreen = false;
  @override
  void initState() {
    super.initState();
    // 立即把控制栏显示出来；引擎流一来就有状态可渲染。
    _controller
      ..addListener(_maybeScheduleHide)
      ..addListener(_maybeShowNotice)
      ..showControls();
  }

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_maybeScheduleHide);
      oldWidget.controller.removeListener(_maybeShowNotice);
      _controller
        ..addListener(_maybeScheduleHide)
        ..addListener(_maybeShowNotice);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller
      ..removeListener(_maybeScheduleHide)
      ..removeListener(_maybeShowNotice);
    super.dispose();
  }

  /// 每次状态变化后评估自动隐藏。
  ///
  /// 定时器只在「播放中且没有挂着的隐藏计时」时才启动：位置流约 4Hz 推送，若
  /// 每次都重置计时，计时器将永远到不了点。暂停/结束/出错时取消计时并保持控制
  /// 栏可见。
  void _maybeScheduleHide() {
    _syncStageElapsed();
    if (_controller.isPlaying) {
      if (_hideTimer == null) _scheduleHide();
    } else {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (!_controller.isControlVisible) _controller.showControls();
    }
  }

  /// 非致命事件（如硬解降级）到点后飘一条提示并消费。
  ///
  /// `docs/04` §5 规则 2 要求硬解降级「在 UI 明确提示」，这里就是那个出口：
  /// [PlayerController.notice] 一非空就展示 SnackBar，随后
  /// `PlayerController.consumeNotice` 清空，避免每次位置流通知都重复弹。
  void _maybeShowNotice() {
    final err = _controller.notice;
    if (err == null || !mounted) return;
    _controller.consumeNotice();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(err.error.message)),
      );
  }

  /// 同步「当前阶段已耗时」：进入连接态开始计时，离开则停止并清零。
  void _syncStageElapsed() {
    final connecting = _controller.isConnecting;
    if (connecting && !_stageElapsed.isRunning) {
      _stageElapsed
        ..reset()
        ..start();
    } else if (!connecting && _stageElapsed.isRunning) {
      _stageElapsed
        ..stop()
        ..reset();
    }
  }

  /// 从「现在」起延迟 [PlayerController.autoHideDelay] 后隐藏。
  ///
  /// 判定「该不该藏」不再二次依赖真实时钟（widget 测试的假时钟与
  /// `DateTime.now()` 不一致会让判定永假）：计时器只在播放中启动、暂停/结束/
  /// 出错时被取消并唤出控制栏，到点即藏是安全的。
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_controller.autoHideDelay, () {
      _hideTimer = null;
      if (mounted && _controller.isControlVisible) {
        _controller.hideControls();
      }
    });
  }

  /// 任何指针/按键交互都唤出控制栏并重启倒计时。
  void _poke() {
    if (_controller.isControlVisible) {
      // 已显示：重置倒计时即可。
      _scheduleHide();
    } else {
      _controller.showControls();
    }
  }

  // -------------------------------------------------------------------
  // 快捷键
  // -------------------------------------------------------------------

  /// 一个按键压成命令并派发。
  Future<void> _dispatchKey(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool ctrl = false,
  }) async {
    final command = resolvePlayerKey(key, shift: shift, ctrl: ctrl);
    if (command == null) return;
    _poke();
    await _run(command);
  }

  Future<void> _run(PlayerCommand command) async {
    switch (command) {
      case TogglePlayPauseCommand():
        await _controller.togglePlayPause();
      case SeekCommand(:final delta):
        await _controller.seekBy(delta);
      case AdjustVolumeCommand(:final delta):
        await _controller.adjustVolumeBy(delta);
      case ToggleMuteCommand():
        await _controller.toggleMute();
      case ToggleFullscreenCommand():
        _toggleFullscreen();
      case ExitFullscreenCommand():
        if (_fullscreen) _toggleFullscreen();
      case AdjustRateCommand(:final steps):
        await _controller.adjustRateBy(0.25 * steps);
      case ResetRateCommand():
        await _controller.setRate(1);
      case StepFrameCommand(:final backward):
        await _controller.engine.stepFrame(backward: backward);
      case ScreenshotCommand():
        await widget.onScreenshot?.call();
      case ToggleSubtitleCommand() || NotYetWiredCommand():
        _toastNotYet();
    }
  }

  void _toggleFullscreen() {
    final callback = widget.onToggleFullscreen;
    if (callback == null) return;
    callback();
    setState(() => _fullscreen = !_fullscreen);
  }

  /// 骨架期占位：被未接线的按键/动作触发时给一句提示，避免键位无声消失。
  void _toastNotYet() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('此功能将在后续版本提供'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final logical = event.logicalKey;
        final shift = HardwareKeyboard.instance.isShiftPressed;
        final ctrl = HardwareKeyboard.instance.isControlPressed;
        unawaited(_dispatchKey(logical, shift: shift, ctrl: ctrl));
        // 所有已绑定键都吞掉，避免空格误触按钮、方向键滚动页面。
        return resolvePlayerKey(logical, shift: shift, ctrl: ctrl) == null
            ? KeyEventResult.ignored
            : KeyEventResult.handled;
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final controller = _controller;
    final state = controller.state;
    final error = controller.fatalError;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 视频区铺满
        Positioned.fill(child: widget.videoArea),

        // 顶部信息栏：标题 + 返回，随控制栏一起显隐。
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedOpacity(
            opacity: controller.isControlVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !controller.isControlVisible,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                        tooltip: '返回',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 错误必须优先于缓冲态，否则起播超时会一直被「缓冲中」遮住。
        if (error != null)
          Positioned.fill(
            child: PlayerErrorCard(
              error: error,
              title: widget.title,
              onCopyDiagnostics: () {
                final text = '${error.error.message}\n${error.error.code}';
                unawaited(Clipboard.setData(ClipboardData(text: text)));
              },
            ),
          )
        else if (controller.isConnecting)
          Positioned.fill(
            child: PlayerLoadingOverlay(
              state: state,
              elapsed: _stageElapsed.elapsed,
              title: widget.title,
            ),
          ),

        // 暂停时的中央播放按钮：随控制栏一起出现。
        if (!controller.isPlaying && controller.isControlVisible)
          Positioned.fill(
            child: Center(
              child: IconButton(
                onPressed: () {
                  _poke();
                  unawaited(_controller.togglePlayPause());
                },
                iconSize: 72,
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white70,
                ),
                tooltip: '播放',
              ),
            ),
          ),

        // 控制栏：底部，透明度随显示状态切换。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedOpacity(
            opacity: controller.isControlVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: PlayerControlBar(
              isPlaying: controller.isPlaying,
              position: controller.position,
              duration: controller.duration,
              buffered: controller.buffered,
              volume: controller.volume,
              muted: controller.isMuted,
              rate: controller.rate,
              isFullscreen: _fullscreen,
              onTogglePlayPause: () {
                _poke();
                unawaited(_controller.togglePlayPause());
              },
              onSeek: (target) {
                _poke();
                unawaited(_controller.seekTo(target));
              },
              onToggleMute: () {
                _poke();
                unawaited(_controller.toggleMute());
              },
              onAdjustVolume: (delta) {
                _poke();
                unawaited(_controller.adjustVolumeBy(delta));
              },
              onToggleFullscreen: () {
                _poke();
                _toggleFullscreen();
              },
            ),
          ),
        ),

        // 控制栏隐藏时：鼠标移动或任意触摸都唤出。
        if (!_controller.isControlVisible)
          Positioned.fill(
            child: MouseRegion(
              onHover: (_) => _poke(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _poke(),
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );
  }
}
