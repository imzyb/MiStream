/// libmpv 随包分发与校验。
///
/// 分发的核心不是「把 DLL 拷贝出去」，而是**可复现**：每次安装都在固定版本上，
/// 下载后先校验 SHA256 才解包，任何漂移（来源被改、磁盘损坏、cdn 换包）都会
/// 在解包前被拒绝。依据 docs/03-技术选型.md §2：libmpv 必须锁版本 + 校验 hash，
/// 不能随系统漂移——播放行为的回归极难定位，而「用户机器上的库悄悄换了」会让
/// issue 完全不可复现。
///
/// 本包是纯命令行工具（`dart run tools/libmpv_dist/bin/libmpv_dist.dart`）：
/// 产物是解包后的 `libmpv-2.dll`，不参与应用运行时。运行时通过
/// `MediaKitRuntime.ensureInitialized(libmpv: <path>)` 或 `LIBMPV_LIBRARY_PATH`
/// 指向它，见 packages/player_engine。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// 一个可见的校验失败。
final class LibmpvException implements Exception {
  /// 构造失败。
  const LibmpvException(this.message);

  /// 说明。
  final String message;

  @override
  String toString() => 'LibmpvException: $message';
}

/// 锁定的 libmpv 清单（[assets/libmpv.manifest.json] 的结构）。
@immutable
final class LibmpvManifest {
  /// 解析清单 JSON。
  const LibmpvManifest({
    required this.platform,
    required this.version,
    required this.archive,
    required this.url,
    required this.sha256,
    required this.dllSha256,
    required this.dll,
  });

  /// 从 JSON 字符串解析。
  factory LibmpvManifest.fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const LibmpvException('清单必须是 JSON 对象');
    }

    String stringOf(String key) {
      final value = decoded[key];
      if (value is! String || value.isEmpty) {
        throw LibmpvException('清单缺少字符串字段「$key」');
      }
      return value;
    }

    final manifest = LibmpvManifest(
      platform: stringOf('platform'),
      version: stringOf('version'),
      archive: stringOf('archive'),
      url: stringOf('url'),
      sha256: stringOf('sha256'),
      dllSha256: stringOf('dllSha256'),
      dll: stringOf('dll'),
    );
    return manifest..validate();
  }

  /// 目标平台，如 `windows-x64`。
  final String platform;

  /// 发布标签，如 `2023-09-24`。
  final String version;

  /// 归档文件名。
  final String archive;

  /// 下载地址。
  final String url;

  /// 归档的 SHA256（十六进制小写），校验下载完整性。
  final String sha256;

  /// 解包后 [dll] 的 SHA256，校验真正随包分发的文件。
  final String dllSha256;

  /// 解包后取出的库文件名。
  final String dll;

  /// 校验字段自洽。
  void validate() {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      throw LibmpvException('sha256 必须是 64 位十六进制，得到「$sha256」');
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(dllSha256)) {
      throw LibmpvException('dllSha256 必须是 64 位十六进制，得到「$dllSha256」');
    }
    if (!url.endsWith(archive)) {
      throw LibmpvException('url 应以归档名 $archive 结尾');
    }
  }
}

/// 分发器的依赖（便于测试注入，不实际下载）。
final class LibmpvDistribution {
  /// 构造分发器。
  LibmpvDistribution({
    required this.manifest,
    Future<String> Function(File file)? computeSha256,
    Future<void> Function(File archive, Directory dest)? extract,
    Future<List<int>> Function(String url)? fetch,
  }) : computeSha256 = computeSha256 ?? sha256Of,
       extract = extract ?? _extractArchive,
       fetch = fetch ?? _httpGetBytes;

  /// 清单。
  final LibmpvManifest manifest;

  /// SHA256 计算函数，默认 [sha256Of]。
  final Future<String> Function(File file) computeSha256;

  /// 解包实现，默认 [_extractArchive]，用系统 `tar`。
  final Future<void> Function(File archive, Directory dest) extract;

  /// 网络请求，默认 [_httpGetBytes]。
  final Future<List<int>> Function(String url) fetch;

  /// 把 `libmpv-2.dll` 装进 [dest]。
  ///
  /// 幂等：若 [dest]/[dll 名] 已存在且哈希等于 [LibmpvManifest.dllSha256] 则
  /// 直接复用，不重新下载——CI 里每次构建都重下 8.7MB 没有意义。返回安装到的
  /// DLL 绝对路径。
  Future<File> install(File cacheFile, Directory dest) async {
    final dll = File('${dest.path}/${manifest.dll}');
    if (dll.existsSync() &&
        await computeSha256(dll) == manifest.dllSha256.toLowerCase()) {
      return dll;
    }

    final archivePath = cacheFile.path;
    if (!cacheFile.existsSync()) {
      await cacheFile.create(recursive: true);
      await cacheFile.writeAsBytes(await fetch(manifest.url), flush: true);
    }

    final actual = await computeSha256(cacheFile);
    if (actual.toLowerCase() != manifest.sha256.toLowerCase()) {
      throw LibmpvException(
        '归档 SHA256 不匹配：期望 ${manifest.sha256}，实际 $actual\n'
        '来源 ${manifest.url} 可能已变更，或下载损坏。删除缓存后重试：'
        '$archivePath',
      );
    }

    await dest.create(recursive: true);
    await extract(cacheFile, dest);

    if (!dll.existsSync()) {
      throw LibmpvException('解包后未找到 ${manifest.dll}，请检查归档结构');
    }
    final dllActual = await computeSha256(dll);
    if (dllActual != manifest.dllSha256.toLowerCase()) {
      throw LibmpvException(
        '${manifest.dll} SHA256 不匹配：期望 ${manifest.dllSha256}，实际 '
        '$dllActual。归档与清单不一致，请升级清单（见 assets/CHANGELOG.md）',
      );
    }
    return dll;
  }
}

/// 计算文件的 SHA256（十六进制小写）。
Future<String> sha256Of(File file) async {
  final bytes = sha256.bind(file.openRead());
  final digest = await bytes.first;
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Future<void> _extractArchive(File archive, Directory dest) async {
  final result = await Process.run(
    'tar',
    ['-xf', archive.path, '-C', dest.path],
  );
  if (result.exitCode != 0) {
    throw LibmpvException(
      '解包失败（tar 退出码 ${result.exitCode}）：${result.stderr}',
    );
  }
}

Future<List<int>> _httpGetBytes(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw LibmpvException('下载失败 HTTP ${response.statusCode}：$url');
    }
    return await response.fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
  } finally {
    client.close(force: true);
  }
}
