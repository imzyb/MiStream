import 'package:drift/drift.dart';

import 'package:storage/src/database/database.dart';

/// `site` 表：站点仓储。
///
/// 语义见 `docs/07-数据库设计.md` §3.2：站点来自配置源或插件（`config_id` 与
/// `plugin_id` 恰有一个非空）；运行时状态列（`status`/`fail_count` 等）可重建。
class SiteRepository {
  /// 持有底层数据库连接。
  SiteRepository(this.db);

  /// 底层数据库连接。
  final AppDatabase db;

  /// 全部启用站点（按优先级降序）。
  Future<List<Site>> enabled({bool searchable = true}) async {
    final query = db.select(db.sites)
      ..where(
        (t) =>
            t.enabled.equals(true) &
            (searchable ? t.searchable.equals(true) : const Constant(true)),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.priority)]);
    return query.get();
  }

  /// 某配置源下的站点。
  Future<List<Site>> byConfig(int configId) async {
    final query = db.select(db.sites)
      ..where((t) => t.configId.equals(configId))
      ..orderBy([(t) => OrderingTerm.desc(t.priority)]);
    return query.get();
  }

  /// 某插件提供的站点。
  Future<List<Site>> byPlugin(String pluginId) async {
    final query = db.select(db.sites)
      ..where((t) => t.pluginId.equals(pluginId))
      ..orderBy([(t) => OrderingTerm.desc(t.priority)]);
    return query.get();
  }

  /// 按 id 取站点；不存在返回 null。
  Future<Site?> byId(int id) async {
    return (db.select(
      db.sites,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 插入/更新站点。返回最终落库行。
  ///
  /// 带 `id` 走覆盖更新；不带则插入并回读自增 id。
  Future<Site> upsert(SitesCompanion companion) async {
    if (companion.id.present) {
      await db.into(db.sites).insertOnConflictUpdate(companion);
      return (await byId(companion.id.value))!;
    }
    final id = await db.into(db.sites).insert(companion);
    return (await byId(id))!;
  }

  /// 更新运行时状态（可重建数据，不影响业务字段）。
  Future<void> updateStatus(
    int siteId, {
    required String status,
    int? failCount,
    DateTime? lastOkAt,
    String? lastError,
    int? lastLatencyMs,
  }) async {
    final companion = SitesCompanion(
      status: Value(status),
      failCount: Value(failCount ?? 0),
      lastOkAt: Value(lastOkAt),
      lastError: Value(lastError),
      lastLatencyMs: Value(lastLatencyMs),
    );
    await (db.update(db.sites)..where((t) => t.id.equals(siteId))).write(
      companion,
    );
  }

  /// 删除某配置源下的全部站点。
  Future<int> deleteByConfig(int configId) async {
    return (db.delete(
      db.sites,
    )..where((t) => t.configId.equals(configId))).go();
  }

  /// 清空全部站点。
  Future<int> clear() => db.delete(db.sites).go();
}
