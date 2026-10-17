/// 更新 feed（`latest.json`）的模型与解析。
///
/// feed 由发布流水线生成（`tools/gen_update_feed.dart`），应用只读。
/// 形状：
///
/// ```json
/// {
///   "channel": "stable",
///   "version": "0.2.0",
///   "releasedAt": "2026-10-17T12:00:00Z",
///   "notes": "修了什么",
///   "minimumVersion": "0.1.0",
///   "assets": {
///     "windows-x64-portable": {
///       "url": "https://…/mistream-v0.2.0-windows-x64.zip",
///       "sha256": "…",
///       "size": 123456789
///     }
///   }
/// }
/// ```
///
/// 也接受**多渠道路由**的形状 —— 一个文件里带 stable/beta 两份：
///
/// ```json
/// {"channels": {"stable": {…上面的对象…}, "beta": {…}}}
/// ```
///
/// 为什么两种都收：单文件双渠道省一次请求、也不用记两个 URL；但单渠道单文件
/// 更简单，发布脚本两种都能生成。解析层宽容，**语义层不宽容** —— 见 [parse]。
library;

import 'dart:convert';

import 'package:updater/src/update_version.dart';

/// 发布渠道。
enum UpdateChannel {
  /// 稳定版：默认。
  stable,

  /// 测试版：只给在设置里主动切过去的人。
  beta;

  /// 从字符串解析；不认识的一律回落到 [stable]。
  ///
  /// 这里**故意**宽容：上游多写一个渠道名不该让整个更新检查失败，
  /// 最坏结果只是「按稳定版处理」。
  static UpdateChannel parse(String? raw) {
    final text = (raw ?? '').trim().toLowerCase();
    return text == 'beta' ? UpdateChannel.beta : UpdateChannel.stable;
  }

  /// feed 里的字面量。
  String get wireName => name;
}

/// 便携包在 feed 里的资产键。
///
/// 为什么带平台后缀：将来 M13 要出 macOS/Linux 包，键名必须能区分，
/// 否则同一个 feed 会让 mac 去下 Windows 的 zip。
const String portableAssetKey = 'windows-x64-portable';

/// 一个可下载的发布产物。
final class UpdateAsset {
  /// 构造。
  const UpdateAsset({
    required this.url,
    this.sha256,
    this.size,
    this.fileName = '',
  });

  /// 从 JSON 解析；形状不对时抛 [FormatException]。
  factory UpdateAsset.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('asset 不是对象');
    }
    final url = (json['url'] as Object?)?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw const FormatException('asset 缺 url');
    }
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      // 只允许 http(s)：更新包来自网络，`file://` / 相对路径会让「从哪来」
      // 变得不可控。
      throw FormatException('asset 的 url 不是 http(s): $url');
    }
    final sizeRaw = json['size'];
    final size = sizeRaw is num
        ? sizeRaw.toInt()
        : int.tryParse((sizeRaw ?? '').toString());
    if (size != null && size <= 0) {
      throw FormatException('asset 的 size 不合法: $sizeRaw');
    }
    final sha = (json['sha256'] as Object?)?.toString().trim().toLowerCase();
    if (sha != null &&
        sha.isNotEmpty &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw FormatException('asset 的 sha256 不是 64 位十六进制: $sha');
    }
    return UpdateAsset(
      url: url,
      sha256: (sha == null || sha.isEmpty) ? null : sha,
      size: size,
      fileName: (json['fileName'] as Object?)?.toString() ?? '',
    );
  }

  /// 下载地址（必须 http/https）。
  final String url;

  /// 期望的 sha256（小写十六进制）；`null` 表示 feed 没给。
  ///
  /// 没给就**不校验**，但要记一笔 —— 完整性靠 TLS。给了就必须对，
  /// 因为「下到半个文件」比「没有更新」更糟。
  final String? sha256;

  /// 期望的字节数；`null` 表示没给。
  final int? size;

  /// 落盘文件名（feed 可显式给，否则从 URL 末段推）。
  final String fileName;

  /// 解析出来的文件名。
  String get resolvedFileName {
    if (fileName.isNotEmpty) return fileName;
    final uri = Uri.tryParse(url);
    final last = uri == null || uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.last;
    return last.isEmpty ? 'mistream-update.zip' : last;
  }
}

