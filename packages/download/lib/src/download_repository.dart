import 'package:download/src/download_task.dart';

/// 下载任务与分片进度的持久化接口。
///
/// 为什么要它：`download` / `download_segment` 两张表**早就在 schema 里**
/// （`docs/07-数据库设计.md` §3.5），但此前零使用 —— 任务只活在
/// `DownloadManager` 的内存 `Map` 里。于是「强制杀进程后重启，任务状态正确
/// 恢复」这条出口标准**不可能**成立，而「断点续传（`download_segment` 表）」
/// 这条交付物也只是一张空表。
abstract class DownloadRepository {
  /// 插入一个新任务，返回数据库分配的 id（忽略 [task] 自带的 id）。
  Future<int> insertTask(DownloadTask task);

  /// 按 id 覆盖写入（不存在则插入）。状态变化与周期性进度都走它。
  Future<void> upsertTask(DownloadTask task);

  /// 全部任务，按创建时间升序（与 UI 的「等待中」列表顺序一致）。
  Future<List<DownloadTask>> listTasks();

  /// 删除任务（`download_segment` 由外键级联删除）。
  Future<void> deleteTask(int id);

  /// 清掉全部已完成任务。
  Future<void> clearCompleted();

  /// 标记某个分片已下载完成。
  ///
  /// 复合主键 `(taskId, seq)`，重复标记是幂等的（断点续传要反复扫同一批分片）。
  Future<void> markSegmentDone({
    required int taskId,
    required int seq,
    required String url,
    required int bytes,
  });

  /// 某任务已完成的分片序号集合。
  Future<Set<int>> doneSegmentSeqs(int taskId);

  /// 清掉某任务的全部分片记录（取消 / 重新开始时用）。
  Future<void> clearSegments(int taskId);
}

/// 内存实现：测试用，也给「没有数据库」的场景兜底。
class InMemoryDownloadRepository implements DownloadRepository {
  /// 构造。
  InMemoryDownloadRepository();

  final Map<int, DownloadTask> _tasks = {};
  final Map<int, Map<int, ({String url, int bytes})>> _segments = {};
  int _seq = 0;

  @override
  Future<int> insertTask(DownloadTask task) async {
    final id = ++_seq;
    _tasks[id] = task.copyWith(id: id);
    return id;
  }

  @override
  Future<void> upsertTask(DownloadTask task) async {
    _tasks[task.id] = task;
    if (task.id > _seq) _seq = task.id;
  }

  @override
  Future<List<DownloadTask>> listTasks() async {
    final rows = _tasks.values.toList()
      ..sort((a, b) {
        final byCreated = a.createdAt.compareTo(b.createdAt);
        return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
      });
    return rows;
  }

  @override
  Future<void> deleteTask(int id) async {
    _tasks.remove(id);
    _segments.remove(id);
  }

  @override
  Future<void> clearCompleted() async {
    final done = _tasks.values
        .where((t) => t.status == DownloadStatus.completed)
        .map((t) => t.id)
        .toList();
    for (final id in done) {
      _tasks.remove(id);
      _segments.remove(id);
    }
  }

  @override
  Future<void> markSegmentDone({
    required int taskId,
    required int seq,
    required String url,
    required int bytes,
  }) async {
    // 存 url 与 bytes 而不是只记个序号：与 drift 那份保持同一份数据，
    // 否则「内存实现下用例全绿、真库上少字段」这类偏差没人发现。
    _segments.putIfAbsent(taskId, () => {})[seq] = (url: url, bytes: bytes);
  }

  @override
  Future<Set<int>> doneSegmentSeqs(int taskId) async =>
      Set<int>.unmodifiable(_segments[taskId]?.keys ?? const <int>[]);

  @override
  Future<void> clearSegments(int taskId) async {
    _segments.remove(taskId);
  }
}
