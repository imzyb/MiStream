/// 下载进度信息。
class DownloadProgress {
  /// 任务ID。
  final String taskId;

  /// 当前状态。
  final DownloadProgressStatus status;

  /// 下载进度（0.0 - 1.0）。
  final double progress;

  /// 下载速度（字节/秒）。
  final int speed;

  /// 已下载字节数。
  final int downloadedBytes;

  /// 总字节数（-1表示未知）。
  final int totalBytes;

  /// 已下载分片数（HLS）。
  final int downloadedSegments;

  /// 总分片数（HLS）。
  final int totalSegments;

  /// 预计剩余时间（秒，-1表示未知）。
  final int eta;

  /// 错误信息。
  final String? error;

  const DownloadProgress({
    required this.taskId,
    required this.status,
    this.progress = 0.0,
    this.speed = 0,
    this.downloadedBytes = 0,
    this.totalBytes = -1,
    this.downloadedSegments = 0,
    this.totalSegments = -1,
    this.eta = -1,
    this.error,
  });

  /// 是否正在下载。
  bool get isDownloading => status == DownloadProgressStatus.downloading;

  /// 是否已完成。
  bool get isCompleted => status == DownloadProgressStatus.completed;

  /// 是否失败。
  bool get isFailed => status == DownloadProgressStatus.failed;

  /// 格式化下载速度。
  String get formattedSpeed {
    if (speed < 1024) return '$speed B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// 格式化已下载大小。
  String get formattedDownloaded {
    return _formatBytes(downloadedBytes);
  }

  /// 格式化总大小。
  String get formattedTotal {
    if (totalBytes < 0) return '未知';
    return _formatBytes(totalBytes);
  }

  /// 格式化预计剩余时间。
  String get formattedEta {
    if (eta < 0) return '计算中...';
    if (eta == 0) return '即将完成';
    final minutes = eta ~/ 60;
    final seconds = eta % 60;
    if (minutes > 0) return '${minutes}分${seconds}秒';
    return '${seconds}秒';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() =>
      'DownloadProgress(task: $taskId, progress: ${(progress * 100).toStringAsFixed(1)}%, speed: $formattedSpeed)';
}

/// 下载进度状态。
enum DownloadProgressStatus {
  /// 下载中。
  downloading,

  /// 已完成。
  completed,

  /// 失败。
  failed,
}
