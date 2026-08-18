/// HTTP 运行时 —— 无子进程的 Spider 实现。
///
/// 对 type=1（JSON API / 苹果 CMS 风格）源，直接通过 HTTP 调用远端 API，
/// 不走子进程 RPC 管道。
///
/// 支持标准 Apple CMS v2 协议：
/// - `GET {api}/?ac=videolist` — 首页列表
/// - `GET {api}/?ac=list` — 分类列表
/// - `GET {api}/?ac=list&t={tid}&pg={page}` — 分类详情
/// - `GET {api}/?ac=detail&ids={ids}` — 详情
/// - `GET {api}/?ac=videolist&wd={keyword}` — 搜索
///
/// 见 `docs/05-Spider引擎.md` §2.1、§5.3。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

/// Apple CMS v2 默认 User-Agent。
const _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

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

/// HTTP 运行时 —— 直接调用远端 Apple CMS v2 API。
///
/// 使用 [baseUrl] 作为 API 入口，附加 `?ac=...&...` 参数。
/// 支持 `videolist`、`list`、`detail` 等标准 Apple CMS 方法。
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
      // 设置默认 User-Agent
      request.headers.set('User-Agent', _defaultUserAgent);
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

  /// 调用 Apple CMS v2 API。
  ///
  /// 构造 URL: `{baseUrl}?ac={ac}&{params}`
  Future<Result<HttpResponseData, AppError>> call(
    String ac, {
    Map<String, String> queryParams = const {},
    int timeoutMs = 15000,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'ac': ac,
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

  /// 首页列表（Apple CMS: ac=videolist）。
  Future<Result<HttpResponseData, AppError>> home({int page = 1}) => call(
    'videolist',
    queryParams: {'pg': '$page'},
    timeoutMs: 10000,
  );

  /// 分类列表（Apple CMS: ac=list，无 tid 返回所有分类）。
  Future<Result<HttpResponseData, AppError>> category() => call(
    'list',
    timeoutMs: 10000,
  );

  /// 分类详情（Apple CMS: ac=list&t={tid}&pg={page}）。
  Future<Result<HttpResponseData, AppError>> categoryDetail({
    required String typeId,
    int page = 1,
  }) => call(
    'list',
    queryParams: {
      't': typeId,
      'pg': '$page',
    },
  );

  /// 搜索（Apple CMS: ac=videolist&wd={keyword}）。
  Future<Result<HttpResponseData, AppError>> search({
    required String keyword,
    int page = 1,
  }) => call(
    'videolist',
    queryParams: {
      'wd': keyword,
      'pg': '$page',
    },
  );

  /// 详情（Apple CMS: ac=detail&ids={ids}）。
  Future<Result<HttpResponseData, AppError>> detail({
    required String ids,
  }) => call('detail', queryParams: {'ids': ids});

  /// 播放地址。
  ///
  /// 对于 type=1 Apple CMS 源，播放地址通常在 detail 响应的
  /// `vod_play_url` 字段中。此方法用于需要单独解析播放地址的场景。
  Future<Result<HttpResponseData, AppError>> play({
    required String flag,
    required String ids,
  }) => call(
    'detail',
    queryParams: {'ids': ids},
  );
}
