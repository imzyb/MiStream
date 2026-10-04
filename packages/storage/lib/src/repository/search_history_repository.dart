import 'package:drift/drift.dart';

import 'package:storage/src/database/database.dart';

/// `search_history` 表：搜索历史仓储。
///
/// 语义见 `docs/07-数据库设计.md` §3.12：`keyword` 主键，`hit_count` 记录命中次数，
/// `last_at` 最近搜索时间。
class SearchHistoryRepository {
  /// 持有底层数据库连接。
  SearchHistoryRepository(this.db);

  /// 底层数据库连接。
  final AppDatabase db;

  /// 最近搜索过的关键词（按最近时间倒序，取 [limit] 条）。
  Future<List<SearchHistory>> recent({int limit = 10}) async {
    final query = db.select(db.searchHistories)
      ..orderBy([(t) => OrderingTerm.desc(t.lastAt)])
      ..limit(limit);
    return query.get();
  }

  /// 记录一次搜索：已存在则命中 +1 且更新 [at]；否则插入。
  ///
  /// [source] 记录这次搜索来自哪里（`local`/`plugin`/...），默认 `local`。
  Future<void> record(String keyword, {DateTime? at, String? source}) async {
    final now = at ?? DateTime.now().toUtc();
    final src = source ?? 'local';
    await db.customInsert(
      'INSERT INTO search_history (keyword, hit_count, last_at, source) '
      'VALUES (?, 1, ?, ?) '
      'ON CONFLICT(keyword) DO UPDATE SET hit_count = hit_count + 1, '
      'last_at = excluded.last_at, source = excluded.source',
      variables: [
        Variable.withString(keyword),
        Variable.withInt(now.millisecondsSinceEpoch),
        Variable.withString(src),
      ],
    );
  }

  /// 删除单个关键词。
  Future<void> remove(String keyword) async {
    await (db.delete(
      db.searchHistories,
    )..where((t) => t.keyword.equals(keyword))).go();
  }

  /// 清空全部搜索历史。
  Future<int> clear() => db.delete(db.searchHistories).go();
}
