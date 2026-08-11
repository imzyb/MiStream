/// 起播编排的领域模型。
///
/// docs/04-播放器设计.md §7。
library;

/// 播放线路（flag）。
class PlaybackFlag {
  /// 构造线路。
  const PlaybackFlag({required this.name, this.priority = 0});

  /// 线路名，对应源返回的 `vod_play_from`。
  final String name;

  /// 优先级，数值越大越先尝试。
  final int priority;
}

/// 解析器规则。
class ParserRule {
  /// 构造解析器规则。
  const ParserRule({
    required this.name,
    required this.type,
    this.priority = 0,
    this.flags = const [],
  });

  /// 解析器名。
  final String name;

  /// 解析器类型，见 docs/05-Spider引擎.md 的 `parses` 四种 type。
  final int type;

  /// 优先级，运行期按成功率与耗时自适应调整。
  final int priority;

  /// 适用的线路名；为空表示不限。
  final List<String> flags;
}

/// 单个播放候选（一路 flag + 解析方式）。
class PlayCandidate {
  /// 构造候选。
  const PlayCandidate({
    required this.url,
    required this.flag,
    this.headers = const {},
    this.isDirect = true,
  });

  /// 待播地址。
  final String url;

  /// 请求头（UA/Referer 等，需透传给播放内核）。
  final Map<String, String> headers;

  /// 是否直链（`parse == 0`）；false 表示还需经解析器或嗅探。
  final bool isDirect;

  /// 所属线路名。
  final String flag;
}

/// 起播结果。
class PlayResult {
  /// 构造起播结果。
  const PlayResult({
    required this.url,
    required this.headers,
    required this.sourceName,
    required this.flag,
    required this.elapsed,
    this.parserName,
  });

  /// 最终可播地址。
  final String url;

  /// 随地址一起透传的请求头。
  final Map<String, String> headers;

  /// 来源站点名。
  final String sourceName;

  /// 命中的线路名。
  final String flag;

  /// 命中的解析器名；直链起播时为 null。
  final String? parserName;

  /// 从发起到成功的耗时，用于解析器自适应排序。
  final Duration elapsed;
}

/// 起播失败（结构化，供 UI 显示可读原因）。
class PlayFailure {
  /// 构造失败信息。
  const PlayFailure({
    required this.sourceName,
    required this.flag,
    required this.code,
    required this.message,
    this.parserName,
  });

  /// 来源站点名。
  final String sourceName;

  /// 失败发生在哪条线路。
  final String flag;

  /// 失败发生在哪个解析器；非解析阶段为 null。
  final String? parserName;

  /// 错误码，取自 `core_domain` 的 `ErrorCode`。
  final int code;

  /// 可读原因。UI 不应退化成笼统的「播放失败」。
  final String message;
}

/// spider.playerContent 的返回。
class PlayerContentResult {
  /// 构造返回。
  const PlayerContentResult({
    this.parse = 0,
    this.url = '',
    this.header = const {},
    this.jx = 0,
  });

  /// 0 = 直链，1 = 需解析。
  final int parse;

  /// 播放地址或待解析页面地址。
  final String url;

  /// 请求头。
  final Map<String, String> header;

  /// 是否允许走解析接口。
  final int jx;

  /// 是否为直链。
  bool get isDirect => parse == 0;
}

/// spider.playerContent 接口。
// 由 source_adapter 的 HttpSpiderPlayerApi 实现。
// ignore: one_member_abstracts — 依赖倒置接缝，测试要替换实现
abstract class SpiderPlayerApi {
  /// 取 [ids] 在线路 [flag] 上的播放信息。
  Future<PlayerContentResult> playerContent({
    required String flag,
    required String ids,
    List<String> vipFlags = const [],
  });
}

/// 解析器解析接口。
// ignore: one_member_abstracts — 同 SpiderPlayerApi，是可替换实现的接缝。
abstract class ParserResolver {
  /// 用 [rule] 解析 [url]，解析不出返回 null。
  Future<String?> resolve(ParserRule rule, String url);
}

/// 嗅探接口。
// ignore: one_member_abstracts — 同上；M6 落地 runtimes/sniffer 后由它实现。
abstract class SnifferLauncher {
  /// 嗅探 [url]，命中返回媒体地址，未命中返回 null。
  Future<String?> sniff(String url, Map<String, String> headers);
}

/// 实际播放执行接口（封装 PlayerEngine.open + 状态判定）。
// ignore: one_member_abstracts — 同上；把 PlayerEngine 挡在编排器之外。
abstract class PlayExecutor {
  /// 尝试播放 [candidate]，成功返回 null，失败返回错误信息。
  Future<String?> tryPlay(PlayCandidate candidate);
}
