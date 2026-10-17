/// 取网络资源的薄抽象。
///
/// 为什么要这层：更新检查/下载必须能**离线测**。直接调 `HttpClient` 的话，
/// 「校验失败要不要删掉半个文件」「重定向算不算成功」这些用例都得连真网，
/// 在本机（沙箱 + 上游经常 403）根本跑不稳。
library;

import 'dart:io';

/// 一次 HTTP 响应。
final class UpdateResponse {
  /// 构造。
  const UpdateResponse({
    required this.statusCode,
    required this.body,
    this.contentLength,
    this.finalUrl,
  });

  /// 状态码。
  final int statusCode;

  /// 响应体（流式，避免把 100MB 的包整个读进内存）。
  final Stream<List<int>> body;

  /// `Content-Length`；未知为 `null`。
  final int? contentLength;

  /// 重定向后的最终地址（诊断用）。
  final String? finalUrl;

  /// 是否 2xx。
  bool get isOk => statusCode >= 200 && statusCode < 300;
}

/// 取资源的接口。
abstract interface class UpdateFetcher {
  /// GET 一个地址。
  Future<UpdateResponse> get(Uri url, {Map<String, String>? headers});

  /// 释放底层连接。
  void close();
}

/// 基于 `dart:io` 的实现。
final class HttpUpdateFetcher implements UpdateFetcher {
  /// 构造。
  HttpUpdateFetcher({
    this.userAgent = 'MiStream-Updater/0.1',
    Duration connectTimeout = const Duration(seconds: 15),
  }) : connectTimeout = connectTimeout,
       _client = HttpClient()..connectionTimeout = connectTimeout;

  /// UA。GitHub 的 raw/asset 端点对空 UA 不友好，固定一个更稳。
  final String userAgent;

  /// 连接超时。
  final Duration connectTimeout;

  final HttpClient _client;

  @override
  Future<UpdateResponse> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final request = await _client.getUrl(url).timeout(connectTimeout);
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
    headers?.forEach(request.headers.set);
    final response = await request.close().timeout(connectTimeout);
    return UpdateResponse(
      statusCode: response.statusCode,
      body: response,
      contentLength: response.contentLength >= 0
          ? response.contentLength
          : null,
    );
  }

  @override
  void close() => _client.close(force: true);
}
