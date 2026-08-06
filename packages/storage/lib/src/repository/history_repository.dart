import 'package:drift/drift.dart';

import 'package:storage/src/database/database.dart';

/// `history` 表：播放历史仓储。
///
/// 语义见 `docs/07-数据库设计.md` §3.3：同一 `(site, vod)` 只保留一条，随播放更新
/// （历史是「最近看到哪」而非流水账）。
class HistoryRepository {
  /// 持有底层数据库连接。
  HistoryRepository(this.db);

  /// 底层数据库连接。
  final AppDatabase db;

  /// 按最近播放时间倒序取最近 [limit] 条历史。
  Future<List<History>> recent({int limit = 20}) async {
    final query = db.select(db.histories)
      ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
      ..limit(limit);
    return query.get();
  }

  /// 按 `(siteId, vodId)` 取单条历史；不存在返回 null。
  Future<History?> byVod(int siteId, String vodId) async {
    return (db.select(db.histories)
          ..where((t) => t.siteId.equals(siteId) & t.vodId.equals(vodId)))
        .getSingleOrNull();
  }

  /// 记录/更新一次播放进度。
  ///
  /// 已存在则更新剧集与位置；未存在则插入。返回最终落库行。
  Future<History> upsert({
    required int siteId,
    required String vodId,
    required String vodName,
    String? vodPic,
    String? flag,
    int episodeIndex = 0,
    String? episodeName,
    int positionMs = 0,
    int durationMs = 0,
    bool finished = false,
    double? playRate,
    DateTime? playedAt,
  }) async {
    final existing = await byVod(siteId, vodId);
    final now = DateTime.now().toUtc();
    final companion = HistoriesCompanion(
      siteId: Value(siteId),
      vodId: Value(vodId),
      vodName: Value(vodName),
      vodPic: Value(vodPic),
      flag: Value(flag ?? existing?.flag),
      episodeIndex: Value(episodeIndex),
      episodeName: Value(episodeName),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      finished: Value(finished),
      playRate: Value(playRate ?? existing?.playRate),
      playedAt: Value(playedAt ?? now),
      createdAt: Value(existing?.createdAt ?? now),
    );

    await db
        .into(db.histories)
        .insert(
          companion,
          onConflict: DoUpdate(
            (old) => companion,
            target: [db.histories.siteId, db.histories.vodId],
          ),
        );

    return (await byVod(siteId, vodId))!;
  }

  /// 删除一条历史（按 `(siteId, vodId)`）。
  Future<void> deleteVod(int siteId, String vodId) async {
    await (db.delete(
      db.histories,
    )..where((t) => t.siteId.equals(siteId) & t.vodId.equals(vodId))).go();
  }

  /// 清空全部历史。
  Future<int> clear() => db.delete(db.histories).go();
}
