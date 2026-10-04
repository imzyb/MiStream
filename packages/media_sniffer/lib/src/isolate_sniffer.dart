/// Isolate 嗅探器：把 `SnifferResolver` 放进 isolate 跑，超时可杀。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:media_sniffer/src/sniffer_resolver.dart';

Future<SniffResponse> _httpFetcher(
  String url,
  Map<String, String> headers,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await client.getUrl(Uri.parse(url));
    headers.forEach((k, v) => req.headers.set(k, v));
    final resp = await req.close().timeout(const Duration(seconds: 8));
    final body = await resp.transform(utf8.decoder).join();
    final ct = resp.headers.value('content-type');
    return SniffResponse(
      statusCode: resp.statusCode,
      body: body,
      contentType: ct,
      finalUrl: resp.redirects.isNotEmpty
          ? resp.redirects.last.location.toString()
          : url,
    );
  } finally {
    client.close(force: true);
  }
}

Future<String?> _sniffInIsolate(
  (String, Map<String, String>) args,
) async {
  final (url, headers) = args;
  final resolver = SnifferResolver(
    fetcher: _httpFetcher,
    verifyCandidates: false,
  );
  final outcome = await resolver.resolve(url, extraHeaders: headers);
  return outcome.media?.url;
}

/// 对外暴露的 isolate 嗅探器。
class IsolateSniffer {
  /// 嗅探 [url]，[headers] 会透传，超时 [timeout] 后返回 null。
  Future<String?> sniff(
    String url,
    Map<String, String> headers, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      return await Isolate.run(
        () => _sniffInIsolate((url, headers)),
      ).timeout(timeout);
    } on TimeoutException {
      return null;
    } on Object {
      return null;
    }
  }
}
