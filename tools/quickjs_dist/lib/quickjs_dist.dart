/// QuickJS 运行时 DLL 的 vendored 分发与校验。
///
/// spider_js 的引擎目录（`lib/src/engine/`）三个 DLL 被 `.gitignore` 排除，
/// CI 上因此没有它们，导致 Release 包链（`spider-js:bundle`）失败。三份 DLL
/// 的来源各不相同：
///
/// - `libquickjs.dll`：仓库本地 MinGW 定制构建，JSObject 内存布局非 mainline，
///   无法从公开 URL 复现（见 `runtimes/spider_js/README.md`）
/// - `quickjs_wrapper.dll`：由 `native/build.bat`（MSVC）从仓库源码产出
/// - `quickjs.dll`：`libquickjs.dll` 的别名副本
///
/// 因此采用「vendor + 锁哈希」而不是下载：三份 DLL 随包提交在
/// `tools/quickjs_dist/vendor/`，本工具负责按清单校验并拷贝到引擎目录。
/// 任何漂移（误替换、压缩损坏、wrapper 重编未同步清单）都在拷贝后被拒绝。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// 一个可见的校验失败。
final class QuickjsDistException implements Exception {
  /// 构造失败。
  const QuickjsDistException(this.message);

  /// 说明。
  final String message;

  @override
  String toString() => 'QuickjsDistException: $message';
}

/// 锁定的 DLL 清单（[assets/quickjs.manifest.json] 的结构）。
@immutable
final class QuickjsManifest {
  /// 构造清单。
  const QuickjsManifest({
    required this.version,
    required this.platform,
    required this.files,
  });

  /// 从 JSON 字符串解析。
  factory QuickjsManifest.fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const QuickjsDistException('清单必须是 JSON 对象');
    }

    final version = decoded['version'];
    final platform = decoded['platform'];
    final filesJson = decoded['files'];
    if (version is! String || version.isEmpty) {
      throw const QuickjsDistException('清单缺少字符串字段「version」');
    }
    if (platform is! String || platform.isEmpty) {
      throw const QuickjsDistException('清单缺少字符串字段「platform」');
    }
    if (filesJson is! Map) {
      throw const QuickjsDistException('清单缺少「files」对象');
    }

    final files = <String, String>{};
    for (final entry in filesJson.entries) {
      final name = entry.key.toString();
      final meta = entry.value;
      if (meta is! Map) {
        throw QuickjsDistException('「$name」缺少元数据对象');
      }
      final sha = meta['sha256'];
      if (sha is! String || !_isSha256(sha)) {
        throw QuickjsDistException('「$name」的 sha256 缺失或非法：$sha');
      }
      files[name] = sha.toLowerCase();
    }

    if (files.isEmpty) {
      throw const QuickjsDistException('files 不能为空');
    }

    return QuickjsManifest(
      version: version,
      platform: platform,
      files: Map.unmodifiable(files),
    );
  }

  /// 快照日期。
  final String version;

  /// 目标平台，如 `windows-x64`。
  final String platform;

  /// 文件名 → 小写 SHA256。
  final Map<String, String> files;

  static bool _isSha256(String value) =>
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value);
}

/// 分发器的依赖（便于测试注入）。
final class QuickjsDistribution {
  /// 构造分发器。
  QuickjsDistribution({
    required this.manifest,
    Future<String> Function(File file)? computeSha256,
  }) : computeSha256 = computeSha256 ?? sha256Of;

  /// 清单。
  final QuickjsManifest manifest;

  /// SHA256 计算函数，默认 [sha256Of]。
  final Future<String> Function(File file) computeSha256;

  /// 把清单里的全部 DLL 装进 [dest]。
  ///
  /// 幂等：已存在且哈希匹配的直接复用。来源是 [vendorDir] 下同名文件，
  /// 拷贝后再校验一次，任何哈希不符都抛错并**不落盘**（先校验临时文件）。
  Future<void> install(Directory vendorDir, Directory dest) async {
    await dest.create(recursive: true);
    for (final entry in manifest.files.entries) {
      final name = entry.key;
      final expected = entry.value;

      final existing = File('${dest.path}${Platform.pathSeparator}$name');
      if (existing.existsSync() &&
          (await computeSha256(existing)).toLowerCase() == expected) {
        continue;
      }

      final source = File('${vendorDir.path}${Platform.pathSeparator}$name');
      if (!source.existsSync()) {
        throw QuickjsDistException(
          'vendor 缺少 $name（$source）。若重编过 wrapper 或换过'
          ' libquickjs，请同步更新 tools/quickjs_dist/vendor/ 与'
          ' quickjs.manifest.json',
        );
      }
      final sourceHash = (await computeSha256(source)).toLowerCase();
      if (sourceHash != expected) {
        throw QuickjsDistException(
          'vendor 中 $name 的 SHA256 与清单不符：\n'
          '  期望 $expected\n'
          '  实际 $sourceHash\n'
          '请重新执行 copy 并更新清单',
        );
      }

      // 先落临时文件并校验，通过后才覆盖正式位置，避免半截拷贝污染。
      final tmp = File(
        '${dest.path}${Platform.pathSeparator}.$name.tmp',
      );
      await source.copy(tmp.path);
      final tmpHash = (await computeSha256(tmp)).toLowerCase();
      if (tmpHash != expected) {
        await tmp.delete();
        throw QuickjsDistException('$name 拷贝后校验失败，已丢弃临时文件');
      }
      await tmp.rename(existing.path);
    }
  }

  /// 校验 [dest] 里的全部 DLL 与清单一致。返回缺失/不符的文件名。
  Future<List<String>> verify(Directory dest) async {
    final problems = <String>[];
    for (final entry in manifest.files.entries) {
      final name = entry.key;
      final expected = entry.value;
      final file = File('${dest.path}${Platform.pathSeparator}$name');
      if (!file.existsSync()) {
        problems.add('$name（缺失）');
        continue;
      }
      if ((await computeSha256(file)).toLowerCase() != expected) {
        problems.add('$name（哈希不符）');
      }
    }
    return problems;
  }
}

/// 计算文件的 SHA256（十六进制小写）。
Future<String> sha256Of(File file) async {
  final bytes = sha256.bind(file.openRead());
  final digest = await bytes.first;
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
