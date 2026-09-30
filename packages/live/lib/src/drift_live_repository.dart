import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:live/src/live_channel.dart';
import 'package:live/src/live_epg.dart';
import 'package:live/src/live_group.dart';
import 'package:live/src/live_parser.dart';
import 'package:live/src/live_repository.dart';
import 'package:storage/storage.dart' as db;

/// 把一组播放地址编码进 `live_channel.urls_json`。
///
/// 用 JSON 数组而不是分隔符拼接：播放地址里本来就可能带 `,` `;` `|` `#`
/// （`&amp;`、`?a=1,b=2`、HLS 变体列表），任何分隔符方案都必然有歧义 ——
/// 这正是 [splitUrls] 要在解析侧绕的那些坑，不该在落库侧再造一遍。
String encodeLiveUrls(List<String> urls) => jsonEncode(urls);

/// 解析 `live_channel.urls_json`。
///
/// 兼容两种历史形态：
/// 1. JSON 数组（当前实现）→ 全部地址；
/// 2. 裸 URL 字符串（旧实现把主地址直接塞进这一列，多地址全丢）→ 单地址。
///
/// 第 2 种必须留着：老用户的库里就是这么存的，读不出来的话升级后整个直播
/// 列表会变成空频道。
List<String> decodeLiveUrls(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return const [];
  if (value.startsWith('[')) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } on FormatException {
      // 不像合法 JSON（比如地址本身以 `[` 开头），落到下面按裸 URL 处理。
    }
  }
  return [value];
}

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
      const db.LiveChannelsCompanion(favorite: Value(true)),
    );
  }

  @override
  Future<void> removeFavorite(String channelId) async {
    final id = int.tryParse(channelId);
    if (id == null) return;
    await (_db.update(_db.liveChannels)..where((t) => t.id.equals(id))).write(
      const db.LiveChannelsCompanion(favorite: Value(false)),
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
    await replaceAll(LiveParser().parse(content));
  }

  @override
  Future<void> replaceAll(LiveParseResult result) async {
    await _db.transaction(() async {
      // 收藏是**用户行为**，不该被一次「刷新订阅」抹掉。整体重建会让行主键
      // 全变，所以只能靠业务键恢复 —— 用**频道名**而不是地址：用户收藏的是
      // 「这个台」，源换了线路还是同一个台，按地址恢复等于每次换源都丢收藏。
      //
      // 代价是同名不同台会误判为同一个收藏。真实直播源里同名基本就是同一个
      // 台（实测 CCTV1 在一个源里挂 3 条地址，在另一个源里是另一批地址）。
      final favoriteNames = {
        for (final row in await (_db.select(
          _db.liveChannels,
        )..where((t) => t.favorite.equals(true))).get())
          row.name,
      };

      await _db.delete(_db.liveChannels).go();
      await _db.delete(_db.liveGroups).go();

      final groupIdByName = <String, int>{};
      for (final group in result.groups) {
        groupIdByName[group.name] = await _db
            .into(_db.liveGroups)
            .insert(
              db.LiveGroupsCompanion.insert(
                name: group.name,
                sortOrder: Value(group.order),
              ),
            );
      }

      // 未分组频道必须有落点：`live_channel.group_id` 是 NOT NULL（外键指向
      // `live_group`）。旧实现遇到 `groupId == null` 直接 `continue`，结果
      // 这些频道在「全部」列表里也一起消失了 —— 用户看到的是「导入了但少了
      // 一半频道」，而且分组视图与总数的差刚好等于未分组数，很难往这里想。
      final hasUngrouped = result.channels.any((c) => c.groupId == null);
      final int? ungroupedId = hasUngrouped
          ? await _db
                .into(_db.liveGroups)
                .insert(
                  db.LiveGroupsCompanion.insert(
                    name: LiveParseResult.ungroupedGroup.name,
                    sortOrder: Value(LiveParseResult.ungroupedGroup.order),
                  ),
                )
          : null;

      final rows = <db.LiveChannelsCompanion>[];
      for (final channel in result.channels) {
        final groupId = channel.groupId == null
            ? ungroupedId
            : groupIdByName[channel.groupId];
        if (groupId == null) continue;
        rows.add(
          db.LiveChannelsCompanion.insert(
            groupId: groupId,
            name: channel.name,
            logo: Value(channel.logo),
            // 列名是 `urls_json`（复数）—— 设计上就是多地址。旧实现只写主
            // 地址，备用线路在落库这一步就没了，「多线路自动重试」自然永远
            // 只有一条线可试。
            urlsJson: encodeLiveUrls(channel.allUrls),
            epgId: Value(channel.id),
            favorite: Value(favoriteNames.contains(channel.name)),
          ),
        );
      }
      await _db.batch((b) => b.insertAll(_db.liveChannels, rows));
    });
  }

  @override
  Future<void> refresh() async {}

  LiveChannel _channelFromRow(db.LiveChannel row) {
    final urls = decodeLiveUrls(row.urlsJson);
    return LiveChannel(
      id: row.id.toString(),
      name: row.name,
      url: urls.isEmpty ? '' : urls.first,
      extraUrls: urls.length > 1 ? urls.sublist(1) : const [],
      logo: row.logo,
      groupId: row.groupId.toString(),
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
