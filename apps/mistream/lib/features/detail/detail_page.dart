/// 影片详情页：展示基本信息 + 剧集列表 + 播放入口。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mistream/app/app.dart';
import 'package:mistream/application/detail_use_case.dart';
import 'package:mistream/application/download_use_case.dart';
import 'package:mistream/features/common/common.dart'
    show ErrorView, PosterImage, ResponsiveGridPresets, ResponsiveSliverGrid;
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
    this.useCase,
    this.downloadUseCase,
  });

  /// 站点 ID，用于查找 API 地址。
  final int siteId;

  /// 影片 ID。
  final String vodId;

  /// 从搜索结果传入的摘要信息（可选，用于即时展示标题/封面）。
  final SearchItem? item;

  /// 可注入的详情用例（测试用）；`null` 时取 [AppScope] 装配里的默认实现。
  final DetailUseCase? useCase;

  /// 可注入的下载用例（测试用）；`null` 时取 [AppScope] 装配里的默认实现。
  final DownloadUseCase? downloadUseCase;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool _loading = true;
  String? _error;
  VodDetail? _detail;
  int _selectedFlagIndex = 0;
  bool _descriptionExpanded = false;
  bool? _favorite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  @override
  void didUpdateWidget(DetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换片源走的是 `replaceNamed`（路由参数变、页面栈不增长）。go_router 对
    // 同一路由模板复用同一个 page key，于是 State 会被复用、`initState` 不再跑
    // ——不在这里补一次加载，换了片源页面会停在上一部片的详情上。
    if (oldWidget.siteId != widget.siteId || oldWidget.vodId != widget.vodId) {
      _selectedFlagIndex = 0;
      _descriptionExpanded = false;
      _detail = null;
      _favorite = null;
      _loading = true;
      _error = null;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    // 首次调用来自 post-frame 回调，页面可能已被弹出。
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final useCase = widget.useCase ?? AppScope.of(context).detailUseCase;
    final result = await useCase.load(
      siteId: widget.siteId,
      vodId: widget.vodId,
    );
    if (!mounted) return;

    result.fold(
      (detail) => setState(() {
        _loading = false;
        _detail = detail;
        // 默认选 m3u8 线路：share/网页线路返回的是播放页而不是媒体流，
        // 直接喂给 mpv 打不开（需要嗅探器，见 media_sniffer）。
        _selectedFlagIndex = _preferredFlagIndex(detail.flags);
      }),
      (err) => setState(() {
        _loading = false;
        _error = err.message;
      }),
    );

    unawaited(_refreshFavorite());
  }

  Future<void> _refreshFavorite() async {
    try {
      final liked = await AppScope.of(
        context,
      ).repositories.favorites.isFavorite(widget.siteId, widget.vodId);
      if (mounted) setState(() => _favorite = liked);
    } on Object {
      // 收藏状态读取失败不影响详情浏览，保持未知态（收藏按钮禁用）。
    }
  }

  Future<void> _toggleFavorite() async {
    final detail = _detail;
    if (detail == null) return;
    final liked = _favorite ?? false;
    final repo = AppScope.of(context).repositories.favorites;
    try {
      if (liked) {
        await repo.remove(widget.siteId, widget.vodId);
      } else {
        await repo.add(
          siteId: widget.siteId,
          vodId: widget.vodId,
          vodName: detail.name,
          vodPic: detail.pic,
          vodRemarks: detail.remarks,
        );
      }
      if (mounted) setState(() => _favorite = !liked);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('收藏操作失败: $e')),
        );
      }
    }
  }

  /// 优先返回名字里带 `m3u8` 的线路索引，找不到则回 0。
  static int _preferredFlagIndex(List<String> flags) {
    for (var i = 0; i < flags.length; i++) {
      if (flags[i].toLowerCase().contains('m3u8')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;

    return Scaffold(
      body: _loading
          ? const _DetailSkeleton()
          : error != null
          ? ErrorView(message: error, onRetry: () => unawaited(_load()))
          : _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final detail = _detail!;

    return CustomScrollView(
      slivers: [
        // 顶部海报区域
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 72,
              bottom: 12,
            ),
            title: Text(
              detail.name,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                PosterImage(url: detail.pic),
                // 渐变遮罩：尾部接到页面背景色，明暗主题都成立。
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        theme.colorScheme.surface,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: (_favorite ?? false) ? '取消收藏' : '收藏',
              onPressed: _favorite == null ? null : _toggleFavorite,
              icon: Icon(
                (_favorite ?? false) ? Icons.favorite : Icons.favorite_border,
                color: (_favorite ?? false)
                    ? Colors.redAccent
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
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
                // 简介（可展开）
                if (detail.description.isNotEmpty)
                  _buildDescription(detail.description, theme),
              ],
            ),
          ),
        ),

        // 片源切换：只在「同片多源」时出现（搜索合并了多个源的同一部片）。
        // 与下面的「线路」是两回事——线路是**同一个源里**的不同播放通道，
        // 片源是**不同的站点**，同一部片在不同站点上的清晰度/完整度可能差很多。
        if (_alternativeSources.isNotEmpty)
          SliverToBoxAdapter(child: _buildSourcePicker(theme)),

        // 线路选择
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
        if (_episodes.isEmpty)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('暂无剧集', style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          ResponsiveSliverGrid(
            config: ResponsiveGridPresets.detailEpisodes,
            childAspectRatio: 2.2,
            itemCount: _episodes.length,
            itemBuilder: (context, index) {
              final ep = _episodes[index];
              final flag = _currentFlag;
              return _EpisodeCard(
                episode: ep,
                onTap: () => _playEpisode(ep, flag),
                onMenu: (position) =>
                    unawaited(_showEpisodeMenu(ep, flag, position)),
              );
            },
          ),
      ],
    );
  }

  VodDetail get _detailOrNull => _detail!;

  String get _currentFlag => _detailOrNull.flags.isNotEmpty
      ? _detailOrNull.flags[_selectedFlagIndex]
      : '';

  List<VodEpisode> get _episodes {
    final flag = _currentFlag;
    return _detailOrNull.episodes[flag] ?? [];
  }

  /// 搜索结果带来的「同片多源」列表。
  ///
  /// 只有一个源（或不是从搜索进来的）时返回空——多一行只有单个选项的 chip
  /// 只是噪音。
  List<SearchSourceRef> get _alternativeSources {
    final sources = widget.item?.sources ?? const <SearchSourceRef>[];
    return sources.length > 1 ? sources : const <SearchSourceRef>[];
  }

  bool _isCurrentSource(SearchSourceRef source) =>
      source.sourceId == widget.siteId && source.vodId == widget.vodId;

  /// 换到另一个片源。
  ///
  /// 用 `replaceNamed` 而不是 `pushNamed`：切源是「换个角度看同一部片」，不是
  /// 层层深入的导航，堆栈里堆一串详情页只会让返回键变得难用。`extra` 要跟着
  /// 传，否则切一次源后源列表就丢了，再也切不回去。
  void _switchSource(SearchSourceRef source) {
    if (_isCurrentSource(source)) return;
    context.replaceNamed(
      'detail',
      pathParameters: {
        'siteId': source.sourceId.toString(),
        'vodId': source.vodId,
      },
      extra: widget.item,
    );
  }

  Widget _buildSourcePicker(ThemeData theme) {
    final sources = _alternativeSources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            '片源（${sources.length}）',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(source.sourceName),
                  selected: _isCurrentSource(source),
                  onSelected: (_) => _switchSource(source),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDescription(String description, ThemeData theme) {
    final collapsed = !_descriptionExpanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          maxLines: collapsed ? 4 : null,
          overflow: collapsed ? TextOverflow.ellipsis : null,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () =>
                setState(() => _descriptionExpanded = !_descriptionExpanded),
            child: Text(_descriptionExpanded ? '收起' : '展开'),
          ),
        ),
      ],
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

  // -------------------------------------------------------------------
  // 下载
  // -------------------------------------------------------------------

  /// 剧集卡片的右键/长按菜单。
  ///
  /// 下载入口挂在**集**上而不是「整部片」上：播放也是按集点的，而 `download`
  /// 表要记的正是「哪一集」（`episode_name`）—— 没有它，同一部剧下回来的
  /// 文件在列表里长得一模一样，也去不了重。
  ///
  /// 「已在下载列表」这一项做成**禁用**而不是隐藏：用户第二次点的时候要看到
  /// 「为什么点不动」，而不是以为菜单坏了。状态由 `findExisting` 先问再做，
  /// 所以点下去之前就能画对。
  Future<void> _showEpisodeMenu(
    VodEpisode episode,
    String flag,
    Offset globalPosition,
  ) async {
    final detail = _detail;
    if (detail == null) return;
    final useCase =
        widget.downloadUseCase ?? AppScope.of(context).downloadUseCase;
    final request = DownloadRequest(
      siteId: widget.siteId,
      vodId: widget.vodId,
      flag: flag,
      vodName: detail.name,
      episodeId: episode.id,
      episodeName: episode.name,
    );
    final existing = useCase.findExisting(request);

    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'download',
          enabled: existing == null,
          child: Text(existing == null ? '下载本集' : '已在下载列表'),
        ),
      ],
    );
    if (action != 'download' || !mounted) return;

    final result = await useCase.addEpisode(request);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    result.fold(
      (task) => messenger.showSnackBar(
        SnackBar(content: Text('已加入下载：${task.displayName}')),
      ),
      (error) => messenger.showSnackBar(
        SnackBar(content: Text('加入下载失败：${error.message}')),
      ),
    );
  }
}

