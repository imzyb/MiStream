/// 控制栏：播放/暂停、进度条、音量、倍速、全屏，及时间显示。
library;

import 'package:flutter/material.dart';
import 'package:mistream/features/player/widgets/player_seek_bar.dart';
import 'package:player_engine/player_engine.dart';

/// 把秒格式化成 `H:MM:SS` / `M:SS`。负值按零处理。
String formatDuration(Duration d) {
  var s = d.inSeconds;
  if (s < 0) s = 0;
  final hours = s ~/ 3600;
  final minutes = (s % 3600) ~/ 60;
  final seconds = s % 60;

  String two(int v) => v.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${two(minutes)}:${two(seconds)}';
  }
  return '$minutes:${two(seconds)}';
}

/// 播放控制栏。
///
/// 本 widget 无状态、纯展示 + 上抛回调：真正的状态在 `PlayerController`，这里
/// 只管把值显示出来、把手势换成对 `PlayerController` 命令的调用。这样它既能在
/// widget 测试里直接喂假值，也不和 controller 的生命周期/自动隐藏纠缠。
class PlayerControlBar extends StatelessWidget {
  /// 构造控制栏。所有回调均为必填：控制栏不是给自己看的功能件，按钮按下去
  /// 该做什么由持有 controller 的父级决定。
  const PlayerControlBar({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.volume,
    required this.muted,
    required this.rate,
    required this.onTogglePlayPause,
    required this.onSeek,
    required this.onToggleMute,
    required this.onAdjustVolume,
    required this.onToggleFullscreen,
    this.isFullscreen = false,
  });

  /// 是否处于播放/缓冲中（决定播放/暂停图标）。
  final bool isPlaying;

  /// 当前播放位置。
  final Duration position;

  /// 总时长。
  final Duration duration;

  /// 已缓冲区间。
  final List<DurationRange> buffered;

  /// 当前音量（0..1.5）。
  final double volume;

  /// 当前是否静音。
  final bool muted;

  /// 当前倍速。
  final double rate;

  /// 播放/暂停按钮回调。
  final VoidCallback onTogglePlayPause;

  /// 进度条 seek 回调。
  final ValueChanged<Duration> onSeek;

  /// 静音切换回调。
  final VoidCallback onToggleMute;

  /// 音量增减回调。
  final ValueChanged<double> onAdjustVolume;

  /// 全屏切换回调。
  final VoidCallback onToggleFullscreen;

  /// 是否已全屏（决定全屏图标方向）。
  final bool isFullscreen;

  IconData get _playIcon =>
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;

  /// 音量图标随值变化（静音/低/高）。
  IconData get _volumeIcon {
    if (muted || volume <= 0) return Icons.volume_off_rounded;
    if (volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // `docs/09-UI规范.md` §2.1 color.overlay：控制栏遮罩 rgba(0,0,0,0.6)。
        color: Colors.black.withValues(alpha: 0.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerSeekBar(
            position: position,
            duration: duration,
            buffered: buffered,
            onSeek: onSeek,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: isPlaying ? '暂停' : '播放',
                onPressed: onTogglePlayPause,
                icon: Icon(_playIcon, color: Colors.white, size: 28),
              ),
              Text(
                '${formatDuration(position)} / ${formatDuration(duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                '${rate}x',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: muted ? '取消静音' : '静音',
                onPressed: onToggleMute,
                icon: Icon(_volumeIcon, color: Colors.white),
              ),
              Text(
                '${(volume * 100).round()}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: isFullscreen ? '退出全屏' : '全屏',
                onPressed: onToggleFullscreen,
                icon: Icon(
                  isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
