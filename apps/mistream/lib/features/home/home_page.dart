/// 首页：推荐轮播 + 分类入口 + 分类详情。
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mistream/app/router.dart' show globalRouterAssembly;
import 'package:mistream/application/app_assembly.dart' show AppAssembly;
import 'package:mistream/application/jvm_runtime_status.dart'
    show JvmRuntimeStatus;
import 'package:mistream/features/common/common.dart'
    show
        BreakpointContext, // ignore: unused_shown_name -- 提供 context.isDesktop 扩展
        EmptyView,
        ErrorView,
        ResponsiveGridView,
        ResponsiveHorizontalList;
import 'package:mistream/features/home/widgets/home_section.dart';
import 'package:mistream/features/home/widgets/media_card.dart';
import 'package:search_engine/search_engine.dart';

/// 全局装配实例，供首页使用。
AppAssembly? _globalHomeAssembly;

/// 获取全局装配实例。
AppAssembly? get globalHomeAssembly => _globalHomeAssembly;

/// 设置全局装配实例。
void setGlobalHomeAssembly(AppAssembly? assembly) {
  _globalHomeAssembly = assembly;
}

/// 首页：展示推荐、分类与分类详情。
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.assembly});

  /// 注入的装配（测试或上级注入），为空时回退到全局装配。
  final AppAssembly? assembly;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;
  List<HomeItem> _recommends = [];
  List<CategoryItem> _categories = [];
  final Map<String, List<HomeItem>> _categoryDetails = {};
  final Map<String, int> _categoryPages = {};
  List<SourceOption> _availableSites = [];
  SourceOption? _currentSite;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  AppAssembly? get _assembly =>
      widget.assembly ?? globalHomeAssembly ?? globalRouterAssembly;

  Future<void> _loadData({bool forceRefresh = false}) async {
    final assembly = _assembly;
    if (assembly == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (forceRefresh) assembly.homeUseCase.clearCache();

    try {
      // 片源选择器列出**全部**启用站点，这里不预先过滤——否则用户看不到
      // 「有源但不支持」这件事。但「支持与否」只有一把尺子：`listSources`
      // 给出的 `isUsable`（= `HomeUseCase._siteHasRuntime`）既决定选择器里
      // 哪些可点，也决定取数时哪些会被试。两者必须同口径，否则会出现
      // 「能点但必然失败」或「点不到却仍被取数」这类各写一半的状态。
      _availableSites = await assembly.homeUseCase.listSources();

      final homeResult = await assembly.homeUseCase.getHomeData(
        siteId: _currentSite?.id,
      );

      var recommends = <HomeItem>[];
      var categories = <CategoryItem>[];

      homeResult.fold(
        (ok) {
          recommends = ok.recommends;
          categories = ok.categories;
        },
        (err) => _error = err.message,
      );

      final workingSiteId = assembly.homeUseCase.workingSiteId;
      if (workingSiteId != null) {
        _currentSite = _availableSites
            .where((site) => site.id == workingSiteId)
            .firstOrNull;
      }

      // 预加载前 3 个分类的第一页
      final detailFutures = <Future<void>>[];
      for (final cat in categories.take(3)) {
        detailFutures.add(
          _loadCategoryDetail(cat.typeId, siteId: workingSiteId),
        );
      }
      await Future.wait(detailFutures);

      if (mounted) {
        setState(() {
          _recommends = recommends;
          _categories = categories;
          _loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败: $e';
        });
      }
    }
  }

  Future<void> _loadCategoryDetail(
    String typeId, {
    int page = 1,
    int? siteId,
  }) async {
    final assembly = _assembly;
    if (assembly == null) return;

    final result = await assembly.homeUseCase.getCategoryDetail(
      typeId: typeId,
      page: page,
      siteId: siteId ?? _currentSite?.id,
    );

    result.fold(
      (ok) {
        if (mounted) {
          setState(() {
            _categoryDetails[typeId] = ok.items;
            _categoryPages[typeId] = ok.page;
          });
        }
      },
      (err) {
        // 静默失败，不阻塞其他分类
        debugPrint('分类 $typeId 加载失败: ${err.message}');
      },
    );
  }

  void _navigateToCategoryDetail(CategoryItem category) {
    final siteId = _currentSite?.id;
    if (siteId == null) return;
    context.pushNamed(
      'category_detail',
      pathParameters: {
        'siteId': '$siteId',
        'typeId': category.typeId,
      },
      extra: category.typeName,
    );
  }

  void _navigateToDetail(HomeItem item) {
    final assembly = _assembly;
    if (assembly == null) return;
    // 用「实际取数成功的那个站点」的 id，而不是列表里的第一个：首页数据可能
    // 来自轮询中的第 N 个源，拿错 id 会让详情页去一个空站点上查这条影片。
    final siteId = assembly.homeUseCase.workingSiteId;
    if (siteId == null) return;
    context.pushNamed(
      'detail',
      pathParameters: {
        'siteId': '$siteId',
        'vodId': item.vodId,
      },
    );
  }

  void _showSourcePicker() {
    if (_availableSites.isEmpty) return;
    final unusableCount = _availableSites.where((s) => !s.isUsable).length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('切换片源 (${_availableSites.length}个)'),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 有不可用站点才提示，且提示必须说清**缺什么、怎么办**。
              // 只灰显不给引导，用户看到的是一整屏完全相同的「不可用」——
              // 分不清是配置坏了、软件坏了还是少装了个可选组件。
              // ADR-006 的「后果」一节把这条写成了硬要求。
              if (unusableCount > 0)
                _UnavailableSourcesNotice(
                  count: unusableCount,
                  status: _assembly?.jvmRuntimeStatus,
                ),
              // 用 ConstrainedBox 限高而不是 Flexible：AlertDialog 会把 content
              // 包进 IntrinsicWidth，而本机 flutter test 起不来（OS error 231），
              // 我没法实测「IntrinsicWidth + flex 子项」是否稳。ConstrainedBox
              // 不参与 flex 布局，行为可以纯靠读代码确定。高度随窗口缩放，避免
              // 小窗口下 notice + 列表把弹窗撑溢出。
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableSites.length,
                  itemBuilder: (ctx, i) {
                    final site = _availableSites[i];
                    final isSelected = site.id == _currentSite?.id;
                    final usable = site.isUsable;
                    return ListTile(
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              site.name,
                              style: TextStyle(
                                color: usable
                                    ? null
                                    : Theme.of(ctx).disabledColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (site.isExperimentalJar) ...[
                            const SizedBox(width: 6),
                            const _ExperimentalJarChip(),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        usable
                            ? site.api
                            : '${site.api} · '
                                  '${site.unavailableReason ?? '暂不支持'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(ctx).colorScheme.primary,
                            )
                          : null,
                      onTap: usable
                          ? () => unawaited(_confirmAndSwitch(ctx, site))
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切换片源；jar 源先要一次**显式确认**。
  ///
  /// ADR-006 决策第 4 条：「UI 中对 jar 源标注『实验性 · 二进制不可审计』，
  /// 需用户显式确认后才加载」。这里就是那次确认 —— 不是走过场的提示框，
  /// 而是把「不可审计」这件事讲明白再让用户决定。
  Future<void> _confirmAndSwitch(
    BuildContext pickerCtx,
    SourceOption site,
  ) async {
    if (site.isExperimentalJar) {
      final confirmed = await showDialog<bool>(
        context: pickerCtx,
        builder: (confirmCtx) => AlertDialog(
          title: const Text('实验性 · 二进制不可审计'),
          content: const Text(
            '这个片源来自闭源 jar 二进制，MiStream 无法审计它做了什么。\n\n'
            '当前只承诺「纯 Java 逻辑 + 已 shim 的 android API 子集」可运行，'
            '不承诺任意 jar 可用（见 ADR-006）。\n\n'
            '确认后才会加载。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(confirmCtx, true),
              child: const Text('仍然使用'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!pickerCtx.mounted) return;
    Navigator.pop(pickerCtx);
    _switchSource(site);
  }

  /// 全部分类弹窗：首页只展示前 8 个，这里给出完整清单。
  void _showAllCategories() {
    final siteId = _currentSite?.id;
    if (siteId == null || _categories.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全部分类'),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        content: SizedBox(
          width: 480,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              return _CategoryCard(
                category: cat,
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToCategoryDetail(cat);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _switchSource(SourceOption site) {
    if (site.id == _currentSite?.id) return;
    setState(() {
      _currentSite = site;
      _loading = true;
      _error = null;
      _recommends = [];
      _categories = [];
      _categoryDetails.clear();
    });
    unawaited(_loadData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _availableSites.isNotEmpty
            ? GestureDetector(
                onTap: _showSourcePicker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentSite?.name ?? 'MiStream',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              )
            : const Text('MiStream'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.pushNamed('search'),
            tooltip: '搜索',
          ),
        ],
      ),
      body: _loading
          ? const _HomeSkeleton()
          : _error != null
          ? ErrorView(
              message: _error!,
              onRetry: () => _loadData(forceRefresh: true),
            )
          : RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              child: CustomScrollView(
                slivers: [
                  // 空数据引导：片源不可用或配置里没有内容时给用户去处。
                  if (_recommends.isEmpty && _categories.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        icon: Icons.movie_outlined,
                        title: '暂无内容',
                        subtitle: '首页数据为空，请检查片源是否可用或切换片源',
                        action: Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            if (_availableSites.isNotEmpty)
                              FilledButton.tonalIcon(
                                onPressed: _showSourcePicker,
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('切换片源'),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => unawaited(_loadData()),
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 推荐轮播
                  if (_recommends.isNotEmpty)
                    HomeSection(
                      title: '为你推荐',
                      child: SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _recommends.length,
                          itemBuilder: (context, index) {
                            final item = _recommends[index];
                            return MediaCard(
                              title: item.vodName,
                              coverUrl: item.vodPic,
                              remarks: item.vodRemarks,
                              onTap: () => _navigateToDetail(item),
                            );
                          },
                        ),
                      ),
                    ),

                  // 分类网格
                  if (_categories.isNotEmpty)
                    HomeSection(
                      title: '分类',
                      action: TextButton(
                        onPressed: _showAllCategories,
                        child: const Text('查看全部'),
                      ),
                      child: ResponsiveGridView(
                        itemCount: _categories.length.clamp(0, 8),
                        // HomePage 位于 CustomScrollView 的 SliverToBoxAdapter
                        // 内，内部 GridView 必须收缩包裹，否则会拿到无限高度。
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          return _CategoryCard(
                            category: cat,
                            onTap: () => _navigateToCategoryDetail(cat),
                          );
                        },
                      ),
                    ),

                  // 分类详情（前 3 个）
                  ..._categories.take(3).map((cat) {
                    final items = _categoryDetails[cat.typeId] ?? [];
                    if (items.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return HomeSection(
                      title: cat.typeName,
                      action: TextButton(
                        onPressed: () => _navigateToCategoryDetail(cat),
                        child: const Text('更多'),
                      ),
                      child: ResponsiveHorizontalList(
                        itemCount: items.length.clamp(0, 10),
                        itemWidth: 120,
                        spacing: 8,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return MediaCard(
                            title: item.vodName,
                            coverUrl: item.vodPic,
                            remarks: item.vodRemarks,
                            onTap: () => _navigateToDetail(item),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

/// 首页骨架屏：加载时用静态占位块勾勒版面，避免整页白屏/转圈。
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: block(width: 96, height: 20),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, _) => block(width: 120),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: block(width: 64, height: 20),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(8, (_) => block(width: 72, height: 36)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「实验性 · 二进制不可审计」标记。
///
/// ADR-006 要求这个定性**出现在 UI 上**（另外两处是 README 与 ROADMAP），
/// 且 jar 源即使运行时齐备也要用户显式确认后才加载。放在片源名旁边而不是
/// 塞进副标题，是因为副标题在窄窗口会被省略号截掉 —— 定性一旦被截掉，
/// 「不可审计」这个警告就等于没写。
class _ExperimentalJarChip extends StatelessWidget {
  const _ExperimentalJarChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '实验性 · 二进制不可审计',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}

/// 片源不可用时的说明条：讲清缺什么、怎么补。
///
/// 文案取自 `JvmRuntimeStatus.missingItems`，而不是在这里再判一遍 —— 判定逻辑
/// 只能有一处，否则界面说的和实际做的迟早会不一致。
class _UnavailableSourcesNotice extends StatelessWidget {
  const _UnavailableSourcesNotice({required this.count, this.status});

  /// 不可用的片源数量。
  final int count;

  /// JVM 运行时快照；装配不可用时为 `null`。
  final JvmRuntimeStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = status?.missingItems ?? const <String>[];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count 个片源当前不可用',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            missing.isEmpty
                ? '这些片源所需的运行时未就绪。'
                : missing.map((item) => '· $item').join('\n'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// 分类卡片（网格）。
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final CategoryItem category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          category.typeName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
