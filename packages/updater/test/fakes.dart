/// 测试替身：把「取网络」换成可编排的字节流。
///
/// 为什么不用真 HTTP：更新链的用例几乎全在**失败路径**上（sha 不符、size
/// 不符、500、空响应），而这些路径连真网根本造不出来。
library;

import 'dart:async';

import 'package:updater/updater.dart';

/// 按脚本返回响应的 fetcher。
final class FakeFetcher implements UpdateFetcher {
  /// [handler] 收到请求地址，返回响应。
  FakeFetcher(this.handler);

  /// 用固定字节体构造（最常用）。
  factory FakeFetcher.bytes(
    List<int> bytes, {
    int status = 200,
    int? contentLength,
  }) => FakeFetcher(
    (_) async =>
        responseOf(bytes, status: status, contentLength: contentLength),
  );

  /// 请求处理函数。
  final Future<UpdateResponse> Function(Uri url) handler;

  /// 收到的请求（按顺序）。
  final List<Uri> calls = [];

  @override
  Future<UpdateResponse> get(Uri url, {Map<String, String>? headers}) {
    calls.add(url);
    return handler(url);
  }

  @override
  void close() {}
}

/// 造一个响应。
UpdateResponse responseOf(
  List<int> bytes, {
  int status = 200,
  int? contentLength,
}) => UpdateResponse(
  statusCode: status,
  body: Stream<List<int>>.fromIterable([bytes]),
  contentLength: contentLength,
);

/// 分多块返回的响应 —— 用来验证「流式写入」与进度回调。
UpdateResponse chunkedOf(List<List<int>> chunks, {int status = 200}) =>
    UpdateResponse(
      statusCode: status,
      body: Stream<List<int>>.fromIterable(chunks),
    );
