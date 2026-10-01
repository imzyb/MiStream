import 'dart:convert';

/// 下载任务模型。
///
/// ⚠️ **`id` 是 `int`**，且 `0` 表示「尚未落库」。旧版本用的是
/// `DateTime.now().millisecondsSinceEpoch.toRadixString(16)` 生成的字符串，
/// 同一毫秒内建两个任务会得到**同一个 id**，`Map` 赋值直接覆盖 —— 实测建 5 个
/// 只活下来 2 个，中间 3 个静默丢失（探针
/// `.workbuddy-ai/scripts/probe_download_ids.dart`）。改成整数主键之后 id 由
/// 数据库自增（无库时由管理器自增）分配，不再有碰撞。
class DownloadTask {
  /// 构造任务。
  const DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.savePath,
    required this.createdAt,
    required this.updatedAt,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = -1,
    this.error,
    this.downloadedSegments = 0,
    this.totalSegments = -1,
    this.priority = 0,
    this.headers = const {},
  });

  /// 从 JSON 构造。
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as int? ?? 0,
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
      priority: json['priority'] as int? ?? 0,
      headers:
          (json['headers'] as Map?)?.map(
            (key, value) => MapEntry('$key', '$value'),
          ) ??
          const {},
    );
  }

  /// 任务 ID。**0 表示尚未落库**。
  final int id;

  /// 媒体标题。
  final String title;

  /// 原始 URL（m3u8 或直链）。
  final String url;

  /// 保存路径。直链是文件路径；HLS 是分片目录。
  final String savePath;

  /// 任务状态。
  final DownloadStatus status;

  /// 下载进度（0.0 - 1.0）。
  final double progress;

  /// 已下载字节数。
  final int downloadedBytes;

  /// 总字节数（-1 表示未知）。
  final int totalBytes;

  /// 创建时间（**Unix 秒**）。
  final int createdAt;

  /// 最后更新时间（**Unix 秒**）。
  final int updatedAt;

  /// 错误信息（失败时有值）。
  final String? error;

  /// 已下载的分片数（HLS）。
  final int downloadedSegments;

  /// 总分片数（HLS，-1 表示未知）。
  final int totalSegments;

  /// 优先级，**大的先跑**；同优先级按创建顺序。
  final int priority;

  /// 请求头（UA / Referer 之类，真实源常常必需）。
  final Map<String, String> headers;

  /// 是否 HLS（按 URL 判定）。
  ///
  /// 只用 `m3u8` 这个判据，不看扩展名大小写：真实源里 `.../index.M3U8?token=x`
  /// 这类写法都有。管理器与下载器必须用**同一个**判据，否则会出现「管理器按
  /// 直链下载、下载器按 HLS 处理」这种分叉。
  bool get isHls => url.toLowerCase().contains('m3u8');

  /// 落库用的媒体类型。
  String get mediaType => isHls ? 'hls' : 'direct';

  /// 转换为 JSON。
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
      'priority': priority,
      if (headers.isNotEmpty) 'headers': headers,
    };
  }

  /// 复制并修改。
  ///
  /// [clearError] 是必需的：`error` 用 `??` 兜底之后，`copyWith(error: null)`
  /// 表达不了「把错误清掉」，于是重试成功过的任务会一直带着上一次的错误信息。
  DownloadTask copyWith({
    int? id,
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
    int? priority,
    Map<String, String>? headers,
    bool clearError = false,
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
      error: clearError ? null : (error ?? this.error),
      downloadedSegments: downloadedSegments ?? this.downloadedSegments,
      totalSegments: totalSegments ?? this.totalSegments,
      priority: priority ?? this.priority,
      headers: headers ?? this.headers,
    );
  }

  /// 是否可恢复。
  ///
  /// `failed` 也算：失败的直链任务可以靠 `Range` 续，HLS 任务可以靠
  /// `download_segment` 跳过已完成的分片。只有 `completed` / `cancelled`
  /// 不该被「继续」。
  bool get isResumable =>
      status == DownloadStatus.paused || status == DownloadStatus.failed;

  /// 是否已完成。
  bool get isCompleted => status == DownloadStatus.completed;

  /// 是否失败。
  bool get isFailed => status == DownloadStatus.failed;

  /// 是否在排队等跑。
  bool get isPending => status == DownloadStatus.pending;

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
  /// 等待中（在队列里排队）。
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

/// 把请求头编码成 `headers_json` 列要的字符串；空表返回 `null`。
String? encodeHeaders(Map<String, String> headers) =>
    headers.isEmpty ? null : jsonEncode(headers);

/// 解码 `headers_json`；坏值返回空表而不抛异常。
Map<String, String> decodeHeaders(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return decoded.map((key, value) => MapEntry('$key', '$value'));
  } on FormatException {
    return const {};
  }
}
