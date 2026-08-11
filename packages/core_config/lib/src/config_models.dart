/// TVBox 配置的领域模型（解码后/解析后的中间表示）。
library;

/// TVBox 配置根对象。
class TvBoxConfig {
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
}

/// 单个站点配置。
class SiteConfig {
  /// 构造站点配置。
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

  /// 站点唯一键，配置内不重复。
  final String key;

  /// 站点显示名。
  final String name;

  /// 站点类型：0 = 网页解析，1 = JSON API，3 = Spider 脚本。
  final int type;

  /// 接口地址或脚本地址。
  final String api;

  /// 扩展参数，含义由站点类型决定。
  final String? ext;

  /// 是否参与聚合搜索。
  final bool searchable;

  /// 是否支持快速搜索。
  final bool quickSearch;

  /// 是否支持筛选。
  final bool filterable;

  /// 优先级，数值越大越靠前。
  final int priority;
}

/// 直播配置。
class LiveConfig {
  /// 构造直播配置。
  const LiveConfig({this.name, this.url, this.type});

  /// 订阅名。
  final String? name;

  /// 订阅地址。
  final String? url;

  /// 订阅格式（m3u / txt）。
  final String? type;
}

/// 解析器配置。
class ParseConfig {
  /// 构造解析器配置。
  const ParseConfig({
    required this.name,
    required this.type,
    required this.url,
    this.ext,
    this.flags = const [],
  });

  /// 解析器名。
  final String name;

  /// 解析器类型，见 docs/05-Spider引擎.md 的四种 type。
  final int type;

  /// 解析接口地址。
  final String url;

  /// 扩展参数。
  final String? ext;

  /// 适用的线路名；为空表示不限。
  final List<String> flags;
}

/// 嗅探规则配置。
class SniffRuleConfig {
  /// 构造嗅探规则。
  const SniffRuleConfig({required this.host, this.regex});

  /// 命中的主机名。
  final String host;

  /// 命中的地址正则；为空表示只按主机名匹配。
  final String? regex;
}
