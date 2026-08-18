/// 直播页：分组筛选 + 频道列表 + 导入 M3U。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:live/live.dart';

import 'package:mistream/features/common/common.dart'
    show LoadingView, EmptyView, ErrorView;

/// 直播页。
class LivePage extends StatefulWidget {
  /// 构造直播页。
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final LiveRepository _repository = InMemoryLiveRepository();
  List<LiveChannel> _channels = [];
  List<LiveGroup> _groups = [];
  Set<String> _favoriteIds = {};
  LiveGroup? _selectedGroup;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _channels = await _repository.getChannels();
      _groups = await _repository.getGroups();
      _favoriteIds = (await _repository.getFavorites())
          .map((c) => c.id)
          .toSet();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<LiveChannel> get _filteredChannels {
    if (_selectedGroup == null) return _channels;
    return _channels.where((c) => c.groupId == _selectedGroup!.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('直播'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingView(message: '正在加载直播源…');

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadData);
    }

    if (_channels.isEmpty) {
      return EmptyView(
        icon: Icons.tv,
        title: '暂无直播源',
        subtitle: '导入 M3U 播放列表即可开始收看',
        action: FilledButton.icon(
          onPressed: _importPlaylist,
          icon: const Icon(Icons.add),
          label: const Text('导入播放列表'),
        ),
      );
    }

    return Column(
      children: [
        if (_groups.isNotEmpty) _buildGroupTabs(),
        Expanded(child: _buildChannelList()),
      ],
    );
  }

  Widget _buildGroupTabs() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('全部'),
              selected: _selectedGroup == null,
              onSelected: (_) => setState(() => _selectedGroup = null),
            ),
          ),
          ..._groups.map(
            (group) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(group.name),
                selected: _selectedGroup?.id == group.id,
                onSelected: (selected) {
                  setState(() => _selectedGroup = selected ? group : null);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList() {
    final channels = _filteredChannels;

    if (channels.isEmpty) {
      return const EmptyView(icon: Icons.tv, title: '该分组暂无频道');
    }

    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _buildChannelTile(channel);
      },
    );
  }

  Widget _buildChannelTile(LiveChannel channel) {
    return ListTile(
      leading: _buildChannelLogo(channel),
      title: Text(channel.name),
      subtitle: Text(channel.groupId ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (channel.isHd)
            const Chip(
              label: Text('HD', style: TextStyle(fontSize: 10)),
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            tooltip: _isFavorite(channel) ? '取消收藏' : '收藏',
            icon: Icon(
              _isFavorite(channel) ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite(channel) ? Colors.red : null,
            ),
            onPressed: () => _toggleFavorite(channel),
          ),
        ],
      ),
      onTap: () => _playChannel(channel),
    );
  }

  Widget _buildChannelLogo(LiveChannel channel) {
    if (channel.logo != null && channel.logo!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(channel.logo!),
        onBackgroundImageError: (_, __) {},
        child: Text(channel.name.substring(0, 1)),
      );
    }
    return CircleAvatar(child: Text(channel.name.substring(0, 1)));
  }

  bool _isFavorite(LiveChannel channel) => _favoriteIds.contains(channel.id);

  Future<void> _toggleFavorite(LiveChannel channel) async {
    try {
      if (_isFavorite(channel)) {
        await _repository.removeFavorite(channel.id);
      } else {
        await _repository.addFavorite(channel.id);
      }
      final ids = (await _repository.getFavorites()).map((c) => c.id).toSet();
      if (mounted) setState(() => _favoriteIds = ids);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('收藏操作失败: $e')),
        );
      }
    }
  }

  void _playChannel(LiveChannel channel) {
    context.pushNamed(
      'live_player',
      extra: <String, Object?>{'url': channel.url, 'title': channel.name},
    );
  }

  Future<void> _importPlaylist() async {
    final controller = TextEditingController();
    final imported = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入播放列表'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '粘贴 M3U 内容或 URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (imported != true) return;

    final text = controller.text.trim();
    if (text.isEmpty) return;

    try {
      if (text.startsWith('http://') || text.startsWith('https://')) {
        // TODO(M7)：从 URL 拉取 M3U 内容；当前仅支持粘贴内容。
        _showMessage('暂不支持从 URL 导入，请粘贴 M3U 内容');
        return;
      }
      await _repository.importM3u(text);
      await _loadData();
      _showMessage('导入成功');
    } on Object catch (e) {
      _showMessage('导入失败: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
