/// TVBox 配置的领域模型（解码后/解析后的中间表示）。
library;

/// TVBox 配置根对象。
class TvBoxConfig {
  /// 全局 Spider jar 地址。
  final String? spider;

  /// Spider jar 的 MD5。
  final String? spiderMd5;

  /// 站点列表。
  final List<SiteConfig> sites;

  /// 直播订阅。
  final List<LiveConfig> lives;

  /// 解析器列表。
  final List<ParseConfig> parses;

  /// 嗅探规则。
  final List<SniffRuleConfig> rules;

  /// 替换标志（站点级）。
  final List<String> flags;

  /// 壁纸 URL。
  final String? wallpaper;

  /// DoH 提供者列表。
  final List<String> doh;

  /// 构造 TVBox 配置。
  const TvBoxConfig({
    this.spider,
    this.spiderMd5,
    this.sites = const [],
    this.lives = const [],
    this.parses = const [],
    this.rules = const [],
    this.flags = const [],
    this.wallpaper,
    this.doh = const [],
  });
}

/// 单个站点配置。
class SiteConfig {
  final String key;
  final String name;
  final int type;
  final String api;
  final String? ext;
  final bool searchable;
  final bool quickSearch;
  final bool filterable;
  final int priority;

  const SiteConfig({
    required this.key,
    required this.name,
    required this.type,
    required this.api,
    this.ext,
    this.searchable = true,
    this.quickSearch = false,
    this.filterable = false,
    this.priority = 0,
  });
}

/// 直播配置。
class LiveConfig {
  final String? name;
  final String? url;
  final String? type;

  const LiveConfig({this.name, this.url, this.type});
}

/// 解析器配置。
class ParseConfig {
  final String name;
  final int type;
  final String url;
  final String? ext;
  final List<String> flags;

  const ParseConfig({
    required this.name,
    required this.type,
    required this.url,
    this.ext,
    this.flags = const [],
  });
}

/// 嗅探规则配置。
class SniffRuleConfig {
  final String host;
  final String? regex;

  const SniffRuleConfig({required this.host, this.regex});
}
