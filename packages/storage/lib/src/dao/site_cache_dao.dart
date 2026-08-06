import 'package:drift/drift.dart';

import 'package:storage/src/database/database.dart';

/// 缓存总量默认上限（字节）。见 `docs/07 §3.10`。
const int kSiteCacheMaxBytesDefault = 200 * 1024 * 1024;

/// 缓存总量降到上限的 80% 即停（LRU 水线）。
const double _kWaterlineRatio = 0.8;

/// `site_cache` 表：源数据响应缓存。
///
/// 语义见 `docs/07-数据库设计.md` §3.10：
/// - 启动与每小时清除过期项（`expires_at` 已过）
/// - 总量超上限时按 `created_at` 升序 LRU 淘汰，删到 80% 水线
class SiteCacheDao {
  /// 持有底层数据库连接。
  SiteCacheDao(this.db);

  /// 底层数据库连接。
  final AppDatabase db;

  /// 读出未过期的缓存项；过期或缺失返回 null（过期时顺手删除）。
  Future<SiteCache?> get(String cacheKey, {required DateTime now}) async {
    final row = await (db.select(
      db.siteCaches,
    )..where((t) => t.cacheKey.equals(cacheKey))).getSingleOrNull();
    if (row == null) return null;
    if (row.expiresAt.isAfter(now)) {
      return row;
    }
    await _remove(cacheKey);
    return null;
  }

  /// 写入（覆盖）一条缓存。
  Future<void> put(SiteCachesCompanion entry) async {
    await db.into(db.siteCaches).insertOnConflictUpdate(entry);
  }

  /// 删除所有过期项，返回删除条数。启动或定时任务调用。
  Future<int> purgeExpired({required DateTime now}) async {
    final query = db.delete(db.siteCaches)
      ..where(
        (t) => t.expiresAt.isSmallerThanValue(now.millisecondsSinceEpoch),
      );
    return query.go();
  }

  /// 若缓存总量超过 [maxBytes]（缺省用 [kSiteCacheMaxBytesDefault]），
  /// 按最旧 `created_at`（LRU）删到 80% 水线，返回已删除条数。
  Future<int> trimTo({int maxBytes = kSiteCacheMaxBytesDefault}) async {
    final total = await _totalBytes();
    if (total <= maxBytes) return 0;

    final waterline = (maxBytes * _kWaterlineRatio).round();
    final over = total - waterline;
    if (over <= 0) return 0;

    final oldestFirst = await (db.select(
      db.siteCaches,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

    var bytesFreed = 0;
    var deleted = 0;
    for (final row in oldestFirst) {
      if (bytesFreed >= over) break;
      bytesFreed += row.bytes;
      await _remove(row.cacheKey);
      deleted++;
    }
    return deleted;
  }

  Future<int> _totalBytes() async {
    final row = await db
        .customSelect(
          'SELECT COALESCE(SUM(bytes), 0) AS total FROM site_cache',
        )
        .getSingle();
    return (row.data['total'] as num).toInt();
  }

  Future<void> _remove(String cacheKey) async {
    await (db.delete(
      db.siteCaches,
    )..where((t) => t.cacheKey.equals(cacheKey))).go();
  }
}
