import 'package:download/src/download_progress.dart';
import 'package:download/src/download_task.dart';
import 'package:download/src/hls_downloader.dart';
import 'package:download/src/http_download_client.dart';

/// 单个下载任务的执行器。
///
/// 把「跑一个任务」从「排队、限流、状态落库」里拆出来，理由是可测性：
/// 队列顺序、优先级、并发上限、状态迁移、崩溃恢复这些是 `DownloadManager`
/// 真正要保证的语义，而它们一条都不该依赖真实网络。默认实现
/// [DefaultDownloadTaskRunner] 才是唯一碰 `HttpClient` 的地方。
abstract class DownloadTaskRunner {
  /// 跑完一个任务并返回结果。**不负责**改状态，状态由调用方决定。
  Future<DownloadResult> run(
    DownloadTask task, {
    void Function(DownloadProgress progress)? onProgress,
    HlsSegmentDone? onSegmentDone,
    Set<int> skipSegments = const {},
    CancelToken? cancelToken,
  });

  /// 释放底层资源。
  void dispose();
}

/// 默认执行器：直链走 [HttpDownloadClient]，HLS 走 [HlsDownloader]。
class DefaultDownloadTaskRunner implements DownloadTaskRunner {
  /// 构造。
  DefaultDownloadTaskRunner({
    HttpDownloadClient? httpClient,
    HlsDownloader? hlsDownloader,
  }) : _httpClient = httpClient ?? HttpDownloadClient(),
       _hlsDownloader = hlsDownloader ?? HlsDownloader();

  final HttpDownloadClient _httpClient;
  final HlsDownloader _hlsDownloader;

  @override
  Future<DownloadResult> run(
    DownloadTask task, {
    void Function(DownloadProgress progress)? onProgress,
    HlsSegmentDone? onSegmentDone,
    Set<int> skipSegments = const {},
    CancelToken? cancelToken,
  }) async {
    // 判据收在 `DownloadTask.isHls` 一处。管理器、执行器、下载器各写一遍
    // `url.contains('m3u8')` 迟早会分叉成「管理器按直链存、下载器按 HLS 下」。
    if (task.isHls) {
      return _hlsDownloader.download(
        url: task.url,
        savePath: task.savePath,
        title: task.title,
        headers: task.headers,
        onProgress: onProgress,
        onSegmentDone: onSegmentDone,
        skipSegments: skipSegments,
        cancelToken: cancelToken,
      );
    }

    final result = await _httpClient.download(
      url: task.url,
      savePath: task.savePath,
      headers: task.headers,
      cancelToken: cancelToken,
      onProgress: (received, total) {
        onProgress?.call(
          DownloadProgress(
            taskId: '${task.id}',
            status: DownloadProgressStatus.downloading,
            progress: total != null && total > 0 ? received / total : 0,
            downloadedBytes: received,
            totalBytes: total ?? -1,
            downloadedSegments: 1,
            totalSegments: 1,
          ),
        );
      },
    );

    return DownloadResult(
      success: result.success,
      savePath: result.savePath,
      mergedPath: result.savePath,
      resolvedUrl: task.url,
      error: result.error,
      totalSegments: 1,
      downloadedSegments: result.success ? 1 : 0,
      totalBytes: result.totalBytes,
      downloadedBytes: result.downloadedBytes,
    );
  }

  @override
  void dispose() {
    _httpClient.dispose();
    _hlsDownloader.dispose();
  }
}
