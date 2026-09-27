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
      headers: const {
        // 不少封面图源带防盗链，按浏览器 UA 请求比 Flutter 默认的 Dart HttpClient
        // 更容易命中白名单，避免整片封面 403 白块。
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        // 这里是**网络图片解码完成**的淡入，规范 §2.4 的四档场景（悬停反馈 /
        // 页面切换 / 抽屉弹窗 / 播放器控制栏）都不覆盖它，所以刻意保留字面量，
        // 没有硬塞进某一档。要令牌化的话，先在规范里给它加一行。
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (_, _, _) => placeholder,
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
