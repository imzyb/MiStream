/// 聚合搜索编排：多源并发、流式结果、去重合并、失败折叠。
library;

export 'src/home_use_case.dart'
    show
        CategoryDetailResult,
        CategoryItem,
        HomeData,
        HomeItem,
        HomeUseCase,
        SourceOption;
export 'src/models.dart';
export 'src/play_use_case.dart' show PlayResult, PlayUseCase;
export 'src/recommendation_engine.dart';
export 'src/search_use_case.dart'
    show
        SearchUseCase,
        kGlobalConcurrency,
        kMaxResultsPerSource,
        kSourceTimeout,
        normalizeTitle;
