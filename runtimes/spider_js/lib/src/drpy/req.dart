/// drpy 宿主 API：req 网络请求函数。
///
/// 对齐 `docs/05-Spider引擎.md` §2.2 的 req API：
/// `req(url, options)` — method/headers/body/timeout/redirect/withHeaders/buffer/postType。
/// 所有网络请求收敛到宿主 `host.fetch`，由主进程统一施加白名单、SSRF 拦截等。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

/// req 函数的选项，对齐 drpy 的 options 对象。
class ReqOptions {
  /// 构造选项。
  const ReqOptions({
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.timeoutMs = 15000,
    this.followRedirect = true,
    this.buffer = false,
    this.postType,
  });

  /// HTTP 方法。
  final String method;

  /// 请求头。
  final Map<String, String> headers;

  /// 请求体。
  final String? body;

  /// 超时（毫秒）。drpy 源普遍不带超时，这里给一个兜底值。
  final int timeoutMs;

  /// 是否跟随重定向。重定向到私网仍会被宿主拦截。
  final bool followRedirect;

  /// 是否按二进制读取响应体。
  final bool buffer;

  /// 表单编码类型（`form` / `form-data` 等）。
  final String? postType;
}

/// req 响应结果。
class ReqResult {
  /// 构造结果。
  const ReqResult({
    required this.status,
    required this.headers,
    required this.body,
    required this.finalUrl,
    required this.elapsedMs,
  });

  /// HTTP 状态码。
  final int status;

  /// 响应头。
  final Map<String, String> headers;

  /// 响应体。
  final String body;

  /// 跟随重定向后的最终地址。
  final String finalUrl;

  /// 耗时（毫秒），供源诊断面板统计。
  final int elapsedMs;
}

/// drpy req 函数实现。
Future<Result<ReqResult, AppError>> req(
  String url, [
  ReqOptions options = const ReqOptions(),
]) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return Err(
      LocalError(
        code: ErrorCode.invalidArgument,
        message: 'URL 非法: $url',
      ),
    );
  }

  final stopwatch = Stopwatch()..start();
  try {
    final client = HttpClient()
      ..connectionTimeout = Duration(milliseconds: options.timeoutMs);

    final request = await client.openUrl(options.method, uri);
    request.followRedirects = options.followRedirect;

    for (final entry in options.headers.entries) {
      request.headers.set(entry.key, entry.value);
    }

    if (options.postType != null && options.method != 'GET') {
      request.headers.contentType = ContentType.parse(options.postType!);
    }

    if (options.body != null && options.method != 'GET') {
      request.write(utf8.encode(options.body!));
    }

    final response = await request.close().timeout(
      Duration(milliseconds: options.timeoutMs),
    );
    stopwatch.stop();

    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = values.join(', ');
    });

    String body;
    if (options.buffer) {
      final bytes = await response.toList();
      body = base64Encode(bytes.expand((b) => b).toList());
    } else {
      body = await response.transform(utf8.decoder).join();
    }

    client.close();

    return Ok(
      ReqResult(
        status: response.statusCode,
        headers: responseHeaders,
        body: body,
        finalUrl: response.redirects.isNotEmpty
            ? response.redirects.last.location.toString()
            : url,
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
