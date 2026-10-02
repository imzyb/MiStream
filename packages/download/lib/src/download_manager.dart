import 'dart:async';
import 'dart:io';

import 'package:download/src/download_cancel.dart';
import 'package:download/src/download_progress.dart';
import 'package:download/src/download_repository.dart';
import 'package:download/src/download_task.dart';
import 'package:download/src/download_task_runner.dart';
import 'package:path/path.dart' as p;

/// 下载管理器：排队、限流、状态落库。
///
/// 三件事分开看：
/// 1. **任务状态**以 [DownloadRepository] 为准。内存里的 `_tasks` 只是缓存，
///    每一次状态变化都落库 —— 否则「强制杀进程后重启，状态正确恢复」不可能
///    成立（旧实现就只活在内存 `Map` 里，两张表建了却零使用）。
/// 2. **排队**按优先级降序、同级按创建时间升序，同时最多 [maxConcurrent] 个。
///    旧实现是「谁先调 `startDownload` 谁先跑，且调用方要 `await` 到底」，
///    既没有并发上限，也让 UI 无法在下载期间做别的事。
/// 3. **执行**交给 [DownloadTaskRunner]，默认实现才碰网络。
class DownloadManager {
  /// 构造。
  DownloadManager({
    DownloadRepository? repository,
    DownloadTaskRunner? runner,
    this.maxConcurrent = 3,
    this.downloadRoot,
    this.progressPersistInterval = const Duration(seconds: 1),
    this.onPersistError,
  }) : _repository = repository ?? InMemoryDownloadRepository(),
       _runner = runner ?? DefaultDownloadTaskRunner();

  final DownloadRepository _repository;
  final DownloadTaskRunner _runner;

  /// 同时下载的任务数上限。
  final int maxConcurrent;

  /// 下载根目录。
  ///
  /// 有值时，删除任务只会删这个目录**之内**的文件。旧实现在
  /// `cancelDownload` 里对 `task.savePath` 直接 `Directory(...).delete(
  /// recursive: true)`，而调用方传的是硬编码的 `/downloads/<标题>` ——
  /// Windows 上会解析成「当前盘根目录下的 downloads」，越出应用的目录之外。
  final String? downloadRoot;

  /// 进度落库的最小间隔。
  ///
  /// 进度回调一秒可能触发几十次，每次都写库既浪费又和播放抢 IO（M8 有一条
  /// 出口标准是「下载不影响播放」）。**内存里的进度与通知不节流**（UI 要顺滑），
  /// 只有落库节流；状态变化一律立即落库，否则杀进程会丢状态。
  /// 传 [Duration.zero] 表示不节流。
  final Duration progressPersistInterval;

  /// 落库失败时的回调。
  ///
  /// 不静默吞：写库失败本身不该让下载崩掉（下一次状态变化会整行重写），但也
  /// 不能当作没发生 —— 没有这个口子，「杀进程后状态没恢复」会变成一个查不到
  /// 原因的怪现象。
  final void Function(Object error)? onPersistError;

  final Map<int, DownloadTask> _tasks = {};
  final Map<int, StreamController<DownloadProgress>> _progressControllers = {};
  final Map<int, CancelToken> _cancelTokens = {};
  final Set<int> _running = {};
  final Map<int, DateTime> _lastProgressPersist = {};
  final List<void Function(DownloadTask)> _taskListeners = [];
  final List<void Function()> _listeners = [];
  bool _disposed = false;

  /// 全部任务，按创建时间升序（与 `DownloadRepository.listTasks` 同序）。
  List<DownloadTask> get tasks => List.unmodifiable(_byCreated());

  /// 进行中的任务。
  List<DownloadTask> get activeTasks => _filtered(DownloadStatus.downloading);

  /// 等待中的任务，**按实际调度顺序**：优先级高的在前，同级按创建时间。
  ///
  /// 与 [tasks] 的顺序刻意不同：`tasks` 是「列表顺序」，这个才是「下一个轮到
  /// 谁」。UI 的「等待中」页签要的是后者。
  List<DownloadTask> get pendingTasks => _queued();

  /// 已完成的任务。
  List<DownloadTask> get completedTasks => _filtered(DownloadStatus.completed);

  /// 已暂停的任务。
  List<DownloadTask> get pausedTasks => _filtered(DownloadStatus.paused);

