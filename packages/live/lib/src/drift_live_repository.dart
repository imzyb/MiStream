import 'package:drift/drift.dart';
// ignore: depend_on_referenced_packages
import 'package:storage/storage.dart' as db;

import 'live_channel.dart';
import 'live_group.dart';
import 'live_epg.dart';
import 'live_parser.dart';
import 'live_repository.dart';

/// Drift-backed implementation of [LiveRepository].
///
/// Maps between the domain [LiveChannel]/[LiveGroup] models (String IDs)
/// and the drift [db.LiveChannels]/[db.LiveGroups] tables (int IDs).
class DriftLiveRepository implements LiveRepository {
  DriftLiveRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<List<LiveChannel>> getChannels() async {
    final rows = await _db.select(_db.liveChannels).get();
    return rows.map(_channelFromRow).toList();
  }

  @override
  Future<List<LiveGroup>> getGroups() async {
    final rows = await _db.select(_db.liveGroups).get();
    return rows.map(_groupFromRow).toList();
  }

  @override
  Future<Map<LiveGroup, List<LiveChannel>>> getChannelsByGroup() async {
    final channels = await getChannels();
    final groups = await getGroups();
    final groupMap = {for (final g in groups) g.id: g};
    final result = <LiveGroup, List<LiveChannel>>{};
    for (final channel in channels) {
      final group = groupMap[channel.groupId];
      if (group != null) {
        result.putIfAbsent(group, () => []).add(channel);
      }
    }
    return result;
  }

  @override
  Future<LiveEpg?> getEpg(String channelId) async {
    return null;
  }

  @override
  Future<List<LiveChannel>> searchChannels(String query) async {
    final lower = query.toLowerCase();
    final rows = await (_db.select(
      _db.liveChannels,
    )..where((t) => t.name.lower().like('%$lower%'))).get();
    return rows.map(_channelFromRow).toList();
  }

  @override
  Future<void> addFavorite(String channelId) async {
    final id = int.tryParse(channelId);
    if (id == null) return;
    await (_db.update(_db.liveChannels)..where((t) => t.id.equals(id))).write(
      db.LiveChannelsCompanion(favorite: const Value(true)),
    );
  }

  @override
  Future<void> removeFavorite(String channelId) async {
    final id = int.tryParse(channelId);
    if (id == null) return;
    await (_db.update(_db.liveChannels)..where((t) => t.id.equals(id))).write(
      db.LiveChannelsCompanion(favorite: const Value(false)),
    );
  }

  @override
  Future<List<LiveChannel>> getFavorites() async {
    final rows = await (_db.select(
      _db.liveChannels,
    )..where((t) => t.favorite.equals(true))).get();
    return rows.map(_channelFromRow).toList();
  }

  @override
  Future<void> importM3u(String content, {String? sourceName}) async {
    final parser = LiveParser();
    final result = parser.parse(content);

    await _db.transaction(() async {
      await _db.delete(_db.liveChannels).go();
      await _db.delete(_db.liveGroups).go();

      for (final group in result.groups) {
        await _db
            .into(_db.liveGroups)
            .insert(
              db.LiveGroupsCompanion.insert(
                name: group.name,
                sortOrder: Value(group.order),
              ),
            );
      }

      final dbGroups = await _db.select(_db.liveGroups).get();
      final groupNameToId = {for (final g in dbGroups) g.name: g.id};

      for (final channel in result.channels) {
        final groupId = channel.groupId != null
            ? groupNameToId[channel.groupId]
            : null;
        if (groupId == null) continue;

        await _db
            .into(_db.liveChannels)
            .insert(
              db.LiveChannelsCompanion.insert(
                groupId: groupId,
                name: channel.name,
                logo: Value(channel.logo),
                urlsJson: channel.url,
                epgId: Value(channel.id),
                favorite: Value(false),
              ),
            );
      }
    });
  }

  @override
  Future<void> refresh() async {}

  LiveChannel _channelFromRow(db.LiveChannel row) {
    return LiveChannel(
      id: row.id.toString(),
      name: row.name,
      url: row.urlsJson,
      logo: row.logo,
      groupId: row.groupId.toString(),
      isHd: false,
      updatedAt: null,
    );
  }

  LiveGroup _groupFromRow(db.LiveGroup row) {
    return LiveGroup(
      id: row.id.toString(),
      name: row.name,
      order: row.sortOrder,
    );
  }
}
