import 'dart:async';
import 'dart:io';
import 'dart:math';

/// HTTP download client with support for Range requests (resume from breakpoint).
class HttpDownloadClient {
  HttpDownloadClient({HttpClient? httpClient, this.maxRetries = 3})
    : _client = httpClient ?? HttpClient();

  final HttpClient _client;
  final int maxRetries;

  /// Download a file with automatic resume support.
  ///
  /// If [savePath] exists and has partial content, sends a Range request
  /// to resume from where it left off.
  Future<HttpDownloadResult> download({
    required String url,
    required String savePath,
    Map<String, String>? headers,
    void Function(int received, int? total)? onProgress,
  }) async {
    final saveFile = File(savePath);
    var downloadedBytes = 0;
    var totalBytes = 0;

    // Check for partial file
    if (saveFile.existsSync()) {
      downloadedBytes = await saveFile.length();
    }

    var retries = 0;
    while (retries <= maxRetries) {
      try {
        final uri = Uri.parse(url);
        final request = await _client.getUrl(uri);

        // Add Range header for resume
        if (downloadedBytes > 0) {
          request.headers.set('Range', 'bytes=$downloadedBytes-');
        }

        headers?.forEach((name, value) {
          request.headers.set(name, value);
        });

        final response = await request.close();
        final isPartial = response.statusCode == 206;

        if (response.statusCode == 200 && downloadedBytes > 0) {
          // Server doesn't support Range, restart download
          downloadedBytes = 0;
          await saveFile.writeAsBytes([], mode: FileMode.write);
        } else if (response.statusCode != 200 && !isPartial) {
          throw HttpDownloadException(
            'Server returned ${response.statusCode}',
            response.statusCode,
          );
        }

        // Get total content length
        final contentLength = response.headers.contentLength;
        if (isPartial) {
          // Content-Range: bytes 1000-1999/5000
          final contentRange = response.headers.value('content-range');
          if (contentRange != null) {
            final totalMatch = RegExp(r'/(\d+)').firstMatch(contentRange);
            if (totalMatch != null) {
              totalBytes = int.parse(totalMatch.group(1)!);
            }
          }
        } else {
          totalBytes = contentLength > 0 ? contentLength : 0;
        }

        // Append to existing file
        final sink = saveFile.openWrite(mode: FileMode.append);

        await for (final chunk in response) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          onProgress?.call(downloadedBytes, totalBytes > 0 ? totalBytes : null);
        }

        await sink.flush();
        await sink.close();

        return HttpDownloadResult(
          url: url,
          savePath: savePath,
          totalBytes: totalBytes,
          downloadedBytes: downloadedBytes,
          success: true,
        );
      } on SocketException {
        retries++;
        if (retries > maxRetries) rethrow;
        await Future<void>.delayed(Duration(seconds: pow(2, retries).toInt()));
      } on TimeoutException {
        retries++;
        if (retries > maxRetries) rethrow;
        await Future<void>.delayed(Duration(seconds: pow(2, retries).toInt()));
      }
    }

    return HttpDownloadResult(
      url: url,
      savePath: savePath,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      success: false,
      error: 'Max retries exceeded',
    );
  }

  /// Check if a URL supports Range requests.
  Future<bool> supportsRange(String url) async {
    try {
      final uri = Uri.parse(url);
      final request = await _client.headUrl(uri);
      final response = await request.close();
      final acceptRanges = response.headers.value('accept-ranges');
      return acceptRanges == 'bytes';
    } catch (_) {
      return false;
    }
  }

  /// Dispose the HTTP client.
  void dispose() {
    _client.close();
  }
}

/// Result of a download operation.
class HttpDownloadResult {
  const HttpDownloadResult({
    required this.url,
    required this.savePath,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.success,
    this.error,
  });

  final String url;
  final String savePath;
  final int totalBytes;
  final int downloadedBytes;
  final bool success;
  final String? error;

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0;
}

/// Exception thrown during download operations.
class HttpDownloadException implements Exception {
  const HttpDownloadException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'HttpDownloadException($statusCode): $message';
}
