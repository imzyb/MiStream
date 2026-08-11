import 'package:drift/drift.dart';

import 'package:storage/src/database/database.dart';

/// `plugin_storage` 表：按源隔离的 KV 存储，带配额检查。
///
/// 语义见 `docs/07-数据库设计.md` §3.7：`owner` 为 `plugin_id` 或
/// `site:<site_id>`，`value` 为任意字符串，`bytes` 用于配额统计。
class PluginStorageDao {
  /// 持有底层数据库连接。
  PluginStorageDao(this.db);

  /// 底层数据库连接。
  final AppDatabase db;

  /// 读取一项存储。
  Future<String?> get(String owner, String key) async {
    final row =
        await (db.select(db.pluginStorages)
              ..where((t) => t.owner.equals(owner) & t.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }

  /// 写入一项存储（覆盖），返回该 key 占用的字节数。
  Future<int> set(String owner, String key, String value) async {
    final bytes = value.length;
    await db
        .into(db.pluginStorages)
        .insertOnConflictUpdate(
          PluginStoragesCompanion(
            owner: Value(owner),
            key: Value(key),
            value: Value(value),
            bytes: Value(bytes),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    return bytes;
  }

  /// 删除一项存储。
  Future<void> delete(String owner, String key) async {
    await (db.delete(
      db.pluginStorages,
    )..where((t) => t.owner.equals(owner) & t.key.equals(key))).go();
  }

  /// 查询某 owner 的存储总字节数（配额检查用）。
  Future<int> totalBytes(String owner) async {
    final row = await db
        .customSelect(
          'SELECT COALESCE(SUM(bytes), 0) AS total '
          'FROM plugin_storage WHERE owner = ?',
          variables: [Variable.withString(owner)],
        )
        .getSingle();
    return (row.data['total'] as num).toInt();
  }

  /// 删除某 owner 的全部存储（清理用）。
  Future<int> clearOwner(String owner) async {
    return (db.delete(
      db.pluginStorages,
    )..where((t) => t.owner.equals(owner))).go();
  }
}
