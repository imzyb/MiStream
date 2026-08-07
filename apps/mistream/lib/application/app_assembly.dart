/// 应用层装配 —— 组合所有基础设施与 UseCase。
///
/// 当 Flutter 就绪时，UI 从此处获取已装配好的实例。
/// 这是整个应用的唯一「组合根」。
library;

import 'package:search_engine/search_engine.dart';
import 'package:source_adapter/source_adapter.dart';
import 'package:storage/src/database/database.dart';
import 'package:storage/src/repository/repositories.dart';

/// 应用层装配。
class AppAssembly {
  final AppDatabase database;
  final Repositories repositories;

  // UseCase
  late final SearchUseCase searchUseCase;

  bool _initialized = false;

  /// 构造并初始化。
  AppAssembly(this.database, this.repositories) {
    _wire();
  }

  void _wire() {
    if (_initialized) return;

    // 搜索
    final sourceProvider = StorageSourceProvider(repositories.sites);
    // 搜索用 HttpRuntime 需要 baseUrl，这里用占位，实际由 UI 按源配置传入
    searchUseCase = SearchUseCase(
      sourceProvider: sourceProvider,
      spiderSearcher: _DummySearcher(),
    );

    _initialized = true;
  }
}

/// 占位搜索器（实际由 UI 按源类型选择 HttpRuntime 或 QuickJS）。
class _DummySearcher implements SpiderSearcher {
  @override
  Future<SpiderSearchResult> search(int sourceId, String keyword) async {
    return const SpiderSearchResult(error: '搜索器未配置');
  }
}
