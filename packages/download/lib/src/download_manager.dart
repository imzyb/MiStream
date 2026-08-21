import 'dart:async';

import 'package:download/src/download_progress.dart';
import 'package:download/src/download_task.dart';

/// 下载管理器：管理多个下载任务。
class DownloadManager {
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, StreamController<DownloadProgress>> _progressControllers =
      {};
  final List<void Function(DownloadTask)> _taskListeners = [];

  /// 获取所有任务。
  List<DownloadTask> get tasks => List.unmodifiable(_tasks.values);

  /// 获取进行中的任务。
  List<DownloadTask> get activeTasks => _tasks.values
      .where((t) => t.status == DownloadStatus.downloading)
      .toList();

  /// 获取已完成的任务。
  List<DownloadTask> get completedTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.completed).toList();

  /// 添加任务状态监听器。
  void addTaskListener(void Function(DownloadTask) listener) {
    _taskListeners.add(listener);
  }

  /// 移除任务状态监听器。
  void removeTaskListener(void Function(DownloadTask) listener) {
    _taskListeners.remove(listener);
  }

  /// 创建下载任务。
  Future<DownloadTask> createTask({
    required String title,
    required String url,
    required String savePath,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final task = DownloadTask(
      id: _generateId(),
      title: title,
      url: url,
      savePath: savePath,
      createdAt: now,
      updatedAt: now,
    );

    _tasks[task.id] = task;
    _notifyTaskChange(task);
    return task;
  }

  /// 开始下载。
  Future<void> startDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) throw StateError('Task not found: $taskId');
    if (task.status == DownloadStatus.downloading) return;

    _updateTask(task.copyWith(status: DownloadStatus.downloading));

    // 创建进度流
    _progressControllers[taskId] =
        StreamController<DownloadProgress>.broadcast();

    // TODO: 实际实现需要调用HLS下载器或HTTP下载器
    // 这里仅做状态演示
    await Future<void>.delayed(const Duration(seconds: 1));
    _updateTask(task.copyWith(status: DownloadStatus.completed, progress: 1));
  }

  /// 暂停下载。
  Future<void> pauseDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) throw StateError('Task not found: $taskId');
    if (task.status != DownloadStatus.downloading) return;

    _updateTask(task.copyWith(status: DownloadStatus.paused));
  }

  /// 恢复下载。
  Future<void> resumeDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) throw StateError('Task not found: $taskId');
    if (task.status != DownloadStatus.paused) return;

    await startDownload(taskId);
  }

  /// 取消下载。
  Future<void> cancelDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) throw StateError('Task not found: $taskId');

    _updateTask(task.copyWith(status: DownloadStatus.cancelled));
    _progressControllers[taskId]?.close();
    _progressControllers.remove(taskId);
  }

  /// 删除任务。
  Future<void> deleteTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.status == DownloadStatus.downloading) {
      await cancelDownload(taskId);
    }

    _tasks.remove(taskId);
    _notifyTaskChange(task);
  }

  /// 获取任务进度流。
  Stream<DownloadProgress>? getProgressStream(String taskId) {
    return _progressControllers[taskId]?.stream;
  }

  /// 清除已完成的任务。
  Future<void> clearCompleted() async {
    final completed = completedTasks;
    for (final task in completed) {
      _tasks.remove(task.id);
    }
  }

  /// 导出任务列表。
  List<Map<String, dynamic>> exportTasks() {
    return _tasks.values.map((t) => t.toJson()).toList();
  }

  /// 导入任务列表。
  void importTasks(List<Map<String, dynamic>> json) {
    for (final item in json) {
      final task = DownloadTask.fromJson(item);
      _tasks[task.id] = task;
    }
  }

  void _updateTask(DownloadTask task) {
    _tasks[task.id] = task;
    _notifyTaskChange(task);

    // 发送进度更新
    final controller = _progressControllers[task.id];
    if (controller != null && !controller.isClosed) {
      controller.add(
        DownloadProgress(
          taskId: task.id,
          status: _mapStatus(task.status),
          progress: task.progress,
          downloadedBytes: task.downloadedBytes,
          totalBytes: task.totalBytes,
          downloadedSegments: task.downloadedSegments,
          totalSegments: task.totalSegments,
        ),
      );
    }
  }

  DownloadProgressStatus _mapStatus(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return DownloadProgressStatus.downloading;
      case DownloadStatus.completed:
        return DownloadProgressStatus.completed;
      case DownloadStatus.failed:
        return DownloadProgressStatus.failed;
      default:
        return DownloadProgressStatus.downloading;
    }
  }

  void _notifyTaskChange(DownloadTask task) {
    for (final listener in _taskListeners) {
      listener(task);
    }
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  }

  /// 释放资源。
  void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _taskListeners.clear();
  }
}