  /// 失败的任务。
  List<DownloadTask> get failedTasks => _filtered(DownloadStatus.failed);

  /// 已取消的任务。
  List<DownloadTask> get cancelledTasks => _filtered(DownloadStatus.cancelled);

  /// 正在跑的任务数。
  int get runningCount => _running.length;

  /// 按 id 取任务。
  DownloadTask? taskById(int id) => _tasks[id];

  /// 监听「整表变了」（增删任务、批量恢复）。UI 用这个重绘列表。
  void addListener(void Function() listener) => _listeners.add(listener);

  /// 取消 [addListener] 注册的监听。
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// 监听单个任务的状态变化（用来弹「下载完成」这类提示）。
  void addTaskListener(void Function(DownloadTask) listener) =>
      _taskListeners.add(listener);

  /// 取消 [addTaskListener] 注册的监听。
  void removeTaskListener(void Function(DownloadTask) listener) =>
      _taskListeners.remove(listener);

  /// 从仓储恢复任务列表。
  ///
  /// `downloading` 是上一次进程还活着时的残留：崩溃或强杀之后，库里那些
  /// 「下载中」没有一个是真在下载。恢复时统一降级为 `paused`，理由有两条：
  /// - 降成 `pending` 会被队列立刻重跑，用户看到的是「一启动就开始下东西」；
  /// - 降成 `paused` 才是「进度还在，要不要接着下由你决定」，且 `paused` 是
  ///   可恢复状态（[DownloadTask.isResumable]），点「继续」能真正续上。
  ///
  /// **恢复不触发调度**：这一步只负责把状态读回来。
  Future<void> restore() async {
    final rows = await _repository.listTasks();
    _tasks.clear();
    for (final row in rows) {
      final restored = row.status == DownloadStatus.downloading
          ? row.copyWith(status: DownloadStatus.paused)
          : row;
      _tasks[restored.id] = restored;
      if (restored.status != row.status) {
        await _persist(restored);
      }
    }
    _notify();
  }

