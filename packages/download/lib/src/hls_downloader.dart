import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:download/src/download_progress.dart';

/// HLS下载器：下载m3u8播放列表及其分片。
class HlsDownloader {
  HlsDownloader({
    HttpClient? client,
    this.maxConcurrency = 3,
    this.timeoutSeconds = 30,
  }) : _client = client ?? HttpClient();

  /// HTTP客户端。
  final HttpClient _client;

  /// 最大并发下载数。
  final int maxConcurrency;

  /// 下载超时（秒）。
  final int timeoutSeconds;

  /// 下载HLS流。
  ///
  /// [url] m3u8播放列表URL
  /// [savePath] 保存目录
  /// [title] 媒体标题
  /// [onProgress] 进度回调
  /// [cancelToken] 取消令牌
  Future<DownloadResult> download({
    required String url,
    required String savePath,
    required String title,
    void Function(DownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final startTime = DateTime.now();
    var totalSegments = 0;
    var downloadedSegments = 0;
    const totalBytes = 0;
    var downloadedBytes = 0;

    try {
      // 1. 下载m3u8播放列表
      final m3u8Content = await _fetchContent(url);
      final segments = _parseM3u8(m3u8Content, url);

      // 检查是否为master playlist
      if (_isMasterPlaylist(m3u8Content)) {
        final bestUrl = _getBestStreamUrl(m3u8Content, url);
        if (bestUrl != null) {
          return await download(
            url: bestUrl,
            savePath: savePath,
            title: title,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        }
      }

      totalSegments = segments.length;

      // 2. 创建保存目录
      final dir = Directory(savePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 3. 逐个下载分片
      final semaphore = Semaphore(maxConcurrency);
      final futures = <Future<void>>[];

      for (var i = 0; i < segments.length; i++) {
        final segmentUrl = segments[i];
        final segmentIndex = i;

        futures.add(() async {
          // 检查取消
          if (cancelToken?.isCancelled == true) return;

          await semaphore.acquire();
          try {
            // 下载分片
            final segmentData = await _fetchBytes(segmentUrl);
            final segmentPath =
                '$savePath/segment_${segmentIndex.toString().padLeft(6, '0')}.ts';

            // 保存分片
            final file = File(segmentPath);
            await file.writeAsBytes(segmentData);

            downloadedSegments++;
            downloadedBytes += segmentData.length;

            // 报告进度
            onProgress?.call(
              DownloadProgress(
                taskId: '',
                status: DownloadProgressStatus.downloading,
                progress: totalSegments > 0
                    ? downloadedSegments / totalSegments
                    : 0,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                downloadedSegments: downloadedSegments,
                totalSegments: totalSegments,
              ),
            );
          } finally {
            semaphore.release();
          }
        }());
      }

      // 等待所有分片下载完成
      await Future.wait(futures);

      // 4. 生成合并脚本（可选）
      await _generateMergeScript(savePath, segments.length);

      final duration = DateTime.now().difference(startTime);

      return DownloadResult(
        success: true,
        savePath: savePath,
        totalSegments: totalSegments,
        downloadedSegments: downloadedSegments,
        totalBytes: downloadedBytes,
        duration: duration,
      );
    } catch (e) {
      return DownloadResult(
        success: false,
        error: e.toString(),
        totalSegments: totalSegments,
        downloadedSegments: downloadedSegments,
      );
    }
  }

  /// 下载单个文件。
  Future<DownloadResult> downloadFile({
    required String url,
    required String savePath,
    required String title,
    void Function(DownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final startTime = DateTime.now();

    try {
      final data = await _fetchBytes(url);
      final file = File(savePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data);

      return DownloadResult(
        success: true,
        savePath: savePath,
        totalSegments: 1,
        downloadedSegments: 1,
        totalBytes: data.length,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return DownloadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<String> _fetchContent(String url) async {
    final request = await _client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'MiStream/1.0');
    final response = await request.close().timeout(
      Duration(seconds: timeoutSeconds),
    );
    return response.transform(utf8.decoder).join();
  }

  Future<List<int>> _fetchBytes(String url) async {
    final request = await _client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'MiStream/1.0');
    final response = await request.close().timeout(
      Duration(seconds: timeoutSeconds),
    );
    return response.toList().then(
      (chunks) => chunks.expand((c) => c).toList(),
    );
  }

  List<String> _parseM3u8(String content, String baseUrl) {
    final segments = <String>[];
    final baseUri = Uri.parse(baseUrl);

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (trimmed.startsWith('http')) {
        segments.add(trimmed);
      } else {
        segments.add(baseUri.resolve(trimmed).toString());
      }
    }

    return segments;
  }

  bool _isMasterPlaylist(String content) {
    return content.contains('#EXT-X-STREAM-INF');
  }

  String? _getBestStreamUrl(String content, String baseUrl) {
    final baseUri = Uri.parse(baseUrl);
    var bestBandwidth = 0;
    String? bestUrl;

    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        if (bandwidthMatch != null) {
          final bandwidth = int.parse(bandwidthMatch.group(1)!);
          if (bandwidth > bestBandwidth) {
            bestBandwidth = bandwidth;
            if (i + 1 < lines.length) {
              final urlLine = lines[i + 1].trim();
              if (urlLine.startsWith('http')) {
                bestUrl = urlLine;
              } else {
                bestUrl = baseUri.resolve(urlLine).toString();
              }
            }
          }
        }
      }
    }

    return bestUrl;
  }

  Future<void> _generateMergeScript(String savePath, int segmentCount) async {
    final fileNames = List.generate(
      segmentCount,
      (i) => 'segment_${i.toString().padLeft(6, '0')}.ts',
    ).join('|');

    final command =
        '#!/bin/bash\n'
        'ffmpeg -i "concat:$fileNames" -c copy output.mp4\n';

    final scriptFile = File('$savePath/merge.sh');
    await scriptFile.writeAsString(command);
  }

  /// 释放资源。
  void dispose() {
    _client.close();
  }
}

/// 取消令牌。
class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// 信号量（控制并发）。
class Semaphore {
  Semaphore(this.maxCount) : _currentCount = maxCount;
  final int maxCount;
  int _currentCount;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final waiter = _waiters.removeAt(0);
      waiter.complete();
    } else {
      _currentCount++;
    }
  }
}

/// 下载结果。
class DownloadResult {
  const DownloadResult({
    required this.success,
    this.savePath,
    this.error,
    this.totalSegments = 0,
    this.downloadedSegments = 0,
    this.totalBytes = 0,
    this.duration,
  });

  /// 是否成功。
  final bool success;

  /// 保存路径。
  final String? savePath;

  /// 错误信息。
  final String? error;

  /// 总分片数。
  final int totalSegments;

  /// 已下载分片数。
  final int downloadedSegments;

  /// 总字节数。
  final int totalBytes;

  /// 下载耗时。
  final Duration? duration;

  @override
  String toString() =>
      'DownloadResult(success: $success, segments: $downloadedSegments/$totalSegments)';
}
