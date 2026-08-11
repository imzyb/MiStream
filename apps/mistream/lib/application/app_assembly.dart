/// 应用层装配 -- 组合所有基础设施与 UseCase。
///
/// 这是整个应用的**唯一**组合根：数据库只在 `main.dart` 建一次并交到这里，
/// UI 一律经 `AppScope` 取用，不再自行建库。
library;

import 'package:mistream/application/config_install_service.dart';
import 'package:mistream/application/detail_use_case.dart';
import 'package:search_engine/search_engine.dart';
import 'package:source_adapter/source_adapter.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';

/// 应用层装配。
class AppAssembly {
  /// 构造并装配。
  AppAssembly(this.database, this.repositories) {
    sourceProvider = StorageSourceProvider(repositories.sites);
    searchUseCase = SearchUseCase(
      sourceProvider: sourceProvider,
      spiderSearcher: _LazySearcher(repositories.sites),
    );
    detailUseCase = DetailUseCase(repositories.sites);
    configInstaller = ConfigInstallService(repositories);
  }

  /// 底层数据库。
  final AppDatabase database;

  /// 仓储集合。
  final Repositories repositories;

  /// 聚合搜索用例。
  late final SearchUseCase searchUseCase;

  /// 影片详情用例。
  late final DetailUseCase detailUseCase;

  /// 配置导入与引导状态。
  late final ConfigInstallService configInstaller;

  /// 源提供者。
  late final StorageSourceProvider sourceProvider;

  /// 关闭底层资源。
  Future<void> dispose() => database.close();
}

/// 延迟创建的搜索器：每次搜索时根据 sourceId 查站点并创建 HttpRuntime。
class _LazySearcher implements SpiderSearcher {
  _LazySearcher(this.sites);

  /// 站点仓储。
  final SiteRepository sites;

  @override
  Future<SpiderSearchResult> search(int sourceId, String keyword) async {
    final site = await sites.byId(sourceId);
    if (site == null) {
      return const SpiderSearchResult(error: '站点不存在');
    }
    return HttpSpiderSearcher(HttpRuntime(site.api)).search(sourceId, keyword);
  }
}
