/// 下载任务模型。
class DownloadTask {
  /// 任务ID。
  final String id;

  /// 媒体标题。
  final String title;

  /// 原始URL（m3u8或mp4）。
  final String url;

  /// 保存路径。
  final String savePath;

  /// 任务状态。
  final DownloadStatus status;

  /// 下载进度（0.0 - 1.0）。
  final double progress;

  /// 已下载字节数。
  final int downloadedBytes;

  /// 总字节数（-1表示未知）。
  final int totalBytes;

  /// 创建时间。
  final int createdAt;

  /// 最后更新时间。
  final int updatedAt;

  /// 错误信息（失败时有值）。
  final String? error;

  /// 已下载的分片数（HLS）。
  final int downloadedSegments;

  /// 总分片数（HLS，-1表示未知）。
  final int totalSegments;

  const DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.savePath,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = -1,
    required this.createdAt,
    required this.updatedAt,
    this.error,
    this.downloadedSegments = 0,
    this.totalSegments = -1,
  });

  /// 从JSON构造。
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      savePath: json['savePath'] as String? ?? '',
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DownloadStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? -1,
      createdAt: json['createdAt'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? 0,
      error: json['error'] as String?,
      downloadedSegments: json['downloadedSegments'] as int? ?? 0,
      totalSegments: json['totalSegments'] as int? ?? -1,
    );
  }

  /// 转换为JSON。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'savePath': savePath,
      'status': status.name,
      'progress': progress,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (error != null) 'error': error,
      'downloadedSegments': downloadedSegments,
      'totalSegments': totalSegments,
    };
  }

  /// 复制并修改。
  DownloadTask copyWith({
    String? id,
    String? title,
    String? url,
    String? savePath,
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    int? createdAt,
    int? updatedAt,
    String? error,
    int? downloadedSegments,
    int? totalSegments,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      savePath: savePath ?? this.savePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      error: error ?? this.error,
      downloadedSegments: downloadedSegments ?? this.downloadedSegments,
      totalSegments: totalSegments ?? this.totalSegments,
    );
  }

  /// 是否可恢复。
  bool get isResumable => status == DownloadStatus.paused;

  /// 是否已完成。
  bool get isCompleted => status == DownloadStatus.completed;

  /// 是否失败。
  bool get isFailed => status == DownloadStatus.failed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTask &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DownloadTask(id: $id, title: $title, status: ${status.name})';
}

/// 下载状态枚举。
enum DownloadStatus {
  /// 等待中。
  pending,

  /// 下载中。
  downloading,

  /// 已暂停。
  paused,

  /// 已完成。
  completed,

  /// 失败。
  failed,

  /// 已取消。
  cancelled,
}
