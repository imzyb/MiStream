/// 下载更新包并**校验**。
///
/// 三条硬规则：
///   1. 先写 `.part`，校验通过才 `rename` 成正式文件 —— 否则「下到一半」的
///      文件会被下一次启动当成「已下载好」。
///   2. 校验失败**必须删掉** `.part`：留着只会让磁盘越来越脏，且下一次
///      下载会以为有缓存。
///   3. `size` 与 `sha256` 都是「feed 给了才校验」。没给就不校验 —— 那时
///      完整性只剩 TLS 一层，这一点必须写清楚，别让人以为默认就校验了。
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:updater/src/update_fetcher.dart';
import 'package:updater/src/update_manifest.dart';

/// 下载/校验失败。
///
/// 单独一个类型是为了让调用方能区分「网络失败（可重试）」与「校验失败
/// （重试也没用，要去查 feed）」。
final class UpdateDownloadException implements Exception {
  /// 构造。
  const UpdateDownloadException(this.message, {this.retryable = false});

  /// 面向用户的中文短句。
  final String message;

  /// 是否值得重试。
  final bool retryable;

  @override
  String toString() => 'UpdateDownloadException: $message';
}

/// 进度回调：`(已收字节, 总字节或 null)`。
typedef DownloadProgress = void Function(int received, int? total);

/// 下载器。
final class UpdateDownloader {
  /// 构造。
  const UpdateDownloader({required this.fetcher});

  /// 取网络的实现。
  final UpdateFetcher fetcher;

  /// 下载 [asset] 到 [dir]，返回**校验通过**的正式文件。
  Future<File> download({
    required UpdateAsset asset,
    required Directory dir,
    DownloadProgress? onProgress,
  }) async {
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, asset.resolvedFileName));
    final part = File('${target.path}.part');
    _discard(part);

    final response = await fetcher.get(Uri.parse(asset.url));
    if (!response.isOk) {
      throw UpdateDownloadException(
        '下载失败: HTTP ${response.statusCode}（${asset.url}）',
        retryable: response.statusCode >= 500 || response.statusCode == 429,
      );
    }

    final total = asset.size ?? response.contentLength;
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    var received = 0;
    final sink = part.openWrite();
    try {
      await for (final chunk in response.body) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      hasher.close();
    } on Object catch (e) {
      try {
        await sink.close();
      } on Object {
        // 关不掉也无所谓，下面会删文件。
      }
      _discard(part);
      throw UpdateDownloadException('下载中断: $e', retryable: true);
    } finally {
      // `openWrite` 的 sink 必须关，否则 Windows 上删不掉文件。
      try {
        await sink.close();
      } on Object {
        // 已经关过会抛，忽略。
      }
    }

    // 大小对不上 → 明确是「内容不完整」，比 sha 失败更容易解释。
    if (asset.size != null && received != asset.size) {
      _discard(part);
      throw UpdateDownloadException(
        '包大小不符: 期望 ${asset.size} 实际 $received 字节',
      );
    }
    if (received == 0) {
      _discard(part);
      throw const UpdateDownloadException('下载到 0 字节，源可能返回了空响应');
    }

    if (asset.sha256 != null) {
      final actual = digestSink.value?.toString() ?? '';
      if (actual != asset.sha256) {
        _discard(part);
        throw UpdateDownloadException(
          'sha256 不符: 期望 ${asset.sha256} 实际 $actual —— '
          '包可能被截断或被替换，已删除',
        );
      }
    }

    // 原子替换：Windows 上 rename 到已存在的文件会失败，先删旧的。
    if (target.existsSync()) target.deleteSync();
    part.renameSync(target.path);
    return target;
  }

  static void _discard(File part) {
    try {
      if (part.existsSync()) part.deleteSync();
    } on FileSystemException {
      // 删不掉也不该盖住真正的原因；下次下载会先清 `.part`。
    }
  }
}

/// `crypto` 的分块哈希需要 `Sink<Digest>`；这里收下最后的摘要。
final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
