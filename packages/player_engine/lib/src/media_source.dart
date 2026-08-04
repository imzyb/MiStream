/// 待播放的媒体及其网络上下文。
library;

import 'package:meta/meta.dart';

/// DRM 信息的保留位。
///
/// `docs/04-播放器设计.md` §3 把它写成「保留字段，当前恒为 null」。这里刻意
/// 让它**无法从包外构造**——没有公开构造函数，因此 `drm` 参数只能传 `null`。
/// 合规边界（`docs/01-项目概述.md` §6）写明本项目不提供 DRM 解除能力，把这
/// 件事做成类型层面的限制，比在字段注释里写一句「请勿使用」可靠。
@immutable
final class DrmInfo {
  const DrmInfo._();
}

/// 一个待播放的媒体源。
///
/// [headers] 的透传是硬需求而不是可选项：大量源站按 `Referer` 或 `User-Agent`
/// 判断盗链，`docs/04-播放器设计.md` §6 明确要求把 `playerContent` 返回的这些
/// 头原样下发。
@immutable
final class MediaSource {
  /// 构造一个媒体源。
  const MediaSource({
    required this.uri,
    this.headers = const {},
    this.externalSubtitles = const [],
    this.title,
    this.drm,
    this.isLive = false,
  });

  /// 媒体地址。
  final Uri uri;

  /// 随请求下发的 HTTP 头，如 `User-Agent` / `Referer` / `Cookie` / `Origin`。
  final Map<String, String> headers;

  /// 起播时一并加载的外挂字幕。
  final List<Uri> externalSubtitles;

  /// 显示用标题。
  final String? title;

  /// DRM 信息。恒为 `null`，见 [DrmInfo]。
  final DrmInfo? drm;

  /// 是否是直播流。
  ///
  /// 影响缓冲策略：`docs/04-播放器设计.md` §6 要求点播缓冲 64MB、直播 16MB
  /// （低延迟优先）。这个判断没法可靠地从 URL 猜出来，必须由上层告知。
  final bool isLive;

  /// `User-Agent` 头。
  ///
  /// 单独取出来是因为 mpv 有专门的 `user-agent` 选项，而它与
  /// `http-header-fields` 里的同名项行为不完全一致——同时写两处会让实际发出
  /// 去的值取决于 mpv 的内部顺序。三个取值器把这件事一次性说清楚。
  String? get userAgent => _headerValue('user-agent');

  /// `Referer` 头，对应 mpv 的 `referrer` 选项。
  ///
  /// 注意两边拼写不同：HTTP 头历史遗留地少一个 r，mpv 的选项名是正确拼写。
  String? get referrer => _headerValue('referer');

  /// 除 `User-Agent` 与 `Referer` 之外的头。
  ///
  /// 这些交给 mpv 的 `http-header-fields`。
  Map<String, String> get otherHeaders => {
    for (final entry in headers.entries)
      if (!_isSpecialHeader(entry.key)) entry.key: entry.value,
  };

  String? _headerValue(String lowercaseName) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowercaseName) return entry.value;
    }
    return null;
  }

  static bool _isSpecialHeader(String name) {
    final lower = name.toLowerCase();
    return lower == 'user-agent' || lower == 'referer';
  }

  @override
  String toString() => 'MediaSource($uri)';
}
