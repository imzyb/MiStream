import 'package:drift/drift.dart';

import 'package:storage/src/database/database.dart';

/// `favorite` 表：收藏仓储。
///
/// 语义见 `docs/07-数据库设计.md` §3.4：同一 `(site, vod)` 只保留一条，`folder`
/// 分组（`''` 为默认），`vod_remarks` vs `latest_remarks` 的差异即「有更新」判定。
class FavoriteRepository {
  /// 持有底层数据库连接。
  FavoriteRepository(this.db);

  /// 底层数据库连接。
  final AppDatabase db;

  /// 取某收藏夹下的收藏（默认夹 `folder=''`），按 [Favorite.folder]/sortOrder 排序。
  Future<List<Favorite>> byFolder(String folder, {int limit = 200}) async {
    final query = db.select(db.favorites)
      ..where((t) => t.folder.equals(folder))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
      ..limit(limit);
    return query.get();
  }

  /// 全部收藏夹名（去重）。
  Future<List<String>> folders() async {
    final rows = await db
        .customSelect(
          'SELECT DISTINCT folder FROM favorite ORDER BY folder',
        )
        .get();
    return rows.map((r) => r.data['folder']! as String).toList();
  }

  /// 是否已收藏 `(siteId, vodId)`。
  Future<bool> isFavorite(int siteId, String vodId) async {
    return (await byVod(siteId, vodId)) != null;
  }

  /// 按 `(siteId, vodId)` 取收藏；不存在返回 null。
  Future<Favorite?> byVod(int siteId, String vodId) async {
    return (db.select(db.favorites)
          ..where((t) => t.siteId.equals(siteId) & t.vodId.equals(vodId)))
        .getSingleOrNull();
  }

  /// 收藏一项（已存在则更新剧集信息，不重复插入）。
  Future<Favorite> add({
    required int siteId,
    required String vodId,
    required String vodName,
    String? vodPic,
    String? vodRemarks,
    String folder = '',
  }) async {
    final existing = await byVod(siteId, vodId);
    final companion = FavoritesCompanion(
      siteId: Value(siteId),
      vodId: Value(vodId),
      vodName: Value(vodName),
      vodPic: Value(vodPic),
      vodRemarks: Value(vodRemarks ?? existing?.vodRemarks),
      folder: Value(folder),
      createdAt: Value(existing?.createdAt ?? DateTime.now().toUtc()),
    );

    await db
        .into(db.favorites)
        .insert(
          companion,
          onConflict: DoUpdate(
            (old) => companion,
            target: [db.favorites.siteId, db.favorites.vodId],
          ),
        );

    return (await byVod(siteId, vodId))!;
  }

  /// 取消收藏；返回是否真的删掉了（原先存在）。
  Future<bool> remove(int siteId, String vodId) async {
    final existed = await isFavorite(siteId, vodId);
    await deleteVod(siteId, vodId);
    return existed;
  }

  /// 更新「最近检查到的更新状态」，用于「有更新」标记。
  Future<void> markChecked(
    int siteId,
    String vodId, {
    required String latestRemarks,
    DateTime? checkedAt,
  }) async {
    await (db.update(
      db.favorites,
    )..where((t) => t.siteId.equals(siteId) & t.vodId.equals(vodId))).write(
      FavoritesCompanion(
        latestRemarks: Value(latestRemarks),
        lastCheckAt: Value(checkedAt ?? DateTime.now().toUtc()),
      ),
    );
  }

  /// 删除一条收藏（按 `(siteId, vodId)`）。
  Future<void> deleteVod(int siteId, String vodId) async {
    await (db.delete(
      db.favorites,
    )..where((t) => t.siteId.equals(siteId) & t.vodId.equals(vodId))).go();
  }

  /// 清空全部收藏。
  Future<int> clear() => db.delete(db.favorites).go();
}
