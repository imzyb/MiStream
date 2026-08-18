/// 应用层装配 -- 组合所有基础设施与 UseCase。
///
/// 这是整个应用的**唯一**组合根：数据库只在 `main.dart` 建一次并交到这里，
/// UI 一律经 `AppScope` 取用，不再自行建库。
library;

import 'dart:convert';
import 'dart:io';

import 'package:media_sniffer/media_sniffer.dart';
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
    // Spider JS 运行时：优先使用编译后的 exe，fallback 到 dart run
    final exePath = _resolveSpiderJsPath();
    _hostApi = HostApi();
    _runtimeFactory = SpiderRuntimeFactory(
      spiderJsPath: exePath,
      hostApi: _hostApi,
    );

    sourceProvider = StorageSourceProvider(repositories.sites);
    searchUseCase = SearchUseCase(
      sourceProvider: sourceProvider,
      spiderSearcher: _LazySearcher(
        repositories.sites,
        runtimeFactory: _runtimeFactory,
      ),
    );
    detailUseCase = DetailUseCase(repositories.sites);
    snifferResolver = SnifferResolver(
      fetcher: HttpSniffFetcher(timeout: const Duration(seconds: 6)).call,
      verifyDirectMedia: true,
    );
    playUseCase = PlayUseCase(
      repositories.sites,
      runtimeFactory: _runtimeFactory,
      resolver: snifferResolver,
    );
    homeUseCase = HomeUseCase(
      repositories.sites,
      runtimeFactory: _runtimeFactory,
    );
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

  /// 播放编排用例。
  late final PlayUseCase playUseCase;

  /// 首页编排用例。
  late final HomeUseCase homeUseCase;

  /// 播放地址嗅探解析器。
  late final SnifferResolver snifferResolver;

  /// 配置导入与引导状态。
  late final ConfigInstallService configInstaller;

  /// 源提供者。
  late final StorageSourceProvider sourceProvider;

  /// Spider JS 运行时工厂。
  late final SpiderRuntimeFactory _runtimeFactory;

  /// 宿主 API。
  late final HostApi _hostApi;

  /// 关闭底层资源。
  Future<void> dispose() => database.close();

  /// 定位 spider_js_runtime 可执行文件。
  ///
  /// 开发时通过 `dart run` 执行 Dart 脚本；编译后优先使用同目录下的 exe。
  static String _resolveSpiderJsPath() {
    // 编译后：exe 旁边有 spider_js_runtime.exe
    final exeDir = File(Platform.resolvedExecutable).parent;
    final compiledExe = File('${exeDir.path}\\spider_js_runtime.exe');
    if (compiledExe.existsSync()) return compiledExe.path;

    // 开发时：通过 dart run 执行脚本
    // 向上找 runtimes/spider_js/bin/spider_js_runtime.dart
    var dir = exeDir;
    for (var i = 0; i < 10; i++) {
      dir = dir.parent;
      final scriptPath =
          '${dir.path}\\runtimes\\spider_js\\bin\\spider_js_runtime.dart';
      if (File(scriptPath).existsSync()) return scriptPath;
    }
    // fallback：假设在项目根目录下
    return 'runtimes/spider_js/bin/spider_js_runtime.dart';
  }
}

/// 延迟创建的搜索器：每次搜索时根据 sourceId 查站点并创建 SpiderRuntime。
class _LazySearcher implements SpiderSearcher {
  _LazySearcher(this.sites, {this.runtimeFactory});

  /// 站点仓储。
  final SiteRepository sites;

  /// Spider 运行时工厂；`null` 时仅支持 type=1。
  final SpiderRuntimeFactory? runtimeFactory;

  @override
  Future<SpiderSearchResult> search(int sourceId, String keyword) async {
    final site = await sites.byId(sourceId);
    if (site == null) {
      return const SpiderSearchResult(error: '站点不存在');
    }
    if (site.typeCode == 1) {
      return HttpSpiderSearcher(
        HttpRuntime(site.api),
      ).search(sourceId, keyword);
    }
    // type=3：走 Spider 运行时
    if (runtimeFactory == null) {
      return const SpiderSearchResult(error: 'JS 运行时未配置');
    }
    try {
      String? sourceUrl;
      if (site.configId != null) {
        sourceUrl = await sites.configSourceUrl(site.id);
      }
      final runtime = await runtimeFactory!.create(
        typeCode: site.typeCode,
        api: site.api,
        ext: site.ext,
        sourceUrl: sourceUrl,
      );
      try {
        final result = await runtime.search(keyword: keyword);
        return await result.fold(
          (ok) => _parseSearchResult(ok.body),
          (err) => SpiderSearchResult(error: err.message),
        );
      } finally {
        await runtime.dispose();
      }
    } on Object catch (e) {
      return SpiderSearchResult(error: '搜索失败: $e');
    }
  }

  /// 解析搜索结果 JSON。
  static SpiderSearchResult _parseSearchResult(String body) {
    try {
      final decoded = jsonDecode(body);
      final map = decoded is Map<String, Object?>
          ? decoded
          : (decoded is Map ? Map<String, Object?>.from(decoded) : null);
      if (map == null) return const SpiderSearchResult(error: '结果格式非法');
      final rawList = map['list'];
      if (rawList is! List) return const SpiderSearchResult(error: '结果格式非法');
      const maxResults = 50;
      final items = rawList.take(maxResults).map((item) {
        final m = item is Map<String, Object?>
            ? item
            : (item is Map
                  ? Map<String, Object?>.from(item)
                  : <String, Object?>{});
        return SpiderRawItem(
          vodId: '${m['vod_id'] ?? ''}',
          vodName: (m['vod_name'] as String?) ?? '',
          vodPic: m['vod_pic'] as String?,
          vodRemarks: m['vod_remarks'] as String?,
          vodYear: m['vod_year'] as String?,
        );
      }).toList();
      return SpiderSearchResult(items: items);
    } on Object catch (e) {
      return SpiderSearchResult(error: '解析失败: $e');
    }
  }
}
