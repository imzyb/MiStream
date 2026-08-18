import 'package:flutter/material.dart';
import 'package:live/live.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final LiveRepository _repository = InMemoryLiveRepository();
  List<LiveChannel> _channels = [];
  List<LiveGroup> _groups = [];
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

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
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
        title: const Text('Live TV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tv, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No channels available'),
            const SizedBox(height: 8),
            const Text('Import an M3U playlist to get started'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _importPlaylist,
              icon: const Icon(Icons.add),
              label: const Text('Import Playlist'),
            ),
          ],
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
              label: const Text('All'),
              selected: _selectedGroup == null,
              onSelected: (selected) {
                setState(() {
                  _selectedGroup = null;
                });
              },
            ),
          ),
          ..._groups.map(
            (group) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(group.name),
                selected: _selectedGroup?.id == group.id,
                onSelected: (selected) {
                  setState(() {
                    _selectedGroup = selected ? group : null;
                  });
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
      return const Center(child: Text('No channels in this group'));
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

  bool _isFavorite(LiveChannel channel) {
    // TODO: Check from repository
    return false;
  }

  Future<void> _toggleFavorite(LiveChannel channel) async {
    if (_isFavorite(channel)) {
      await _repository.removeFavorite(channel.id);
    } else {
      await _repository.addFavorite(channel.id);
    }
    setState(() {});
  }

  void _playChannel(LiveChannel channel) {
    // TODO: Navigate to player
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing: ${channel.name}')),
    );
  }

  void _importPlaylist() {
    // TODO: Show import dialog
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Playlist'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: 'Paste M3U URL or content',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Import playlist
              Navigator.pop(context);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}
