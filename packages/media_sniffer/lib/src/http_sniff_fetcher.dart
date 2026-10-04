/// [SniffFetcher] 的 `dart:io` 实现。
///
/// 单独一个文件是为了让 `sniffer_resolver.dart` 保持无 IO 依赖——解析逻辑的单测
/// 因此不需要网络，也不需要 mock HTTP 栈，只喂 [SniffResponse] 即可。
library;

import 'dart:convert';
import 'dart:io';

import 'package:media_sniffer/src/sniffer_resolver.dart';

/// 用 [HttpClient] 取页面的 [SniffFetcher]。
///
/// 嗅探目标是采集站的播放页与 CDN，两者的证书链经常不完整，因此默认放行证书
/// 错误——这里取的都是公开页面，不传凭据，风险限于「可能连到中间人伪造的
/// 播放页」，而播放页本身不可信这件事已经由「候选地址要验证」覆盖了。
class HttpSniffFetcher {
  /// 构造抓取器。
  ///
  /// [timeout] 同时作为连接超时与整体超时；[maxBodyBytes] 限制读入内存的大小，
  /// 防止把一整条 mp4 拉进内存（验证候选地址时只需要头部）。
  // ignore_for_file: prefer_initializing_formals — 字段是私有的，而命名参数不
  // 允许以下划线开头，因此无法写成 `this._timeout`；这条 lint 在该组合下是误报。
  HttpSniffFetcher({
    Duration timeout = const Duration(seconds: 10),
    int maxBodyBytes = 2 * 1024 * 1024,
    bool allowBadCertificates = true,
  }) : _timeout = timeout,
       _maxBodyBytes = maxBodyBytes,
       _allowBadCertificates = allowBadCertificates;

  final Duration _timeout;
  final int _maxBodyBytes;
  final bool _allowBadCertificates;

  /// 作为 [SniffFetcher] 使用的入口。
  Future<SniffResponse> call(String url, Map<String, String> headers) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    if (_allowBadCertificates) {
      client.badCertificateCallback = (_, _, _) => true;
    }
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      request
        ..followRedirects = true
        ..maxRedirects = 5;
      headers.forEach(request.headers.set);

      final response = await request.close().timeout(_timeout);

      final bytes = <int>[];
      await for (final chunk in response.timeout(_timeout)) {
        bytes.addAll(chunk);
        if (bytes.length >= _maxBodyBytes) break;
      }

      return SniffResponse(
        statusCode: response.statusCode,
        body: utf8.decode(bytes, allowMalformed: true),
        contentType: response.headers.contentType?.toString(),
        finalUrl: response.redirects.isNotEmpty
            ? response.redirects.last.location.toString()
            : url,
      );
    } finally {
      client.close(force: true);
    }
  }
}
