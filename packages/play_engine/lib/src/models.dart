/// 起播编排的领域模型。
///
/// docs/04-播放器设计.md §7。
library;

/// 播放线路（flag）。
class PlaybackFlag {
  final String name;
  final int priority;

  const PlaybackFlag({required this.name, this.priority = 0});
}

/// 解析器规则。
class ParserRule {
  final String name;
  final int type;
  final int priority;
  final List<String> flags;

  const ParserRule({
    required this.name,
    required this.type,
    this.priority = 0,
    this.flags = const [],
  });
}

/// 单个播放候选（一路 flag + 解析方式）。
class PlayCandidate {
  final String url;
  final Map<String, String> headers;
  final bool isDirect; // parse==0 直链；false 需解析
  final String flag;

  const PlayCandidate({
    required this.url,
    required this.flag,
    this.headers = const {},
    this.isDirect = true,
  });
}

/// 起播结果。
class PlayResult {
  final String url;
  final Map<String, String> headers;
  final String sourceName;
  final String flag;
  final String? parserName;
  final Duration elapsed;

  const PlayResult({
    required this.url,
    required this.headers,
    required this.sourceName,
    required this.flag,
    this.parserName,
    required this.elapsed,
  });
}

/// 起播失败（结构化，供 UI 显示可读原因）。
class PlayFailure {
  final String sourceName;
  final String flag;
  final String? parserName;
  final int code;
  final String message;

  const PlayFailure({
    required this.sourceName,
    required this.flag,
    this.parserName,
    required this.code,
    required this.message,
  });
}

/// spider.playerContent 的返回。
class PlayerContentResult {
  final int parse; // 0=直链 1=需解析
  final String url;
  final Map<String, String> header;
  final int jx; // 是否允许走解析接口

  const PlayerContentResult({
    this.parse = 0,
    this.url = '',
    this.header = const {},
    this.jx = 0,
  });

  bool get isDirect => parse == 0;
}

/// spider.playerContent 接口。
abstract class SpiderPlayerApi {
  Future<PlayerContentResult> playerContent({
    required String flag,
    required String ids,
    List<String> vipFlags = const [],
  });
}

/// 解析器解析接口。
abstract class ParserResolver {
  Future<String?> resolve(ParserRule rule, String url);
}

/// 嗅探接口。
abstract class SnifferLauncher {
  Future<String?> sniff(String url, Map<String, String> headers);
}

/// 实际播放执行接口（封装 PlayerEngine.open + 状态判定）。
abstract class PlayExecutor {
  /// 尝试播放 [candidate]，成功返回 null，失败返回错误信息。
  Future<String?> tryPlay(PlayCandidate candidate);
}
