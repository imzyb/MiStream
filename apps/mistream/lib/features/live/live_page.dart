/// 直播页：分组筛选 + 频道列表 + 导入订阅。
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:live/live.dart';
import 'package:mistream/app/app.dart' show AppScope;
import 'package:mistream/features/common/common.dart'
    show EmptyView, ErrorView, LoadingView;

/// 直播页。
class LivePage extends StatefulWidget {
  /// 构造直播页。
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  late LiveRepository _repository;
  late LiveImporter _importer;
  bool _depsReady = false;

  List<LiveChannel> _channels = [];
  List<LiveGroup> _groups = [];
  Map<String, String> _groupNameById = {};
  Set<String> _favoriteIds = {};
  LiveGroup? _selectedGroup;
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    final assembly = AppScope.of(context);
    _repository = assembly.liveRepository;
    _importer = assembly.liveImporter;
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _channels = await _repository.getChannels();
      _groups = await _repository.getGroups();
      _groupNameById = {for (final g in _groups) g.id: g.name};
      _favoriteIds = (await _repository.getFavorites())
          .map((c) => c.id)
          .toSet();

      // 选中的分组可能已经不存在了（重新导入后分组 id 全变），要清掉，
      // 否则会停在一个空列表上，看起来像「导入把频道弄没了」。
      if (_selectedGroup != null &&
          !_groups.any((g) => g.id == _selectedGroup!.id)) {
        _selectedGroup = null;
      }

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
            icon: const Icon(Icons.playlist_add),
            tooltip: '导入订阅',
            onPressed: _importPlaylist,
          ),
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
        subtitle: '导入订阅地址或 M3U 播放列表即可开始收看',
        action: FilledButton.icon(
          onPressed: _importPlaylist,
          icon: const Icon(Icons.add),
          label: const Text('导入订阅'),
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
              label: Text('全部 (${_channels.length})'),
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
      itemBuilder: (context, index) => _buildChannelTile(channels[index]),
    );
  }

  Widget _buildChannelTile(LiveChannel channel) {
    return ListTile(
      leading: _buildChannelLogo(channel),
      title: Text(channel.name),
      subtitle: Text(_subtitleFor(channel)),
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
            onPressed: () => unawaited(_toggleFavorite(channel)),
          ),
        ],
      ),
      onTap: () => _playChannel(channel),
    );
  }

  /// 副标题：分组名 + 线路数。
  ///
  /// 显示**分组名**而不是 `groupId`：落库后 groupId 是数据库自增主键，
  /// 直接显示出来是一串数字。多线路时把线路数也带上，用户才知道这个台有
  /// 备用源（播放页会自动按序重试）。
  String _subtitleFor(LiveChannel channel) {
    final id = channel.groupId;
    final group = id == null ? null : _groupNameById[id];
    final parts = <String>[group ?? '未分组'];
    final lineCount = channel.allUrls.length;
    if (lineCount > 1) parts.add('$lineCount 条线路');
    return parts.join(' · ');
  }

  Widget _buildChannelLogo(LiveChannel channel) {
    final logo = channel.logo;
    if (logo != null && logo.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(logo),
        onBackgroundImageError: (_, _) {},
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('收藏操作失败: $e')));
      }
    }
  }

  void _playChannel(LiveChannel channel) {
    unawaited(
      context.pushNamed(
        'live_player',
        extra: <String, Object?>{'channel': channel},
      ),
    );
  }

  Future<void> _importPlaylist() async {
    final controller = TextEditingController();
    final imported = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入直播源'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '粘贴订阅地址（http/https）或 M3U/txt 内容',
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
        final report = await _importer.import([LiveSubscription(url: text)]);
        if (!mounted) return;
        await _loadData();
        if (mounted) _showMessage(_describe(report));
        return;
      }
      await _repository.importM3u(text);
      await _loadData();
      if (mounted) _showMessage('导入成功');
    } on Object catch (e) {
      if (mounted) _showMessage('导入失败: $e');
    }
  }

  /// 把导入报告说成人话。
  String _describe(LiveImportReport report) {
    if (report.allFailed) {
      final failed = report.outcomes.firstWhere((o) => !o.isOk);
      return '导入失败：${failed.error}';
    }
    final parts = <String>['已导入 ${report.channelCount} 个频道'];
    if (report.hasFailure) {
      parts.add('${report.failedCount} 个源失败');
    }
    return parts.join('，');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
