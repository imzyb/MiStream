import 'package:live/src/live_parser.dart';
import 'package:live/src/live_repository.dart';
import 'package:live/src/live_subscription.dart';

/// 拉取直播源文本的传输层。
///
/// **必须可注入**：真实网络在测试里不可控，本项目的沙箱还禁止本地回环，
/// 「拉取」这一步要是焊死在实现里，整条导入链路就永远只有人工点一遍才能验证
/// —— 这正是项目里 sniffer / spider_js 踩过的坑。
typedef LiveContentFetcher =
    Future<String> Function(
      String url, {
      String? userAgent,
    });

/// 导入过程中的可读错误。
class LiveImportError implements Exception {
  /// 构造错误。
  const LiveImportError(this.message);

  /// 错误说明。
  final String message;

  @override
  String toString() => message;
}

/// 单个订阅源的导入结果。
class LiveImportOutcome {
  /// 构造结果。
  const LiveImportOutcome({
    required this.subscription,
    required this.url,
    this.channelCount = 0,
    this.groupCount = 0,
    this.error,
    this.stackTrace,
  });

  /// 原始订阅。
  final LiveSubscription subscription;

  /// 实际请求的地址（相对路径已按配置 URL 解析）。
  final String url;

  /// 解析出的频道数。
  final int channelCount;

  /// 解析出的分组数。
  final int groupCount;

  /// 失败原因；`null` 表示成功。
  final Object? error;

  /// 失败堆栈。
  final StackTrace? stackTrace;

  /// 是否成功。
  bool get isOk => error == null;
}

/// 一批订阅的导入报告。
class LiveImportReport {
  /// 构造报告。
  const LiveImportReport({
    required this.outcomes,
    required this.result,
    required this.written,
  });

  /// 每个订阅源的结果，顺序与输入一致。
  final List<LiveImportOutcome> outcomes;

  /// 合并后的解析结果（只含成功源）。
  final LiveParseResult result;

  /// 是否真的写进了仓库。
  final bool written;

  /// 成功导入的源数。
  int get okCount => outcomes.where((o) => o.isOk).length;

  /// 失败的源数。
  int get failedCount => outcomes.length - okCount;

  /// 是否有源失败。
  bool get hasFailure => failedCount > 0;

  /// 是否**一个都没成功**（且确实有源要导）。
  bool get allFailed => outcomes.isNotEmpty && okCount == 0;

  /// 合并后的频道数。
  int get channelCount => result.channels.length;

  /// 合并后的分组数。
  int get groupCount => result.groups.length;
}

/// 订阅导入编排：拉取 → 解析 → 合并 → 落库。
///
/// 真实 TVBox 配置的 `lives` 是一**组**源，挂掉几个是常态（源站跑路、
/// 域名换掉、只有特定网络能连）。所以这里的核心约定是：
///
/// - **单个源失败不中断整批** —— 否则一个死源会让能用的源一起消失；
/// - **全军覆没时不写库** —— 否则一次网络抖动就会把用户已有的频道列表清空，
///   而且失败信息只是「导入完成，0 个频道」，根本指不到原因。
class LiveImporter {
  /// 构造导入器。
  ///
  /// [fetcher] 是传输层，[repository] 是落库目标，[parser] 默认
  /// [LiveParser]（格式按内容嗅探，不看配置里的 `type`）。
  LiveImporter({
    required LiveRepository repository,
    required LiveContentFetcher fetcher,
    LiveParser? parser,
  }) : _repository = repository,
       _fetcher = fetcher,
       _parser = parser ?? LiveParser();

  final LiveRepository _repository;
  final LiveContentFetcher _fetcher;
  final LiveParser _parser;

  /// 导入 [subscriptions]。
  ///
  /// [baseUrl] 是配置自身的 URL，用于解析订阅里的相对地址。
  /// [replace] 为真（默认）时，成功导入后**整体替换**仓库内容。
  ///
  /// 源之间是**串行**拉取的。并发能快一些，但配置里通常十几个源，串行已经
  /// 够用，而且顺序可预测、对源站也客气 —— 不值得为此引入并发控制。
  Future<LiveImportReport> import(
    List<LiveSubscription> subscriptions, {
    String? baseUrl,
    bool replace = true,
  }) async {
    final outcomes = <LiveImportOutcome>[];
    final parsed = <LiveParseResult>[];

    for (final subscription in subscriptions) {
      if (subscription.url.trim().isEmpty) {
        outcomes.add(
          LiveImportOutcome(
            subscription: subscription,
            url: '',
            error: const LiveImportError('订阅地址为空'),
          ),
        );
        continue;
      }

      final url = resolveLiveUrl(subscription.url, baseUrl: baseUrl);
      try {
        final content = await _fetcher(url, userAgent: subscription.userAgent);
        final result = _withLogoTemplate(
          _parser.parse(content),
          subscription,
        );
        outcomes.add(
          LiveImportOutcome(
            subscription: subscription,
            url: url,
            channelCount: result.channels.length,
            groupCount: result.groups.length,
          ),
        );
        parsed.add(result);
      } on Object catch (error, stackTrace) {
        outcomes.add(
          LiveImportOutcome(
            subscription: subscription,
            url: url,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }

    final merged = LiveParseResult.merge(parsed);
    // 全军覆没时不落库：让旧列表原样留着，比清空后显示「暂无直播源」有用得多。
    final written = replace && parsed.isNotEmpty;
    if (written) {
      await _repository.replaceAll(merged);
    }

    return LiveImportReport(
      outcomes: outcomes,
      result: merged,
      written: written,
    );
  }

  /// 用订阅的 `logo` 模板给**没有图标**的频道补图标。
  ///
  /// 真实配置里 `lives[].logo` 是含 `{name}` 的**模板**
  /// （如 `https://live.fanmingming.com/tv/{name}.png`），不是图标地址 ——
  /// 直接拿去请求会拿到一个 404 的模板串。
  ///
  /// 自带 `tvg-logo` 的频道（m3u 常见）不覆盖：那是源站给的具体图标，比按
  /// 名字猜的准。
  static LiveParseResult _withLogoTemplate(
    LiveParseResult result,
    LiveSubscription subscription,
  ) {
    if ((subscription.logoTemplate ?? '').trim().isEmpty) return result;
    return LiveParseResult(
      groups: result.groups,
      channels: [
        for (final channel in result.channels)
          if ((channel.logo ?? '').isNotEmpty)
            channel
          else
            channel.copyWith(logo: subscription.logoFor(channel.name)),
      ],
    );
  }
}
