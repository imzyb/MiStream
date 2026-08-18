/// 资源库页面：收藏 + 播放历史。
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:storage/storage.dart';

import 'package:mistream/app/router.dart' show globalRouterAssembly;
import 'package:mistream/application/app_assembly.dart' show AppAssembly;
import 'package:mistream/features/library/widgets/library_tile.dart';

/// 全局装配实例，供资源库页使用。
AppAssembly? _globalLibraryAssembly;

/// 获取全局装配实例。
AppAssembly? get globalLibraryAssembly => _globalLibraryAssembly;

/// 设置全局装配实例。
void setGlobalLibraryAssembly(AppAssembly? assembly) {
  _globalLibraryAssembly = assembly;
}

/// 资源库页面：收藏列表 + 播放历史。
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  bool _loading = true;

  List<Favorite> _favorites = [];
  List<History> _histories = [];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    final assembly = globalLibraryAssembly ?? globalRouterAssembly;
    if (assembly == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final favorites = await assembly.repositories.favorites.byFolder('');
      final histories = await assembly.repositories.histories.recent(
        limit: 200,
      );

      if (mounted) {
        setState(() {
          _favorites = favorites;
          _histories = histories;
          _loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('加载失败: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _removeFavorite(Favorite favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消收藏'),
        content: Text('确定要取消收藏《${favorite.vodName}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取消收藏'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = AppDatabase.inMemory();
      final repositories = Repositories(db);
      await repositories.favorites.deleteVod(favorite.siteId, favorite.vodId);
      await db.close();

      setState(() => _favorites.removeWhere((f) => f.id == favorite.id));
      _showError('已取消收藏');
    } on Object catch (e) {
      _showError('操作失败: $e');
    }
  }

  Future<void> _removeHistory(History history) async {
    try {
      final db = AppDatabase.inMemory();
      final repositories = Repositories(db);
      await repositories.histories.deleteVod(history.siteId, history.vodId);
      await db.close();

      setState(() => _histories.removeWhere((h) => h.id == history.id));
    } on Object catch (e) {
      _showError('删除失败: $e');
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有播放历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = AppDatabase.inMemory();
      final repositories = Repositories(db);
      await repositories.histories.clear();
      await db.close();

      setState(() => _histories.clear());
      _showError('历史已清空');
    } on Object catch (e) {
      _showError('清空失败: $e');
    }
  }

  void _playHistory(History history) {
    context.pushNamed(
      'detail',
      pathParameters: {
        'siteId': history.siteId.toString(),
        'vodId': history.vodId,
      },
      extra: <String, Object?>{
        'episodeId': history.flag ?? '',
        'episodeName': history.episodeName ?? '',
        'vodName': history.vodName,
        'vodPic': history.vodPic,
      },
    );
  }

  void _playFavorite(Favorite favorite) {
    context.pushNamed(
      'detail',
      pathParameters: {
        'siteId': favorite.siteId.toString(),
        'vodId': favorite.vodId,
      },
      extra: <String, Object?>{
        'episodeId': '',
        'episodeName': '',
        'vodName': favorite.vodName,
        'vodPic': favorite.vodPic,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资源库'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '收藏'),
            Tab(text: '历史'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 收藏
                _favorites.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.favorite_outline,
                        title: '暂无收藏',
                        subtitle: '在详情页点击收藏按钮添加',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _favorites.length,
                        itemBuilder: (context, index) {
                          final fav = _favorites[index];
                          return LibraryTile(
                            title: fav.vodName,
                            subtitle: fav.vodRemarks ?? '无更新信息',
                            coverUrl: fav.vodPic,
                            onTap: () => _playFavorite(fav),
                            onLongPress: () => _removeFavorite(fav),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeFavorite(fav),
                              tooltip: '取消收藏',
                            ),
                          );
                        },
                      ),

                // 历史
                _histories.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.history,
                        title: '暂无播放历史',
                        subtitle: '观看视频后将自动记录',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _histories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _histories.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: OutlinedButton.icon(
                                onPressed: _clearAllHistory,
                                icon: const Icon(Icons.delete_sweep_outlined),
                                label: const Text('清空历史'),
                              ),
                            );
                          }
                          final hist = _histories[index];
                          final progress = hist.durationMs > 0
                              ? hist.positionMs / hist.durationMs
                              : 0.0;
                          return LibraryTile(
                            title: hist.vodName,
                            subtitle: hist.episodeName ?? '未知剧集',
                            coverUrl: hist.vodPic,
                            progress: progress,
                            onTap: () => _playHistory(hist),
                            onLongPress: () => _removeHistory(hist),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeHistory(hist),
                              tooltip: '删除记录',
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