  /// 新建任务并落库，返回带数据库 id 的任务。
  ///
  /// **不自动开始**：「建任务」与「开始下载」是两个动作，调度只有一个入口
  /// （[startDownload] / [resumeDownload]），否则「等待中」这个状态会同时
  /// 表示「排队等跑」和「建了没启动」两件事，没法区分。
  ///
  /// [siteId] / [vodId] / [episodeName] 是「这部片的这一集」的身份，从影片页
  /// 发起下载时才有值（见 `download` 表的同名列）。它们不参与调度，只用来让
  /// 下载列表能显示「第几集」并支持去重。
  Future<DownloadTask> createTask({
    required String title,
    required String url,
    required String savePath,
    Map<String, String> headers = const {},
    int priority = 0,
    int? siteId,
    String? vodId,
    String? episodeName,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final draft = DownloadTask(
      id: 0,
      title: title,
      url: url,
      savePath: savePath,
      createdAt: now,
      updatedAt: now,
      headers: headers,
      priority: priority,
      siteId: siteId,
      vodId: vodId,
      episodeName: episodeName,
    );
    final id = await _repository.insertTask(draft);
    final task = draft.copyWith(id: id);
    _tasks[id] = task;
    _notifyTaskChange(task);
    _notify();
    return task;
  }

  /// 开始（或重试）一个任务：置为等待中并触发调度。
  ///
  /// ⚠️ 它**不保证这个任务立刻开始**。调度器是从全部等待中的任务里挑优先级
  /// 最高（同级挑最早创建）的一个，所以「点开始」的实际语义是「让这个任务进入
  /// 待跑集合」。当前 UI 不设优先级（一律 0），退化成先进先出，与用户直觉一致；
  /// 一旦引入「高优先级」开关，这条语义就是它的落点 —— 与其把调度器改成
  /// 「插队」，不如让调用方给优先级，规则只有一套。
  Future<void> startDownload(int taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (task.status == DownloadStatus.downloading) return;
    _updateTask(
      task.copyWith(status: DownloadStatus.pending, clearError: true),
    );
    _pump();
  }

  /// 暂停下载。
  Future<void> pauseDownload(int taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (task.status != DownloadStatus.downloading) return;
    _cancelTokens[taskId]?.cancel();
    _updateTask(task.copyWith(status: DownloadStatus.paused));
  }

  /// 恢复下载。
  Future<void> resumeDownload(int taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (task.status != DownloadStatus.paused &&
        task.status != DownloadStatus.failed) {
      return;
    }
    await startDownload(taskId);
  }

  /// 取消下载：清掉半成品与分片记录。
  Future<void> cancelDownload(int taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    _cancelTokens[taskId]?.cancel();
    _cancelTokens.remove(taskId);
    await _deleteArtifacts(task.savePath);
    await _repository.clearSegments(taskId);
    _updateTask(
      task.copyWith(
        status: DownloadStatus.cancelled,
        progress: 0,
        downloadedBytes: 0,
        downloadedSegments: 0,
      ),
    );
    await _progressControllers.remove(taskId)?.close();
  }

  /// 删除任务（连同已下载的文件与分片记录）。
  Future<void> deleteTask(int taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    _cancelTokens[taskId]?.cancel();
    _cancelTokens.remove(taskId);
    await _deleteArtifacts(task.savePath);
    await _repository.deleteTask(taskId);
    await _progressControllers.remove(taskId)?.close();
    _tasks.remove(taskId);
    _lastProgressPersist.remove(taskId);
    _notifyTaskChange(task);
    _notify();
  }

  /// 清除全部已完成任务。
  Future<void> clearCompleted() async {
    final completed = completedTasks;
    await _repository.clearCompleted();
    for (final task in completed) {
      await _progressControllers.remove(task.id)?.close();
      _tasks.remove(task.id);
      _lastProgressPersist.remove(task.id);
    }
    _notify();
  }

  /// 获取任务进度流。
  Stream<DownloadProgress>? getProgressStream(int taskId) =>
      _progressControllers[taskId]?.stream;

  /// 释放资源。
  void dispose() {
    _disposed = true;
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _cancelTokens.clear();
    for (final controller in _progressControllers.values) {
      unawaited(controller.close());
    }
    _progressControllers.clear();
    _taskListeners.clear();
    _listeners.clear();
    _runner.dispose();
  }

  // ── 调度 ────────────────────────────────────────────────────────────────

  /// 在并发上限内把等待中的任务发出去。
  void _pump() {
    if (_disposed) return;
    while (_running.length < maxConcurrent) {
      final next = _nextToRun();
      if (next == null) return;
      _running.add(next.id);
      // 状态在这里**同步**改成 downloading：如果等 `_run` 里的第一个 await
      // 之后才改，循环下一轮会再选中同一个任务，一个任务被发两次。
      _updateTask(
        next.copyWith(status: DownloadStatus.downloading, clearError: true),
      );
      unawaited(_run(next.id));
    }
  }

  DownloadTask? _nextToRun() {
    for (final task in _queued()) {
      if (!_running.contains(task.id)) return task;
    }
    return null;
  }

  Future<void> _run(int taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
      _running.remove(taskId);
      return;
    }

    final token = CancelToken();
    _cancelTokens[taskId] = token;
    // 分片落库的 Future 攒起来，在 finally 里逐个 await：写要在分片下完时
    // 就**立刻**发出（进程被杀才有可续传的记录），但也不能放着不管 ——
    // 未 await 的 Future 抛错会变成没人接的异步异常。
    final segmentWrites = <Future<void>>[];

    try {
      final skip = task.isHls
          ? await _repository.doneSegmentSeqs(taskId)
          : const <int>{};
      if (token.isCancelled) return;

      final result = await _runner.run(
        task,
        cancelToken: token,
        skipSegments: skip,
        onProgress: (progress) => _applyProgress(taskId, progress),
        onSegmentDone: (seq, url, bytes) => segmentWrites.add(
          _repository.markSegmentDone(
            taskId: taskId,
            seq: seq,
            url: url,
            bytes: bytes,
          ),
        ),
      );

      // 暂停/取消时状态已经由 pause/cancel 写好，这里不要覆盖回去。
      if (token.isCancelled) return;

      final current = _tasks[taskId];
      if (current == null) return;
      if (result.success) {
        _updateTask(
          current.copyWith(
            status: DownloadStatus.completed,
            progress: 1,
            downloadedBytes: result.downloadedBytes,
            totalBytes: result.totalBytes,
            downloadedSegments: result.downloadedSegments,
            totalSegments: result.totalSegments,
            clearError: true,
          ),
        );
      } else {
        _updateTask(
          current.copyWith(
            status: DownloadStatus.failed,
            error: result.error ?? '下载失败',
          ),
        );
      }
    } on Object catch (e) {
      if (!token.isCancelled) {
        final current = _tasks[taskId];
        if (current != null) {
          _updateTask(
            current.copyWith(status: DownloadStatus.failed, error: '$e'),
          );
        }
      }
    } finally {
      for (final write in segmentWrites) {
        try {
          await write;
        } on Object catch (e) {
          onPersistError?.call(e);
        }
      }
      _cancelTokens.remove(taskId);
      _running.remove(taskId);
      _pump();
    }
  }