/// 一份发布清单。
final class UpdateManifest {
  /// 构造。
  const UpdateManifest({
    required this.version,
    required this.channel,
    required this.assets,
    this.releasedAt,
    this.notes = '',
    this.minimumVersion,
  });

  /// 解析 feed 正文。
  ///
  /// [channel] 用于多渠道路由；单渠道文件里若自带 `channel` 字段，以**文件
  /// 里的为准**（发布脚本更清楚这份文件属于谁）。
  factory UpdateManifest.fromFeed(
    String body, {
    UpdateChannel channel = UpdateChannel.stable,
  }) {
    Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException catch (e) {
      throw FormatException('feed 不是合法 JSON: ${e.message}');
    }
    return UpdateManifest._fromJson(json, channel);
  }

  /// 从已解码的 JSON 建清单。
  ///
  /// 拆成两步是因为「解 JSON」与「校验形状」的失败语义不同：前者是
  /// `FormatException`（字节不是 JSON），后者是「是 JSON 但不是 feed」。
  /// 两者都要让调用方看到**不同的**中文说明，否则用户只会看到「格式不对」。
  factory UpdateManifest._fromJson(Object? json, UpdateChannel channel) {
    if (json is! Map) {
      throw const FormatException('feed 顶层不是对象');
    }
    var payload = json;
    final channels = json['channels'];
    if (channels is Map) {
      final wanted =
          channels[channel.wireName] ?? channels[UpdateChannel.stable.wireName];
      if (wanted is! Map) {
        throw FormatException('feed 里没有渠道 ${channel.wireName}');
      }
      payload = wanted;
    }

    final versionRaw = (payload['version'] as Object?)?.toString().trim() ?? '';
    if (versionRaw.isEmpty) {
      throw const FormatException('feed 缺 version');
    }
    final version = AppVersion.parse(versionRaw);

    final assetsJson = payload['assets'];
    if (assetsJson is! Map || assetsJson.isEmpty) {
      throw const FormatException('feed 缺 assets');
    }
    final assets = <String, UpdateAsset>{};
    for (final entry in assetsJson.entries) {
      assets[entry.key.toString()] = UpdateAsset.fromJson(entry.value);
    }

    final minRaw = (payload['minimumVersion'] as Object?)?.toString().trim();
    final releasedRaw = (payload['releasedAt'] as Object?)?.toString().trim();

    return UpdateManifest(
      version: version,
      // 文件里写了就以文件为准；没写才用调用方要的渠道。
      channel: payload.containsKey('channel')
          ? UpdateChannel.parse((payload['channel'] as Object?)?.toString())
          : channel,
      assets: assets,
      releasedAt: releasedRaw == null || releasedRaw.isEmpty
          ? null
          : DateTime.tryParse(releasedRaw)?.toUtc(),
      notes: (payload['notes'] as Object?)?.toString() ?? '',
      minimumVersion: (minRaw == null || minRaw.isEmpty)
          ? null
          : AppVersion.tryParse(minRaw),
    );
  }

  /// 这份清单对应的版本。
  final AppVersion version;

  /// 渠道。
  final UpdateChannel channel;

  /// 平台键 → 资产。
  final Map<String, UpdateAsset> assets;

  /// 发布时间（feed 没给就是 `null`）。
  final DateTime? releasedAt;

  /// 更新说明（纯文本，UI 自己决定怎么排）。
  final String notes;

  /// 低于这个版本必须更新（协议/数据不兼容时用）。
  ///
  /// 与「有新版本」是两件事：`minimumVersion` 是**强制**语义，UI 要拦住不让
  /// 用户继续用旧版；普通的新版本只是提示。
  final AppVersion? minimumVersion;

  /// 取某个平台键的资产；没有则 `null`。
  UpdateAsset? assetFor(String key) => assets[key];

  /// 取便携包资产。
  UpdateAsset? get portable => assets[portableAssetKey];

  /// 解析失败返回 `null`。
  static UpdateManifest? tryParse(
    String body, {
    UpdateChannel channel = UpdateChannel.stable,
  }) {
    try {
      return UpdateManifest.fromFeed(body, channel: channel);
    } on FormatException {
      return null;
    }
  }
}
