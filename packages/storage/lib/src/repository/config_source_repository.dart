import 'package:drift/drift.dart';

import 'package:storage/src/database/database.dart';

/// `config_source` 表：配置订阅仓储。
///
/// 语义见 `docs/07-数据库设计.md` §3.1：用户导入的 TVBox 配置订阅，URL 为 NULL
/// 表示本地文件导入。
class ConfigSourceRepository {
  /// 持有底层数据库连接。
  ConfigSourceRepository(this.db);

  /// 底层数据库连接。
  final AppDatabase db;

  /// 全部配置源（按 sortOrder 升序）。
  Future<List<ConfigSource>> all() async {
    final query = db.select(db.configSources)
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.get();
  }

  /// 按 id 取配置源；不存在返回 null。
  Future<ConfigSource?> byId(int id) async {
    return (db.select(
      db.configSources,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 插入一个配置源，返回自增 id。
  Future<int> add(ConfigSourcesCompanion companion) {
    return db.into(db.configSources).insert(companion);
  }

  /// 更新配置源（覆盖全部字段）。
  Future<void> update(ConfigSourcesCompanion companion) async {
    await db.into(db.configSources).insertOnConflictUpdate(companion);
  }

  /// 记录一次同步结果。
  Future<void> markSynced(
    int id, {
    required String rawHash,
    DateTime? syncedAt,
    String? lastError,
  }) async {
    await (db.update(db.configSources)..where((t) => t.id.equals(id))).write(
      ConfigSourcesCompanion(
        rawHash: Value(rawHash),
        lastSyncAt: Value(syncedAt ?? DateTime.now().toUtc()),
        lastError: Value(lastError),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// 删除配置源（级联删除其站点）。
  Future<int> delete(int id) async {
    return (db.delete(db.configSources)..where((t) => t.id.equals(id))).go();
  }

  /// 清空全部配置源。
  Future<int> clear() => db.delete(db.configSources).go();
}
