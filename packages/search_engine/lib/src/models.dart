/// 聚合搜索的领域模型。
library;

/// 归一化后的搜索结果项（合并去重后的卡片）。
class SearchItem {
  /// 构造结果项。
  const SearchItem({
    required this.identityKey,
    required this.title,
    this.originalTitle,
    this.year,
    this.coverUrl,
    this.remarks,
    this.sources = const [],
    this.maxPriority = 0,
  });

  /// 这张卡片在结果列表中的**稳定身份**。
  ///
  /// 就是合并去重用的那个键（`SearchUseCase` 以 `normalizeTitle(vodName)` 为键），
  /// 所以同一批结果内**必然唯一**——可以直接当 `ValueKey` 用，不会撞 key。
  ///
  /// 为什么要把它显式带出来：搜索结果随各源陆续返回而**重排**（按源优先级排序，
  /// 新命中会插到前面）。列表若按**位置**匹配元素，同一格会被当成「换了一部片」，
  /// 封面重新走一遍加载与淡入，看起来就是整片网格反复闪。带上稳定身份，UI 才能
  /// 认出「还是那一部片」并把它挪到新位置。
  final String identityKey;

  /// 展示用标题（归一化后）。
  final String title;

  /// 源返回的原始标题，去重时用于比对。
  final String? originalTitle;

  /// 年份。
  final String? year;

  /// 封面地址。
  final String? coverUrl;

  /// 备注（如「更新至 12 集」）。
  final String? remarks;

  /// 这张卡片命中的全部源引用，按源优先级排序。
  final List<SearchSourceRef> sources;

  /// [sources] 中的最高优先级，用于结果整体排序。
  final int maxPriority;
}

/// 一条结果来自某个源的具体引用。
class SearchSourceRef {
  /// 构造源引用。
  const SearchSourceRef({
    required this.sourceId,
    required this.sourceName,
    required this.vodId,
    required this.sourcePriority,
  });

  /// 站点 ID。
  final int sourceId;

  /// 站点名。
  final String sourceName;

  /// 该源下的影片 ID。
  final String vodId;

  /// 该源的优先级。
  final int sourcePriority;
}

/// 单个源的搜索状态。
class SearchSourceStatus {
  /// 构造源状态。
  const SearchSourceStatus({
    required this.sourceId,
    required this.sourceName,
    this.status = SearchStatus.pending,
    this.error,
    this.resultCount = 0,
  });

  /// 站点 ID。
  final int sourceId;

  /// 站点名。
  final String sourceName;

  /// 当前状态。
  final SearchStatus status;

  /// 失败原因，仅 [SearchStatus.error] 时非空。
  final String? error;

  /// 该源返回的结果条数。
  final int resultCount;
}

/// 源搜索状态枚举。
enum SearchStatus {
  /// 已排队，尚未开始。
  pending,

  /// 正在搜索。
  running,

  /// 已完成。
  complete,

  /// 已失败（超时、崩溃或返回非法）。
  error,
}

/// 搜索进度（流式回灌给 UI）。
class SearchProgress {
  /// 构造进度快照。
  const SearchProgress({
    required this.keyword,
    this.items = const [],
    this.sourceStatuses = const [],
    this.isComplete = false,
  });

  /// 本次搜索的关键词。
  final String keyword;

  /// 截至此刻已合并去重的结果。
  final List<SearchItem> items;

  /// 各源的状态，失败源在这里单独可见而不阻塞整体。
  final List<SearchSourceStatus> sourceStatuses;

  /// 是否全部源都已结束（成功或失败）。
  final bool isComplete;
}

/// 可搜索的源信息。
class SearchableSource {
  /// 构造源信息。
  const SearchableSource({
    required this.id,
    required this.name,
    this.priority = 0,
  });

  /// 站点 ID。
  final int id;

  /// 站点名。
  final String name;

  /// 优先级，数值越大越靠前。
  final int priority;
}

/// 提供可搜索源列表的接口。
// 由 source_adapter 的 StorageSourceProvider 实现。
// ignore: one_member_abstracts — 依赖倒置接缝，测试要替换假数据源
abstract class SourceProvider {
  /// 取「已启用且可搜索」的站点。
  Future<List<SearchableSource>> getEnabledSites();
}

/// 执行单个源的搜索。
// ignore: one_member_abstracts — 同上；HttpSpiderSearcher 与测试桩都实现它。
abstract class SpiderSearcher {
  /// 在 [sourceId] 上搜索 [keyword]。失败以结果对象表达，不抛异常。
  Future<SpiderSearchResult> search(int sourceId, String keyword);
}

/// 单个源的搜索结果。
class SpiderSearchResult {
  /// 构造单源结果。
  const SpiderSearchResult({this.items = const [], this.error});

  /// 该源返回的结果项。
  final List<SpiderRawItem> items;

  /// 失败原因，成功时为 null。
  final String? error;
}

/// 源返回的原始结果项。
class SpiderRawItem {
  /// 构造原始结果项。
  const SpiderRawItem({
    required this.vodId,
    required this.vodName,
    this.vodPic,
    this.vodRemarks,
    this.vodYear,
  });

  /// 影片 ID。
  final String vodId;

  /// 影片名。
  final String vodName;

  /// 封面地址。
  final String? vodPic;

  /// 备注。
  final String? vodRemarks;

  /// 年份。
  final String? vodYear;
}
