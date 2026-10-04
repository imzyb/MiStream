/// 资源库页面：收藏 + 播放历史。
library;

import 'dart:async' show unawaited;

import 'package:core_domain/core_domain.dart' show EpisodeIndex;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mistream/app/router.dart' show globalRouterAssembly;
import 'package:mistream/application/app_assembly.dart' show AppAssembly;
import 'package:mistream/features/common/common.dart' show EmptyView;
import 'package:mistream/features/library/widgets/library_tile.dart';
import 'package:storage/storage.dart'; // ignore: layering -- 临时直连存储，M10后迁至 Application 层

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
        _showMessage('加载失败: $e');
      }
    }
  }

  void _showMessage(String message) {
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
      final assembly = globalLibraryAssembly ?? globalRouterAssembly;
      if (assembly == null) return;
      await assembly.repositories.favorites.deleteVod(
        favorite.siteId,
        favorite.vodId,
      );

      setState(() => _favorites.removeWhere((f) => f.id == favorite.id));
      _showMessage('已取消收藏');
    } on Object catch (e) {
      _showMessage('操作失败: $e');
    }
  }

  Future<void> _removeHistory(History history) async {
    try {
      final assembly = globalLibraryAssembly ?? globalRouterAssembly;
      if (assembly == null) return;
      await assembly.repositories.histories.deleteVod(
        history.siteId,
        history.vodId,
      );

      setState(() => _histories.removeWhere((h) => h.id == history.id));
    } on Object catch (e) {
      _showMessage('删除失败: $e');
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
      final assembly = globalLibraryAssembly ?? globalRouterAssembly;
      if (assembly == null) return;
      await assembly.repositories.histories.clear();

      setState(() => _histories.clear());
      _showMessage('历史已清空');
    } on Object catch (e) {
      _showMessage('清空失败: $e');
    }
  }

  /// 历史记录点进去直接续播。
  ///
  /// 走 `player` 而不是 `detail`：`History` 里已经存了线路名（`flag`）与集号
  /// （`episodeIndex`），足够直接起播。此前这里 push 的是 `detail`，而 extra
  /// 用的却是播放路由的键名——detail 路由只认 `SearchItem`，整个 extra 被丢弃，
  /// 「继续播放」实际只是打开了详情页。
  void _playHistory(History history) {
    final flag = history.flag;
    // 早期记录可能没写线路名，此时没有足够信息起播，退回详情页让用户自己选。
    if (flag == null || flag.isEmpty) {
      _openDetail(history.siteId, history.vodId);
      return;
    }
    unawaited(
      context.pushNamed(
        'player',
        pathParameters: {
          'siteId': history.siteId.toString(),
          'vodId': history.vodId,
          'flag': flag,
        },
        extra: <String, Object?>{
          // 集号来自落库的 episodeIndex。**不要**用 flag 充当集号——线路名与
          // 集号是两套语义，此前就是这么传错的。
          'episodeId': EpisodeIndex.of(history.episodeIndex).asId,
          'episodeName': history.episodeName ?? '',
          'vodName': history.vodName,
          'vodPic': history.vodPic,
        },
      ),
    );
  }

  /// 收藏没有线路名与集号，只能先进详情页。
  void _playFavorite(Favorite favorite) =>
      _openDetail(favorite.siteId, favorite.vodId);

  /// 打开详情页；线路与剧集由详情页自己加载，不需要额外参数。
  void _openDetail(int siteId, String vodId) {
    unawaited(
      context.pushNamed(
        'detail',
        pathParameters: {'siteId': siteId.toString(), 'vodId': vodId},
      ),
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
                if (_favorites.isEmpty)
                  const EmptyView(
                    icon: Icons.favorite_outline,
                    title: '暂无收藏',
                    subtitle: '在详情页点击收藏按钮添加',
                  )
                else
                  ListView.builder(
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
                if (_histories.isEmpty)
                  const EmptyView(
                    icon: Icons.history,
                    title: '暂无播放历史',
                    subtitle: '观看视频后将自动记录',
                  )
                else
                  ListView.builder(
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
}
