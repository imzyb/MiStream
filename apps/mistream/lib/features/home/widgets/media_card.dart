/// 通用媒体卡片组件。
library;

import 'package:flutter/material.dart';

import 'package:mistream/features/common/common.dart' show PosterImage;

/// 媒体卡片：封面 + 标题 + 备注。
///
/// 封面统一走 [PosterImage]（占位 + 淡入），网格卡片都应使用本组件而不是
/// 各自内联 `Image.network`。
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.title,
    this.coverUrl,
    this.remarks,
    this.onTap,
  });

  final String title;
  final String? coverUrl;
  final String? remarks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PosterImage(
            url: coverUrl,
            borderRadius: 8,
            aspectRatio: 0.7,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          if (remarks != null) ...[
            const SizedBox(height: 2),
            Text(
              remarks!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
