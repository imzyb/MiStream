/// 封面图组件：占位、淡入、失败回退统一处理。
library;

import 'package:flutter/material.dart';

/// 封面图。
///
/// 无 URL、加载中、加载失败都落到同一占位块（surfaceContainerHighest +
/// movie 图标），成功加载后淡入。所有网格/列表卡片的封面都应走这里，避免
/// 各处重复实现占位导致图片一多就白块闪烁。
class PosterImage extends StatelessWidget {
  /// 构造封面图。
  const PosterImage({
    super.key,
    this.url,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.iconSize = 32,
    this.aspectRatio,
  });

  /// 图片地址；null 时直接显示占位。
  final String? url;

  /// 图片填充方式。
  final BoxFit fit;

  /// 圆角；0 表示不裁剪。
  final double borderRadius;

  /// 占位图标尺寸。
  final double iconSize;

  /// 宽高比（宽/高）；null 时不约束，由父级决定尺寸。
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final placeholder = _placeholder(context);
    if (url == null) return placeholder;

    final image = Image.network(
      url!,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => placeholder,
    );

    final stacked = Stack(
      fit: StackFit.expand,
      children: [placeholder, image],
    );

    Widget result = stacked;
    if (aspectRatio != null) {
      result = AspectRatio(aspectRatio: aspectRatio!, child: result);
    }
    if (borderRadius <= 0) return result;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: result,
    );
  }

  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.movie,
          size: iconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
