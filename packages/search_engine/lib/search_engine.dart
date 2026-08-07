/// 聚合搜索编排：多源并发、流式结果、去重合并、失败折叠。
library;

export 'src/models.dart';
export 'src/search_use_case.dart'
    show
        SearchUseCase,
        normalizeTitle,
        kGlobalConcurrency,
        kSourceTimeout,
        kMaxResultsPerSource;
