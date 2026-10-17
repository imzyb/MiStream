/// 把「取 feed → 比较版本 → 下载校验」串成一次调用。
///
/// 为什么单独一层：应用侧只想知道「有没有更新、包在哪」，不该关心 feed 的
/// 形状、渠道选择、`.part` 命名。这一层同时也是**唯一**知道 feed URL 的地方。
library;

import 'dart:convert';
import 'dart:io';

import 'package:updater/src/update_checker.dart';
import 'package:updater/src/update_downloader.dart';
import 'package:updater/src/update_fetcher.dart';
import 'package:updater/src/update_manifest.dart';
import 'package:updater/src/update_version.dart';

/// 更新流程失败。
final class UpdateServiceException implements Exception {
  /// 构造。
  const UpdateServiceException(this.message, {this.retryable = false});

  /// 面向用户的中文短句。
  final String message;

  /// 是否值得重试。
  final bool retryable;

  @override
  String toString() => 'UpdateServiceException: $message';
}

/// 更新服务。
final class UpdateService {
  /// 构造。
  UpdateService({
    required this.fetcher,
    required this.feedUrl,
    this.channel = UpdateChannel.stable,
    this.assetKey = portableAssetKey,
    this.downloader,
    this.checker,
  });

  /// 取网络的实现（feed 与包共用）。
  final UpdateFetcher fetcher;

  /// feed 地址。
  final Uri feedUrl;

  /// 渠道。
  final UpdateChannel channel;

  /// 本机资产键。
  final String assetKey;

  /// 下载器；不给就用同一个 [fetcher] 建一个。
  final UpdateDownloader? downloader;

  /// 检查器；不给就用默认（只看 [assetKey]）。
  final UpdateChecker? checker;

  UpdateChecker get _checker => checker ?? UpdateChecker(assetKey: assetKey);

  /// 拉 feed 并判断。
  Future<UpdateCheckResult> check(AppVersion current) async {
    final manifest = await fetchManifest();
    return _checker.evaluate(current: current, manifest: manifest);
  }

  /// 只拉 feed。
  Future<UpdateManifest> fetchManifest() async {
    final response = await fetcher.get(feedUrl);
    if (!response.isOk) {
      throw UpdateServiceException(
        '取更新清单失败: HTTP ${response.statusCode}',
        retryable: response.statusCode >= 500 || response.statusCode == 429,
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.body) {
      bytes.addAll(chunk);
      // feed 是几十字节的 JSON；超过 1MB 一定是取错了东西（比如被网关换成了
      // 一个 HTML 错误页）。早点停，别把内存吃满。
      if (bytes.length > 1024 * 1024) {
        throw const UpdateServiceException('更新清单异常大（>1MB），已中止');
      }
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    final manifest = UpdateManifest.tryParse(body, channel: channel);
    if (manifest == null) {
      throw const UpdateServiceException('更新清单格式不对（不是合法的 latest.json）');
    }
    return manifest;
  }

  /// 下载并校验 [result] 对应的包。
  ///
  /// `async` 不是为了 `await`，而是为了让「没有资产」这类**前置**错误也走
  /// Future 的失败通道 —— 同步抛出的 Future 函数会让调用方漏掉 `catch`。
  Future<File> download(
    UpdateCheckResult result,
    Directory dir, {
    DownloadProgress? onProgress,
  }) async {
    final asset = result.asset;
    if (asset == null) {
      throw const UpdateServiceException('没有可下载的更新包（本平台缺资产）');
    }
    final d = downloader ?? UpdateDownloader(fetcher: fetcher);
    return d.download(asset: asset, dir: dir, onProgress: onProgress);
  }
}
