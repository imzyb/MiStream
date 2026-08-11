/// 影片详情页：展示基本信息 + 剧集列表 + 播放入口。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mistream/app/app.dart';
import 'package:mistream/application/detail_use_case.dart';
import 'package:search_engine/search_engine.dart';

/// 影片详情页。
///
/// 通过 [siteId] 和 [vodId] 从 Spider API 获取详情，
/// 展示影片封面、简介、剧集列表。用户点击剧集后跳转播放页。
class DetailPage extends StatefulWidget {
  /// 构造详情页。
  const DetailPage({
    required this.siteId,
    required this.vodId,
    super.key,
    this.item,
  });

  /// 站点 ID，用于查找 API 地址。
  final int siteId;

  /// 影片 ID。
  final String vodId;

  /// 从搜索结果传入的摘要信息（可选，用于即时展示标题/封面）。
  final SearchItem? item;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool _loading = true;
  String? _error;
  VodDetail? _detail;
  int _selectedFlagIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    // 首次调用来自 post-frame 回调，页面可能已被弹出。
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AppScope.of(context).detailUseCase.load(
      siteId: widget.siteId,
      vodId: widget.vodId,
    );
    if (!mounted) return;

    result.fold(
      (detail) => setState(() {
        _loading = false;
        _detail = detail;
      }),
      (err) => setState(() {
        _loading = false;
        _error = err.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _ErrorView(message: error, onRetry: () => unawaited(_load()))
          : _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final detail = _detail!;

    return CustomScrollView(
      slivers: [
        // 顶部海报区域
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              detail.name,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (detail.pic != null)
                  Image.network(
                    detail.pic!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildPlaceholderPoster(theme),
                  )
                else
                  _buildPlaceholderPoster(theme),
                // 渐变遮罩
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xFF0D0F14)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 基本信息
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标签行
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (detail.year != null) _InfoChip(label: detail.year!),
                    if (detail.area != null) _InfoChip(label: detail.area!),
                    if (detail.genre != null) _InfoChip(label: detail.genre!),
                    if (detail.remarks != null)
                      _InfoChip(
                        label: detail.remarks!,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // 简介
                if (detail.description.isNotEmpty)
                  Text(
                    detail.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 播放源选择
        if (detail.flags.length > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: detail.flags.length,
                itemBuilder: (context, index) {
                  final flag = detail.flags[index];
                  final selected = index == _selectedFlagIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(flag),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedFlagIndex = index);
                      },
                    ),
                  );
                },
              ),
            ),
          ),

        // 剧集列表
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: _buildEpisodeGrid(detail, theme),
        ),
      ],
    );
  }

  Widget _buildEpisodeGrid(VodDetail detail, ThemeData theme) {
    final currentFlag = detail.flags.isNotEmpty
        ? detail.flags[_selectedFlagIndex]
        : '';
    final episodes = detail.episodes[currentFlag] ?? [];

    if (episodes.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('暂无剧集', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.2,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final ep = episodes[index];
          return _EpisodeCard(
            episode: ep,
            onTap: () => _playEpisode(ep, currentFlag),
          );
        },
        childCount: episodes.length,
      ),
    );
  }

  void _playEpisode(VodEpisode episode, String flag) {
    unawaited(
      context.pushNamed(
        'player',
        pathParameters: {
          'siteId': widget.siteId.toString(),
          'vodId': widget.vodId,
          'flag': flag,
        },
        extra: <String, Object?>{
          'episodeId': episode.id,
          'episodeName': episode.name,
          'vodName': _detail?.name,
          'vodPic': _detail?.pic,
        },
      ),
    );
  }

  Widget _buildPlaceholderPoster(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.movie,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 信息标签。
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color != null ? Colors.white : null,
        ),
      ),
    );
  }
}

/// 剧集卡片。
class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode, required this.onTap});

  final VodEpisode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              episode.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// 错误视图。
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
