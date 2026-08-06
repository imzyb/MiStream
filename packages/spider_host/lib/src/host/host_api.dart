/// Host API 处理器：处理 Runtime → Host 的 RPC 请求。
///
/// 包括 `host.fetch`、`host.storage.*`、`host.env` 等方法。
/// 见 `docs/08-RPC协议.md` §4。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

/// `host.fetch` 响应。
class FetchResult {
  /// HTTP 状态码。
  final int status;

  /// 响应头。
  final Map<String, String> headers;

  /// 响应体字节。
  final List<int> body;

  /// 最终 URL（跟随重定向后）。
  final String finalUrl;

  /// 耗时（毫秒）。
  final int elapsedMs;

  /// 构造抓取结果。
  const FetchResult({
    required this.status,
    required this.headers,
    required this.body,
    required this.finalUrl,
    required this.elapsedMs,
  });

  /// 序列化为 JSON 映射。
  Map<String, Object?> toJson() => {
    'status': status,
    'headers': headers,
    'body': utf8.decode(body),
    'finalUrl': finalUrl,
    'elapsedMs': elapsedMs,
  };
}

/// `host.fetch` 的配置。
class HostFetchConfig {
  /// 域名白名单。空列表表示允许所有（默认）。
  final List<String> allowedHosts;

  /// 最大响应体大小（字节）。默认 10MB。
  final int maxResponseBytes;

  /// 默认超时（毫秒）。默认 15_000。
  final int defaultTimeoutMs;

  /// 禁止的协议，默认只允许 http/https。
  bool Function(String protocol) isProtocolAllowed;

  /// 私网 / 回环地址拦截。
  bool Function(String host) isPrivateAddress;

  /// 构造抓取配置。
  HostFetchConfig({
    this.allowedHosts = const [],
    this.maxResponseBytes = 10 * 1024 * 1024,
    this.defaultTimeoutMs = 15000,
    bool Function(String protocol)? protocolChecker,
    bool Function(String host)? privateChecker,
  }) : isProtocolAllowed =
           protocolChecker ?? ((p) => p == 'http' || p == 'https'),
       isPrivateAddress = privateChecker ?? _defaultPrivateChecker;
}

bool _defaultPrivateChecker(String host) {
  return false; // 默认不拦截私网，由上层按需配置
}

/// Host API 的实现。
///
/// 处理 `host.fetch`、`host.env` 等请求。`host.storage.*` 需外部注入
/// 存储实现。
class HostApi {
  final HostFetchConfig _config;

  /// 构造 Host API。
  HostApi({HostFetchConfig? config}) : _config = config ?? HostFetchConfig();

  /// 处理 `host.fetch` 请求。
  ///
  /// params: `{instanceId, url, method, headers, body, timeoutMs, redirect, responseType}`
  Future<Result<FetchResult, AppError>> fetch(
    Map<String, Object?> params,
  ) async {
    final urlStr = params['url'] as String?;
    if (urlStr == null || urlStr.isEmpty) {
      return Err(
        LocalError(
          code: ErrorCode.invalidArgument,
          message: 'url 必填',
        ),
      );
    }

    final uri = Uri.tryParse(urlStr);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return Err(
        RemoteError(
          code: ErrorCode.invalidResultSchema,
          message: 'URL 格式非法: $urlStr',
        ),
      );
    }

    // 协议白名单
    if (!_config.isProtocolAllowed(uri.scheme)) {
      return Err(
        RemoteError(
          code: ErrorCode.protocolNotAllowed,
          message: '协议不允许: ${uri.scheme}',
        ),
      );
    }

    // SSRF 拦截：私网/回环地址
    if (_config.isPrivateAddress(uri.host)) {
      return Err(
        RemoteError(
          code: ErrorCode.privateAddressBlocked,
          message: '私网地址被拦截: ${uri.host}',
        ),
      );
    }

    // 域名白名单
    if (_config.allowedHosts.isNotEmpty &&
        !_config.allowedHosts.contains(uri.host)) {
      return Err(
        RemoteError(
          code: ErrorCode.hostNotAllowed,
          message: '域名不在白名单: ${uri.host}',
        ),
      );
    }

    final method = (params['method'] as String?) ?? 'GET';
    final timeoutMs =
        (params['timeoutMs'] as num?)?.toInt() ?? _config.defaultTimeoutMs;
    final followRedirects = params['redirect'] as bool? ?? true;

    final stopwatch = Stopwatch()..start();
    try {
      final client = HttpClient()
        ..connectionTimeout = Duration(milliseconds: timeoutMs);

      final request = await client.openUrl(method, uri);
      request.followRedirects = followRedirects;

      // 设置请求头
      if (params['headers'] is Map) {
        for (final entry in (params['headers'] as Map).entries) {
          request.headers.set(entry.key.toString(), entry.value.toString());
        }
      }

      // 设置请求体
      if (params['body'] != null && method != 'GET') {
        request.write(utf8.encode(params['body'] as String));
      }

      final response = await request.close().timeout(
        Duration(milliseconds: timeoutMs),
      );

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      // 读响应体，限制大小
      final bodyBytes = <int>[];
      await for (final chunk in response) {
        bodyBytes.addAll(chunk);
        if (bodyBytes.length > _config.maxResponseBytes) {
          client.close(force: true);
          return Err(
            RemoteError(
              code: ErrorCode.responseTooLarge,
              message: '响应超过大小上限',
            ),
          );
        }
      }

      stopwatch.stop();
      client.close();

      return Ok(
        FetchResult(
          status: response.statusCode,
          headers: responseHeaders,
          body: bodyBytes,
          finalUrl: response.redirects.isNotEmpty
              ? response.redirects.last.location.toString()
              : urlStr,
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
    } on HttpException catch (e) {
      return Err(
        RemoteError(
          code: ErrorCode.networkTlsError,
          message: 'HTTP 错误: $e',
        ),
      );
    } on TimeoutException {
      return Err(
        RemoteError(
          code: ErrorCode.networkTimeout,
          message: '请求超时',
        ),
      );
    } on Object catch (e) {
      return Err(AppError.from(e));
    }
  }

  /// 处理 `host.env` 请求。
  ///
  /// params: `{instanceId}`
  Map<String, Object?> env(Map<String, Object?> params) {
    return {
      'appVersion': 'dev',
      'platform': _platformName(),
      'defaultUA':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'locale': 'zh-CN',
    };
  }

  static String _platformName() {
    try {
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } on Object {
      // dart:io 可能不可用
    }
    return 'unknown';
  }
}
