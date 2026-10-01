import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:download/src/download_cancel.dart';
import 'package:download/src/download_progress.dart';

/// 取消令牌。
///
/// 实现在 `download_cancel.dart`；这里转出一次，让老的
/// `import 'hls_downloader.dart'` 继续能拿到它。
export 'download_cancel.dart' show CancelToken;

/// 拉文本（m3u8 播放列表）的传输函数。
typedef HlsFetchText =
    Future<String> Function(Uri url, Map<String, String> headers);

/// 拉字节（分片）的传输函数。
typedef HlsFetchBytes =
    Future<List<int>> Function(Uri url, Map<String, String> headers);

/// 把字节落盘的传输函数。
///
/// 与 [HlsFetchBytes] 对称：那是「网络那一半」，这是「磁盘那一半」。单独留出来
/// 是为了让**原子写策略**可验证 —— 「先写 `.part` 再改名」这条保障唯一的可观测
/// 差别就是「写出去的中间文件名不是成品名」，落盘不可注入的话它只能靠崩溃注入
/// 才能看见，等于没有回归测试。
typedef HlsWriteBytes = Future<void> Function(String path, List<int> bytes);

/// 一个分片落盘成功。
///
/// 参数是 `(序号, 地址, 字节数)`，与 `download_segment` 表的
/// `(seq, url, bytes)` 一一对应 —— 回调的职责就是让调用方把这三样落库，
/// 下次续传才知道哪些片不用再下。
typedef HlsSegmentDone = void Function(int seq, String url, int bytes);

/// HLS下载器：下载m3u8播放列表及其分片。
///
/// **传输层可注入**（[fetchText] / [fetchBytes]）：分片续传、master 选流、
/// 取消这些是本类真正要保证的逻辑，它们一条都不该依赖真实网络。默认实现走
/// [HttpClient]，测试传入假函数即可覆盖全部分支。
class HlsDownloader {
  HlsDownloader({
    HttpClient? client,
    HlsFetchText? fetchText,
    HlsFetchBytes? fetchBytes,
    HlsWriteBytes? writeBytes,
    this.maxConcurrency = 3,
    this.timeoutSeconds = 30,
    this.userAgent = 'MiStream/1.0',
  }) : _client = fetchText == null || fetchBytes == null
           ? (client ?? HttpClient())
           : null,
       _fetchText = fetchText,
       _fetchBytes = fetchBytes,
       _writeBytes = writeBytes;

  /// HTTP客户端；两个传输函数都注入了时为 `null`。
  final HttpClient? _client;

  /// 注入的文本传输函数；`null` 时用 [_client] 现搭一个。
  final HlsFetchText? _fetchText;

  /// 注入的字节传输函数；`null` 时用 [_client] 现搭一个。
  final HlsFetchBytes? _fetchBytes;

  /// 注入的落盘函数；`null` 时用 `File.writeAsBytes`。
  final HlsWriteBytes? _writeBytes;

  /// 最大并发下载数。
  final int maxConcurrency;

  /// 下载超时（秒）。
  final int timeoutSeconds;

  /// 默认 User-Agent；真实源普遍校验它。
  final String userAgent;

