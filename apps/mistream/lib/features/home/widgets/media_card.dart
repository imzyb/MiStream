/// 通用媒体卡片组件。
library;

import 'package:flutter/material.dart';

import 'package:mistream/features/common/common.dart' show PosterImage;

/// 媒体卡片：封面 + 标题 + 备注。
///
/// 封面统一走 [PosterImage]（占位 + 淡入），网格卡片都应使用本组件而不是
/// 各自内联 `Image.network`。
///
/// 桌面端悬停时封面轻微放大，并浮出播放遮罩，提供直观的可点反馈；触屏设备
/// 没有悬停概念，表现为普通卡片。
class MediaCard extends StatefulWidget {
  /// 构造媒体卡片。
  const MediaCard({
    super.key,
    required this.title,
    this.coverUrl,
    this.remarks,
    this.onTap,
  });

  /// 影片标题。
  final String title;

  /// 封面 URL；为空时显示占位图。
  final String? coverUrl;

  /// 角标备注（如「更新至 12 集」）。
  final String? remarks;

  /// 点击回调。
  final VoidCallback? onTap;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widget = this.widget;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  AnimatedScale(
                    scale: _hovered ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: PosterImage(
                      url: widget.coverUrl,
                      aspectRatio: 0.7,
                    ),
                  ),
                  // 悬停遮罩：暗化 + 居中播放图标。
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        color: Colors.black38,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 40,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (widget.remarks != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.remarks!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
