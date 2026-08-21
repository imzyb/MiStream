import 'package:live/src/live_channel.dart';
import 'package:live/src/live_epg.dart';
import 'package:live/src/live_group.dart';
import 'package:live/src/live_parser.dart';

/// 直播数据仓库接口。
abstract class LiveRepository {
  /// 获取所有频道。
  Future<List<LiveChannel>> getChannels();

  /// 获取所有分组。
  Future<List<LiveGroup>> getGroups();

  /// 按分组获取频道。
  Future<Map<LiveGroup, List<LiveChannel>>> getChannelsByGroup();

  /// 获取频道EPG。
  Future<LiveEpg?> getEpg(String channelId);

  /// 搜索频道。
  Future<List<LiveChannel>> searchChannels(String query);

  /// 添加频道到收藏。
  Future<void> addFavorite(String channelId);

  /// 移除收藏。
  Future<void> removeFavorite(String channelId);

  /// 获取收藏频道。
  Future<List<LiveChannel>> getFavorites();

  /// 导入M3U播放列表。
  Future<void> importM3u(String content, {String? sourceName});

  /// 刷新数据源。
  Future<void> refresh();
}

/// 内存实现的直播仓库（用于测试）。
class InMemoryLiveRepository implements LiveRepository {
  final List<LiveChannel> _channels = [];
  final List<LiveGroup> _groups = [];
  final List<LiveChannel> _favorites = [];
  final Map<String, LiveEpg> _epgCache = {};

  @override
  Future<List<LiveChannel>> getChannels() async => List.unmodifiable(_channels);

  @override
  Future<List<LiveGroup>> getGroups() async => List.unmodifiable(_groups);

  @override
  Future<Map<LiveGroup, List<LiveChannel>>> getChannelsByGroup() async {
    final result = <LiveGroup, List<LiveChannel>>{};
    for (final channel in _channels) {
      final group = _groups.where((g) => g.id == channel.groupId).firstOrNull;
      if (group != null) {
        result.putIfAbsent(group, () => []).add(channel);
      }
    }
    return result;
  }

  @override
  Future<LiveEpg?> getEpg(String channelId) async => _epgCache[channelId];

  @override
  Future<List<LiveChannel>> searchChannels(String query) async {
    final lower = query.toLowerCase();
    return _channels
        .where((c) => c.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Future<void> addFavorite(String channelId) async {
    final channel = _channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => throw StateError('Channel not found'),
    );
    if (!_favorites.contains(channel)) {
      _favorites.add(channel);
    }
  }

  @override
  Future<void> removeFavorite(String channelId) async {
    _favorites.removeWhere((c) => c.id == channelId);
  }

  @override
  Future<List<LiveChannel>> getFavorites() async =>
      List.unmodifiable(_favorites);

  @override
  Future<void> importM3u(String content, {String? sourceName}) async {
    final parser = LiveParser();
    final result = parser.parse(content);

    _channels.clear();
    _groups.clear();
    _channels.addAll(result.channels);
    _groups.addAll(result.groups);
  }

  @override
  Future<void> refresh() async {
    // 内存实现无需刷新
  }
}