  /// 下载HLS流。
  ///
  /// [url] m3u8播放列表URL
  /// [savePath] 保存目录
  /// [title] 媒体标题
  /// [headers] 额外请求头（UA / Referer / Cookie，真实源常常必需）
  /// [onProgress] 进度回调
  /// [onSegmentDone] 单个分片落盘后的回调，用来把 `(seq, url, bytes)` 落库
  /// [skipSegments] 已下载完成、本次应跳过的分片序号（断点续传）
  /// [cancelToken] 取消令牌
  Future<DownloadResult> download({
    required String url,
    required String savePath,
    required String title,
    Map<String, String> headers = const {},
    void Function(DownloadProgress)? onProgress,
    HlsSegmentDone? onSegmentDone,
    Set<int> skipSegments = const {},
    CancelToken? cancelToken,
  }) async {
    final startTime = DateTime.now();
    var totalSegments = 0;
    var downloadedSegments = 0;
    var downloadedBytes = 0;
    var resolvedUrl = url;

    try {
      // 1. 下载m3u8播放列表
      final m3u8Content = await _fetchTextImpl(Uri.parse(url), headers);
      final segments = _parseM3u8(m3u8Content, url);

      // 检查是否为master playlist
      if (_isMasterPlaylist(m3u8Content)) {
        final bestUrl = _getBestStreamUrl(m3u8Content, url);
        if (bestUrl != null && bestUrl != url) {
          resolvedUrl = bestUrl;
          // 递归解析变体列表。选流规则是确定的（取 BANDWIDTH 最大），所以同一
          // 个任务两次运行的**分片序号含义一致** —— 否则按序号跳过已完成分片
          // 会错位，续传出来的文件是坏的。
          return await download(
            url: bestUrl,
            savePath: savePath,
            title: title,
            headers: headers,
            onProgress: onProgress,
            onSegmentDone: onSegmentDone,
            skipSegments: skipSegments,
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

      // 只认**同时满足两个条件**的序号：落在本播放列表范围内，且分片文件真的
      // 还在盘上。
      //
      // 范围检查：播放列表变短时（源换了、任务重下），库里可能留着越界的旧序号，
      // 把它们算进「已完成」会让进度虚高。
      // 盘上检查：用户手动删过下载目录、或换过保存路径时，记录还在但文件没了；
      // 只看记录就会把缺失的分片跳过，最后拼出一个**中间缺一段**的合并文件 ——
      // 这是下载器最糟的失败模式：它不报错，只是播到一半花屏或跳帧。
      final effectiveSkip = <int>{};
      for (final seq in skipSegments) {
        if (seq < 0 || seq >= totalSegments) continue;
        if (!File(_segmentPath(savePath, seq)).existsSync()) continue;
        effectiveSkip.add(seq);
      }
      downloadedSegments = effectiveSkip.length;

      // 3. 逐个下载分片
      final semaphore = Semaphore(maxConcurrency);
      final futures = <Future<void>>[];

      for (var i = 0; i < segments.length; i++) {
        final segmentIndex = i;
        final segmentUrl = segments[i];

        if (effectiveSkip.contains(segmentIndex)) continue;

        futures.add(() async {
          if (cancelToken?.isCancelled == true) return;

          await semaphore.acquire();
          try {
            if (cancelToken?.isCancelled == true) return;

            final segmentData = await _fetchBytesImpl(
              Uri.parse(segmentUrl),
              headers,
            );
            final segmentPath = _segmentPath(savePath, segmentIndex);

            // 先写 `.part` 再改名：`writeAsBytes` 不是原子的，进程在写一半时
            // 被杀会留下**长度不对的成品文件**，而续传时那个序号已被记为完成，
            // 于是拼出来的视频中间缺一段且无人察觉。改名之后要么是完整的成品，
            // 要么只有个 `.part` 残file，而 `.part` 不参与「已完成」判定。
            final partPath = '$segmentPath.part';
            await _writeBytesImpl(partPath, segmentData);
            await File(partPath).rename(segmentPath);

            downloadedSegments++;
            downloadedBytes += segmentData.length;

            onSegmentDone?.call(segmentIndex, segmentUrl, segmentData.length);
            onProgress?.call(
              DownloadProgress(
                taskId: '',
                status: DownloadProgressStatus.downloading,
                progress: totalSegments > 0
                    ? downloadedSegments / totalSegments
                    : 0,
                downloadedBytes: downloadedBytes,
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

      if (cancelToken?.isCancelled == true) {
        return DownloadResult(
          success: false,
          error: '已取消',
          totalSegments: totalSegments,
          downloadedSegments: downloadedSegments,
        );
      }

      // 4. 合并成一个可播文件
      //
      // 为什么用字节拼接而不是生成 ffmpeg 脚本：MPEG-TS 与 fMP4 都是「分片首尾
      // 相接即合法」的容器，直接拼就是对的。而原来生成的
      // `ffmpeg -i "concat:a|b|c"` **是错的** —— concat 协议要的是文件列表，
      // 或者 `concat:` 后跟**同一个**文件重复读取，`|` 分隔多个文件它不认。
      // 脚本既然不对，又让离线播放凭空依赖外部 ffmpeg，不如在 Dart 里拼完。
      final fileNames = [
        for (var i = 0; i < totalSegments; i++) _segmentFileName(i),
      ];
      final mergedPath = await _mergeSegments(
        savePath,
        fileNames,
        extension: _mergedExtension(segments),
      );

      // 跳过的那部分分片没有走下载回调，字节数只能从盘上数回来，否则进度会
      // 显示成「续传后总大小缩水」。
      downloadedBytes = await _sumBytes(savePath, fileNames);

      return DownloadResult(
        success: true,
        savePath: savePath,
        mergedPath: mergedPath,
        resolvedUrl: resolvedUrl,
        totalSegments: totalSegments,
        downloadedSegments: downloadedSegments,
        totalBytes: downloadedBytes,
        downloadedBytes: downloadedBytes,
        duration: DateTime.now().difference(startTime),
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
    Map<String, String> headers = const {},
    void Function(DownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final startTime = DateTime.now();

    try {
      final data = await _fetchBytesImpl(Uri.parse(url), headers);
      final file = File(savePath);
      await file.parent.create(recursive: true);
      final partPath = '$savePath.part';
      await _writeBytesImpl(partPath, data);
      await File(partPath).rename(savePath);

      return DownloadResult(
        success: true,
        savePath: savePath,
        mergedPath: savePath,
        resolvedUrl: url,
        totalSegments: 1,
        downloadedSegments: 1,
        totalBytes: data.length,
        downloadedBytes: data.length,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return DownloadResult(success: false, error: e.toString());
    }
  }

  /// 分片文件名。
  static String _segmentFileName(int index) =>
      'segment_${index.toString().padLeft(6, '0')}.ts';

  /// 分片完整路径。
  static String _segmentPath(String savePath, int index) =>
      '$savePath/${_segmentFileName(index)}';

  Future<String> _fetchTextImpl(Uri url, Map<String, String> headers) {
    final injected = _fetchText;
    if (injected != null) return injected(url, headers);
    return _defaultFetchText(url, headers);
  }

  Future<List<int>> _fetchBytesImpl(Uri url, Map<String, String> headers) {
    final injected = _fetchBytes;
    if (injected != null) return injected(url, headers);
    return _defaultFetchBytes(url, headers);
  }

  Future<void> _writeBytesImpl(String path, List<int> bytes) {
    final injected = _writeBytes;
    if (injected != null) return injected(path, bytes);
    return File(path).writeAsBytes(bytes, flush: true);
  }

  Future<String> _defaultFetchText(Uri url, Map<String, String> headers) async {
    final request = await _client!.getUrl(url);
    _applyHeaders(request, headers);
    final response = await request.close().timeout(
      Duration(seconds: timeoutSeconds),
    );
    if (response.statusCode >= 400) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    return response.transform(utf8.decoder).join();
  }

  Future<List<int>> _defaultFetchBytes(
    Uri url,
    Map<String, String> headers,
  ) async {
    final request = await _client!.getUrl(url);
    _applyHeaders(request, headers);
    final response = await request.close().timeout(
      Duration(seconds: timeoutSeconds),
    );
    if (response.statusCode >= 400) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    return response.toList().then((chunks) => chunks.expand((c) => c).toList());
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String> headers) {
    // 自定义头在后：真实源给的 UA 必须能盖掉默认值，否则带鉴权的源直接 403。
    request.headers.set('User-Agent', userAgent);
    headers.forEach((name, value) {
      if (value.isEmpty) return;
      request.headers.set(name, value);
    });
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

  /// 合并文件的扩展名：分片是 fMP4 就出 `.mp4`，否则 `.ts`。
  String _mergedExtension(List<String> segments) {
    if (segments.isEmpty) return 'ts';
    final path = Uri.tryParse(segments.last)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m4s') || path.endsWith('.mp4')) return 'mp4';
    return 'ts';
  }

  Future<String> _mergeSegments(
    String savePath,
    List<String> fileNames, {
    required String extension,
  }) async {
    final output = File('$savePath/merged.$extension');
    final sink = output.openWrite();
    try {
      for (final name in fileNames) {
        final file = File('$savePath/$name');
        if (!await file.exists()) {
          // 合并前少一片，拼出来的就是个坏文件。这里必须**报错**，不能跳过：
          // 跳过会照样返回 success，用户拿到一个播到一半花屏的成品却毫无提示。
          // 缺片不是理论情况 —— 下载目录被手动清理、杀毒软件误删都会造成它。
          throw StateError('分片缺失，无法合并: $name');
        }
        await sink.addStream(file.openRead());
      }
    } on Object {
      // 半成品不能留在盘上：它的名字与成品一模一样，播放页和用户都可能把它
      // 当成「下好的文件」。删掉，让「没有合并文件」成为唯一信号。
      await _discardOutput(sink, output);
      rethrow;
    }
    await sink.flush();
    await sink.close();
    return output.path;
  }

  /// 关掉写入流并删掉半成品。
  ///
  /// 两个 `try` 各自吞异常：走到这里本来就是因为已经出错了，清理失败不该把
  /// 原始错误盖掉 —— 调用方要看到的是「分片缺失」，不是「关闭文件失败」。
  Future<void> _discardOutput(IOSink sink, File output) async {
    try {
      await sink.close();
    } on Object {
      // 已经出错，关不掉无所谓。
    }
    try {
      if (await output.exists()) await output.delete();
    } on Object {
      // 同上。
    }
  }

  Future<int> _sumBytes(String savePath, List<String> fileNames) async {
    var total = 0;
    for (final name in fileNames) {
      final file = File('$savePath/$name');
      if (await file.exists()) total += await file.length();
    }
    return total;
  }

  /// 释放资源。
  void dispose() {
    _client?.close();
  }
}

/// 信号量（控制并发）。
class Semaphore {
  /// 构造。
  Semaphore(this.maxCount) : _currentCount = maxCount;

  /// 最大并发数。
  final int maxCount;
  int _currentCount;
  final _waiters = <Completer<void>>[];

  /// 获取一个名额，没有则等待。
  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  /// 归还一个名额。
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
  /// 构造。
  const DownloadResult({
    required this.success,
    this.savePath,
    this.mergedPath,
    this.resolvedUrl,
    this.error,
    this.totalSegments = 0,
    this.downloadedSegments = 0,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.duration,
  });

  /// 是否成功。
  final bool success;

  /// 保存路径。直链是文件路径；HLS 是分片目录。
  final String? savePath;

  /// HLS 合并后的可播文件路径；直链与 [savePath] 相同。
  ///
  /// 离线播放要的是这个文件，不是那个装满 `.ts` 的目录。
  final String? mergedPath;

  /// 实际取到分片的那条播放列表地址。
  ///
  /// master 列表会被解析成某个变体，播放页要记的是变体地址 —— 否则下次播放
  /// 又从头走一遍选流，还可能选中另一条码率。
  final String? resolvedUrl;

  /// 错误信息。
  final String? error;

  /// 总分片数。
  final int totalSegments;

  /// 已下载分片数。
  final int downloadedSegments;

  /// 总字节数。
  final int totalBytes;

  /// 已下载字节数。
  final int downloadedBytes;

  /// 下载耗时。
  final Duration? duration;

  /// 进度（0.0 - 1.0）。
  double get progress =>
      totalSegments > 0 ? downloadedSegments / totalSegments : 0;

  @override
  String toString() =>
      'DownloadResult(success: $success, segments: $downloadedSegments/$totalSegments)';
}