  void _applyProgress(int taskId, DownloadProgress progress) {
    final current = _tasks[taskId];
    if (current == null) return;
    // 已暂停/已取消的任务还在收尾，别让残余回调把它改回「下载中」。
    if (current.status != DownloadStatus.downloading) return;
    _updateTask(
      current.copyWith(
        progress: progress.progress,
        downloadedBytes: progress.downloadedBytes,
        totalBytes: progress.totalBytes,
        downloadedSegments: progress.downloadedSegments,
        totalSegments: progress.totalSegments,
      ),
    );
  }

  // ── 状态写入 ────────────────────────────────────────────────────────────

  void _updateTask(DownloadTask task) {
    final previous = _tasks[task.id];
    _tasks[task.id] = task;
    _notifyTaskChange(task);

    final statusChanged = previous == null || previous.status != task.status;
    if (statusChanged || _progressDue(task.id)) {
      _lastProgressPersist[task.id] = DateTime.now();
      unawaited(_persist(task));
    }
  }

  bool _progressDue(int taskId) {
    if (progressPersistInterval == Duration.zero) return true;
    final last = _lastProgressPersist[taskId];
    if (last == null) return true;
    return DateTime.now().difference(last) >= progressPersistInterval;
  }

  Future<void> _persist(DownloadTask task) async {
    try {
      await _repository.upsertTask(task);
    } on Object catch (e) {
      onPersistError?.call(e);
    }
  }

  void _notifyTaskChange(DownloadTask task) {
    for (final listener in List.of(_taskListeners)) {
      listener(task);
    }
    _notify();
  }

  void _notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  // ── 查询 ────────────────────────────────────────────────────────────────

  List<DownloadTask> _byCreated() {
    final rows = _tasks.values.toList()
      ..sort((a, b) {
        final byCreated = a.createdAt.compareTo(b.createdAt);
        return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
      });
    return rows;
  }

  List<DownloadTask> _filtered(DownloadStatus status) => [
    for (final task in _byCreated())
      if (task.status == status) task,
  ];

  List<DownloadTask> _queued() {
    final rows = _filtered(DownloadStatus.pending)
      ..sort((a, b) {
        final byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) return byPriority;
        final byCreated = a.createdAt.compareTo(b.createdAt);
        return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
      });
    return rows;
  }

  // ── 文件清理 ────────────────────────────────────────────────────────────

  Future<void> _deleteArtifacts(String savePath) async {
    if (savePath.isEmpty) return;
    if (!_isInsideDownloadRoot(savePath)) {
      onPersistError?.call(
        StateError('拒绝删除下载根目录之外的内容: $savePath'),
      );
      return;
    }
    try {
      final dir = Directory(savePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return;
      }
      final file = File(savePath);
      if (await file.exists()) await file.delete();
      // HLS 的 `.part` 残片跟在分片目录里，随目录一起删掉了；直链的
      // `<savePath>.part` 是同级文件，要单独清。
      final part = File('$savePath.part');
      if (await part.exists()) await part.delete();
    } on Object {
      // 清理失败不该让「删除任务」失败：记录已经删了，剩下的是磁盘垃圾。
    }
  }

  bool _isInsideDownloadRoot(String path) {
    final root = downloadRoot;
    if (root == null || root.isEmpty) return true;
    final target = p.normalize(p.absolute(path));
    final normalizedRoot = p.normalize(p.absolute(root));
    return target == normalizedRoot || p.isWithin(normalizedRoot, target);
  }
}