/// 详情页骨架屏：加载时用静态占位块勾勒海报区、标签、简介与剧集网格。
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blockColor = theme.colorScheme.surfaceContainerHighest;

    Widget block({double? width, double? height, double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: blockColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部海报区域
          SizedBox(
            width: double.infinity,
            height: 280,
            child: block(radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(width: 160, height: 20),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 8,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 20,
                      child: _SkeletonBlock(),
                    ),
                    SizedBox(
                      width: 64,
                      height: 20,
                      child: _SkeletonBlock(),
                    ),
                    SizedBox(
                      width: 56,
                      height: 20,
                      child: _SkeletonBlock(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SkeletonLine(widthFactor: 1),
                const SizedBox(height: 8),
                const _SkeletonLine(widthFactor: 0.9),
                const SizedBox(height: 8),
                const _SkeletonLine(widthFactor: 0.6),
                const SizedBox(height: 24),
                // 剧集网格占位
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      12,
                      (_) => const SizedBox(
                        width: 64,
                        height: 28,
                        child: _SkeletonBlock(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 骨架占位块（读取父级颜色，避免重复取色）。
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// 骨架文本行：按 [widthFactor] 比例占宽。
class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: const SizedBox(
        height: 12,
        child: _SkeletonBlock(),
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
  const _EpisodeCard({
    required this.episode,
    required this.onTap,
    this.onMenu,
  });

  final VodEpisode episode;
  final VoidCallback onTap;

  /// 右键 / 长按回调，参数是触发位置的全局坐标（菜单要贴着它弹）。
  final void Function(Offset globalPosition)? onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onMenu = this.onMenu;
    return GestureDetector(
      // 触屏长按走外层：`InkWell` 没有带坐标的长按回调，而菜单要贴着触发点弹。
      // 两层不冲突 —— 短按由 `InkWell` 的 tap 认领，长按只有这里认领。
      onLongPressStart: onMenu == null
          ? null
          : (details) => onMenu(details.globalPosition),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // 桌面端右键。两条路径都通到同一个菜单，只做右键的话触屏上这个
          // 功能等于不存在。
          onSecondaryTapDown: onMenu == null
              ? null
              : (details) => onMenu(details.globalPosition),
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
      ),
    );
  }
}
