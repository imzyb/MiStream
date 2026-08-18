import 'dart:async';

/// Background download service that manages downloads independently of the UI.
///
/// Handles queue management, retry logic, and progress reporting
/// for downloads that should continue even when the app is in the background.
class DownloadService {
  DownloadService({this.maxConcurrent = 3, this.maxRetries = 3});

  /// Maximum concurrent downloads.
  final int maxConcurrent;

  /// Maximum retry attempts per task.
  final int maxRetries;

  final _queue = <DownloadServiceTask>[];
  final _active = <String, DownloadServiceTask>{};
  final _progressController = StreamController<DownloadServiceTask>.broadcast();
  final _completionController =
      StreamController<DownloadServiceTask>.broadcast();

  /// Stream of progress updates for active downloads.
  Stream<DownloadServiceTask> get progress => _progressController.stream;

  /// Stream of completed/failed downloads.
  Stream<DownloadServiceTask> get completions => _completionController.stream;

  /// Number of tasks in the queue.
  int get queueLength => _queue.length;

  /// Number of active downloads.
  int get activeCount => _active.length;

  /// Enqueue a new download task.
  Future<void> enqueue(DownloadServiceTask task) async {
    _queue.add(task);
    _processQueue();
  }

  /// Pause a specific download.
  Future<void> pause(String taskId) async {
    final task = _active.remove(taskId);
    if (task != null) {
      task.status = DownloadServiceStatus.paused;
      _queue.insert(0, task);
    }
  }

  /// Resume a paused download.
  Future<void> resume(String taskId) async {
    final index = _queue.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      _queue[index].status = DownloadServiceStatus.pending;
      _processQueue();
    }
  }

  /// Cancel a download.
  Future<void> cancel(String taskId) async {
    _active.remove(taskId);
    _queue.removeWhere((t) => t.id == taskId);
  }

  /// Cancel all downloads.
  Future<void> cancelAll() async {
    _active.clear();
    _queue.clear();
  }

  void _processQueue() {
    while (_active.length < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.firstWhere(
        (t) => t.status == DownloadServiceStatus.pending,
        orElse: () => _queue.first,
      );
      _queue.remove(task);
      _active[task.id] = task;
      _startDownload(task);
    }
  }

  Future<void> _startDownload(DownloadServiceTask task) async {
    task.status = DownloadServiceStatus.downloading;

    try {
      // Simulate download progress
      for (var i = 0; i <= 100; i += 10) {
        if (task.status != DownloadServiceStatus.downloading) return;
        task.progress = i / 100;
        task.downloadedBytes = (task.totalBytes * task.progress).toInt();
        _progressController.add(task);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      task.status = DownloadServiceStatus.completed;
      _active.remove(task.id);
      _completionController.add(task);
      _processQueue();
    } catch (e) {
      if (task.retryCount < maxRetries) {
        task.retryCount++;
        task.status = DownloadServiceStatus.pending;
        _active.remove(task.id);
        _queue.insert(0, task);
        _processQueue();
      } else {
        task.status = DownloadServiceStatus.failed;
        task.error = e.toString();
        _active.remove(task.id);
        _completionController.add(task);
        _processQueue();
      }
    }
  }

  /// Dispose the service and release resources.
  Future<void> dispose() async {
    await _progressController.close();
    await _completionController.close();
    _active.clear();
    _queue.clear();
  }
}

/// Status of a download service task.
enum DownloadServiceStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

/// A download task managed by the background service.
class DownloadServiceTask {
  DownloadServiceTask({
    required this.id,
    required this.url,
    required this.savePath,
    required this.title,
    this.totalBytes = 0,
    this.headers = const {},
  });

  final String id;
  final String url;
  final String savePath;
  final String title;
  final Map<String, String> headers;
  int totalBytes;
  int downloadedBytes = 0;
  double progress = 0;
  DownloadServiceStatus status = DownloadServiceStatus.pending;
  int retryCount = 0;
  String? error;
}
