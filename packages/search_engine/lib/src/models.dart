/// 聚合搜索的领域模型。
library;

/// 归一化后的搜索结果项（合并去重后的卡片）。
class SearchItem {
  final String title;
  final String? originalTitle;
  final String? year;
  final String? coverUrl;
  final String? remarks;
  final List<SearchSourceRef> sources;
  final int maxPriority;

  const SearchItem({
    required this.title,
    this.originalTitle,
    this.year,
    this.coverUrl,
    this.remarks,
    this.sources = const [],
    this.maxPriority = 0,
  });
}

/// 一条结果来自某个源的具体引用。
class SearchSourceRef {
  final int sourceId;
  final String sourceName;
  final String vodId;
  final int sourcePriority;

  const SearchSourceRef({
    required this.sourceId,
    required this.sourceName,
    required this.vodId,
    required this.sourcePriority,
  });
}

/// 单个源的搜索状态。
class SearchSourceStatus {
  final int sourceId;
  final String sourceName;
  final SearchStatus status;
  final String? error;
  final int resultCount;

  const SearchSourceStatus({
    required this.sourceId,
    required this.sourceName,
    this.status = SearchStatus.pending,
    this.error,
    this.resultCount = 0,
  });
}

/// 源搜索状态枚举。
enum SearchStatus { pending, running, complete, error }

/// 搜索进度（流式回灌给 UI）。
class SearchProgress {
  final String keyword;
  final List<SearchItem> items;
  final List<SearchSourceStatus> sourceStatuses;
  final bool isComplete;

  const SearchProgress({
    required this.keyword,
    this.items = const [],
    this.sourceStatuses = const [],
    this.isComplete = false,
  });
}

/// 可搜索的源信息。
class SearchableSource {
  final int id;
  final String name;
  final int priority;

  const SearchableSource({
    required this.id,
    required this.name,
    this.priority = 0,
  });
}

/// 提供可搜索源列表的接口。
abstract class SourceProvider {
  Future<List<SearchableSource>> getEnabledSites();
}

/// 执行单个源的搜索。
abstract class SpiderSearcher {
  Future<SpiderSearchResult> search(int sourceId, String keyword);
}

/// 单个源的搜索结果。
class SpiderSearchResult {
  final List<SpiderRawItem> items;
  final String? error;

  const SpiderSearchResult({this.items = const [], this.error});
}

/// 源返回的原始结果项。
class SpiderRawItem {
  final String vodId;
  final String vodName;
  final String? vodPic;
  final String? vodRemarks;
  final String? vodYear;

  const SpiderRawItem({
    required this.vodId,
    required this.vodName,
    this.vodPic,
    this.vodRemarks,
    this.vodYear,
  });
}
