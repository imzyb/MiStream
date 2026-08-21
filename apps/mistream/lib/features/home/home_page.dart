/// 首页：推荐轮播 + 分类入口 + 分类详情。
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mistream/app/router.dart' show globalRouterAssembly;
import 'package:mistream/application/app_assembly.dart' show AppAssembly;
import 'package:mistream/features/common/common.dart'
    show
        BreakpointContext,
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
      // 片源选择器列出全部启用站点；能否实际取数由 HomeUseCase 逐个试，
      // 这里不预先过滤，否则用户看不到「有源但不支持」这件事。
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('切换片源 (${_availableSites.length}个)'),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: SizedBox(
          width: 420,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableSites.length,
            itemBuilder: (ctx, i) {
              final site = _availableSites[i];
              final isSelected = site.id == _currentSite?.id;
              final usable = site.isUsable;
              return ListTile(
                title: Text(
                  site.name,
                  style: TextStyle(
                    color: usable ? null : Theme.of(ctx).disabledColor,
                  ),
                ),
                subtitle: Text(
                  usable ? site.api : '${site.api} (暂不支持)',
                  maxLines: 1,
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
                    ? () {
                        Navigator.pop(ctx);
                        _switchSource(site);
                      }
                    : null,
              );
            },
          ),
        ),
      ),
    );
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
        actions: context.isDesktop
            // 桌面端搜索/设置已移到左侧导航栏，避免同一图标出现两次。
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.pushNamed('search'),
                  tooltip: '搜索',
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => context.pushNamed('settings'),
                  tooltip: '设置',
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
