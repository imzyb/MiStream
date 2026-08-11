/// HTTP 运行时 —— 无子进程的 Spider 实现。
///
/// 对 type=1（JSON API）源，直接通过 HTTP 调用远端 Spider API，不走子进程
/// RPC 管道。适用于 TVBox 标准的 JSON 接口源。
///
/// 见 `docs/05-Spider引擎.md` §1。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

/// HTTP 请求参数。
class HttpRequestParams {
  /// 构造请求参数。
  const HttpRequestParams({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.timeoutMs = 15000,
  });

  /// 请求 URL。
  final String url;

  /// HTTP 方法。
  final String method;

  /// 请求头。
  final Map<String, String> headers;

  /// 请求体。
  final String? body;

  /// 超时（毫秒）。
  final int timeoutMs;
}

/// HTTP 响应结果。
class HttpResponseData {
  /// 构造响应。
  const HttpResponseData({
    required this.status,
    required this.headers,
    required this.body,
    required this.finalUrl,
    required this.elapsedMs,
  });

  /// 状态码。
  final int status;

  /// 响应头。
  final Map<String, String> headers;

  /// 响应体（UTF-8 文本）。
  final String body;

  /// 最终 URL（跟随重定向后）。
  final String finalUrl;

  /// 耗时（毫秒）。
  final int elapsedMs;
}

/// HTTP 运行时 —— 直接调用远端 Spider API。
///
/// 使用 [baseUrl] 作为 API 入口，附加 `?action=...&...` 参数。
/// 支持 `home`、`category`、`detail`、`search`、`play` 等标准方法。
class HttpRuntime {
  /// 构造 HTTP 运行时。
  HttpRuntime(this.baseUrl);

  /// API 入口地址。
  final String baseUrl;

  /// 发送 HTTP 请求并解析 JSON 响应。
  Future<Result<HttpResponseData, AppError>> request(
    HttpRequestParams params,
  ) async {
    final uri = Uri.tryParse(params.url);
    if (uri == null) {
      return Err(
        LocalError(
          code: ErrorCode.invalidArgument,
          message: 'URL 非法: ${params.url}',
        ),
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final client = HttpClient()
        ..connectionTimeout = Duration(milliseconds: params.timeoutMs);

      final request = await client.openUrl(params.method, uri);
      for (final entry in params.headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (params.body != null && params.method != 'GET') {
        request.write(utf8.encode(params.body!));
      }
      final response = await request.close().timeout(
        Duration(milliseconds: params.timeoutMs),
      );
      stopwatch.stop();

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      final body = await response.transform(utf8.decoder).join();
      client.close();

      return Ok(
        HttpResponseData(
          status: response.statusCode,
          headers: responseHeaders,
          body: body,
          finalUrl: response.redirects.isNotEmpty
              ? response.redirects.last.location.toString()
              : params.url,
          elapsedMs: stopwatch.elapsedMilliseconds,
        ),
      );
    } on SocketException catch (e) {
      return Err(
        RemoteError(
          code: ErrorCode.networkTimeout,
          message: '网络错误: $e',
        ),
      );
    } on TimeoutException {
      return const Err(
        RemoteError(
          code: ErrorCode.networkTimeout,
          message: '请求超时',
        ),
      );
    } on Object catch (e) {
      return Err(AppError.from(e));
    }
  }

  /// 调用 Spider API 的 [action] 方法。
  ///
  /// 构造 URL: `{baseUrl}?action={action}&{params}`
  Future<Result<HttpResponseData, AppError>> call(
    String action, {
    Map<String, String> queryParams = const {},
    int timeoutMs = 15000,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'action': action,
        ...queryParams,
      },
    );
    return request(
      HttpRequestParams(
        url: uri.toString(),
        timeoutMs: timeoutMs,
      ),
    );
  }

  /// 首页内容。
  Future<Result<HttpResponseData, AppError>> home() =>
      call('home', timeoutMs: 10000);

  /// 分类列表。
  Future<Result<HttpResponseData, AppError>> category() =>
      call('category', timeoutMs: 10000);

  /// 分类详情（按分类 id 分页）。
  Future<Result<HttpResponseData, AppError>> categoryDetail({
    required String typeId,
    int page = 1,
  }) => call(
    'category',
    queryParams: {
      'id': typeId,
      'page': '$page',
    },
  );

  /// 搜索。
  Future<Result<HttpResponseData, AppError>> search({
    required String keyword,
    int page = 1,
  }) => call(
    'search',
    queryParams: {
      'wd': keyword,
      'page': '$page',
    },
  );

  /// 详情。
  Future<Result<HttpResponseData, AppError>> detail({
    required String ids,
  }) => call('detail', queryParams: {'ids': ids});

  /// 播放地址。
  Future<Result<HttpResponseData, AppError>> play({
    required String flag,
    required String ids,
  }) => call(
    'play',
    queryParams: {
      'flag': flag,
      'ids': ids,
    },
  );
}
