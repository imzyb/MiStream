import 'package:drift/drift.dart';
import 'package:download/src/download_repository.dart';
import 'package:download/src/download_task.dart';
import 'package:storage/storage.dart' as db;

/// 用 drift 落库的下载仓储（`download` / `download_segment` 两张表）。
///
/// 两张表在 schema v3 就存在，这里只是补上第一个消费者。
///
/// ⚠️ **秒 ↔ 毫秒**：`DownloadTask.createdAt/updatedAt` 是 Unix **秒**，而
/// `download.created_at/updated_at` 列走 `utcMillis` 转换器（存毫秒）。
/// 单位搞错不会报错，只会让「按创建时间排序」的结果看起来是随机的 ——
/// 所以两个方向的换算都收在这一处。
class DriftDownloadRepository implements DownloadRepository {
  /// 以数据库构造。
  DriftDownloadRepository(this._db);

  /// 底层数据库连接。
  ///
  /// 字段名不叫 `db`：`package:storage/storage.dart` 就是以 `db` 为前缀导入的，
  /// 同名会让 `db.` 前缀在类内被遮蔽（analyzer 直接报
  /// `prefix_shadowed_by_local_declaration`）。
  final db.AppDatabase _db;

  @override
  Future<int> insertTask(DownloadTask task) async {
    return _db
        .into(_db.downloads)
        .insert(_toCompanion(task, id: const Value.absent()));
  }

  @override
  Future<void> upsertTask(DownloadTask task) async {
    await _db
        .into(_db.downloads)
        .insertOnConflictUpdate(_toCompanion(task, id: Value(task.id)));
  }

  @override
  Future<List<DownloadTask>> listTasks() async {
    final query = _db.select(_db.downloads)
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return [for (final row in await query.get()) _toTask(row)];
  }

  @override
  Future<void> deleteTask(int id) async {
    await (_db.delete(_db.downloads)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> clearCompleted() async {
    await (_db.delete(
      _db.downloads,
    )..where((t) => t.status.equals(DownloadStatus.completed.name))).go();
  }

  @override
  Future<void> markSegmentDone({
    required int taskId,
    required int seq,
    required String url,
    required int bytes,
  }) async {
    await _db
        .into(_db.downloadSegments)
        .insertOnConflictUpdate(
          db.DownloadSegmentsCompanion(
            downloadId: Value(taskId),
            seq: Value(seq),
            url: Value(url),
            bytes: Value(bytes),
            done: const Value(true),
          ),
        );
  }

  @override
  Future<Set<int>> doneSegmentSeqs(int taskId) async {
    final query = _db.select(_db.downloadSegments)
      ..where((t) => t.downloadId.equals(taskId) & t.done.equals(true));
    return {for (final row in await query.get()) row.seq};
  }

  @override
  Future<void> clearSegments(int taskId) async {
    await (_db.delete(
      _db.downloadSegments,
    )..where((t) => t.downloadId.equals(taskId))).go();
  }

  /// 任务 → 行。
  ///
  /// `totalBytes` 列是 `NOT NULL DEFAULT 0`，而模型用 `-1` 表示「未知」；
  /// `totalSegments` 列可空，`-1` 同样表示未知。两个「未知」的落库形态不同，
  /// 是这张表的既有设计，照着转即可。
  db.DownloadsCompanion _toCompanion(
    DownloadTask task, {
    required Value<int> id,
  }) {
    return db.DownloadsCompanion(
      id: id,
      vodName: Value(task.title),
      sourceUrl: Value(task.url),
      headersJson: Value(encodeHeaders(task.headers)),
      filePath: Value(task.savePath),
      mediaType: Value(task.mediaType),
      totalBytes: Value(task.totalBytes < 0 ? 0 : task.totalBytes),
      doneBytes: Value(task.downloadedBytes),
      totalSegments: Value(task.totalSegments < 0 ? null : task.totalSegments),
      doneSegments: Value(task.downloadedSegments),
      status: Value(task.status.name),
      error: Value(task.error),
      priority: Value(task.priority),
      createdAt: Value(_toDateTime(task.createdAt)),
      updatedAt: Value(_toDateTime(task.updatedAt)),
      completedAt: Value(
        task.status == DownloadStatus.completed
            ? _toDateTime(task.updatedAt)
            : null,
      ),
    );
  }

  DownloadTask _toTask(db.Download row) {
    return DownloadTask(
      id: row.id,
      title: row.vodName,
      url: row.sourceUrl,
      savePath: row.filePath,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == row.status,
        // 认不出的状态当「已暂停」而不是「等待中」：库里的脏值多半来自旧版本，
        // 标成暂停至少让用户能点「继续」，标成等待中会被队列立刻重跑。
        orElse: () => DownloadStatus.paused,
      ),
      progress: row.totalBytes > 0
          ? (row.doneBytes / row.totalBytes).clamp(0.0, 1.0)
          : 0.0,
      downloadedBytes: row.doneBytes,
      totalBytes: row.totalBytes > 0 ? row.totalBytes : -1,
      createdAt: _toSeconds(row.createdAt),
      updatedAt: _toSeconds(row.updatedAt),
      error: row.error,
      downloadedSegments: row.doneSegments ?? 0,
      totalSegments: row.totalSegments ?? -1,
      priority: row.priority,
      headers: decodeHeaders(row.headersJson),
    );
  }

  static DateTime _toDateTime(int unixSeconds) =>
      DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true);

  static int _toSeconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;
}
