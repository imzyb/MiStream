/// 进度条：已播放、缓冲区间、拖拽 seek。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:player_engine/player_engine.dart';

/// 播放进度条。
///
/// 三件事：
///
/// 1. 显示当前 [position] 与总时长 [duration] 的比例；
/// 2. 显示 [buffered] 各区间（`docs/04-播放器设计.md` §10：进度条要显示缓冲
///    区间）；
/// 3. 点击/拖拽 seek——方向由 [onSeek] 交给上层，本 widget 只负责把「手指落在
///    宽度的几分之几」换算成「跳到总时长的几分之几」。
///
/// 无媒体（[duration] 为零）时整条禁触，防误触 seek 到无处可去。
class PlayerSeekBar extends StatelessWidget {
  /// 构造进度条。
  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
    this.height = 24,
  });

  /// 当前播放位置。
  final Duration position;

  /// 总时长；[Duration.zero] 表示未知/直播，整条禁用。
  final Duration duration;

  /// 已缓冲区间（可能多段，seek 后常见）。
  final List<DurationRange> buffered;

  /// 拖拽结束时的回调，参数是目标位置。
  final ValueChanged<Duration> onSeek;

  /// 可拖拽区域高度。视觉上把进度条做在中间，上下留出触控余量。
  final double height;

  bool get _enabled => duration > Duration.zero;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '播放进度',
      hint: '点击或拖动调整播放位置',
      child: MouseRegion(
        cursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled
              ? (d) => _seekFromPosition(context, d.localPosition)
              : null,
          onHorizontalDragStart: _enabled
              ? (d) => _seekFromPosition(context, d.localPosition)
              : null,
          onHorizontalDragUpdate: _enabled
              ? (d) => _seekFromPosition(context, d.localPosition)
              : null,
          onHorizontalDragEnd: _enabled ? (_) {} : null,
          child: SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final fraction = _fraction(position, width);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // 底轨
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 缓冲区间
                    ..._bufferedRanges(width),
                    // 已播放
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // 进度圆点
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 缓冲区间渲染：每段一个绝对定位的条。
  List<Widget> _bufferedRanges(double width) {
    if (!_enabled || buffered.isEmpty) return const [];
    return [
      for (final range in buffered)
        Positioned(
          left: _fraction(range.start, width) * width,
          width: max(
            0,
            (_fraction(range.end, width) - _fraction(range.start, width)) *
                width,
          ),
          top: 10,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
    ];
  }

  double _fraction(Duration value, double width) {
    if (duration <= Duration.zero) return 0;
    return (value.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
  }

  void _seekFromPosition(BuildContext context, Offset local) {
    if (!_enabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final width = box.size.width;
    if (width <= 0) return;
    final ratio = (local.dx / width).clamp(0.0, 1.0);
    final target = Duration(
      microseconds: (duration.inMicroseconds * ratio).round(),
    );
    onSeek(target);
  }
}
