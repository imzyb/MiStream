/// 首页编排：获取推荐、分类、分类详情。
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';

/// 首页推荐项。
class HomeItem {
  const HomeItem({
    required this.vodId,
    required this.vodName,
    this.vodPic,
    this.vodRemarks,
    this.vodYear,
  });
  final String vodId;
  final String vodName;
  final String? vodPic;
  final String? vodRemarks;
  final String? vodYear;
}

/// 分类项。
class CategoryItem {
  const CategoryItem({
    required this.typeId,
    required this.typeName,
  });
  final String typeId;
  final String typeName;
}

/// 分类详情项（带分页）。
class CategoryDetailResult {
  const CategoryDetailResult({
    required this.items,
    required this.page,
    required this.pageCount,
    required this.total,
  });
  final List<HomeItem> items;
  final int page;
  final int pageCount;
  final int total;
}

/// 首页完整数据（推荐 + 分类，单次 API 调用）。
class HomeData {
  /// 构造首页数据。
  const HomeData({required this.recommends, required this.categories});

  /// 推荐列表。
  final List<HomeItem> recommends;

  /// 分类列表。
  final List<CategoryItem> categories;
}

/// 供 UI 选择的片源选项。
///
/// Presentation 层不得直接依赖 `storage`（`docs/10` §3.3），所以首页的片源
/// 选择器拿到的是这个 DTO，而不是 drift 生成的 `Site` 行对象。
class SourceOption {
  /// 构造选项。
  const SourceOption({
    required this.id,
    required this.name,
    required this.api,
    required this.typeCode,
    this.hasRuntime = false,
  });

  /// 站点 id，跳详情页时作为路由参数。
  final int id;

  /// 站点显示名。
  final String name;

  /// API 地址，选择器里作为副标题显示，便于分辨同名源。
  final String api;

  /// 站点类型码（1 = HTTP JSON API，3 = JS Spider）。
  final int typeCode;

  /// 是否有对应运行时可用。
  ///
  /// 由 [HomeUseCase.listSources] 按站点逐个判定——**不要用全局标志**：
  /// `type=3` 里 `api` 以 `csp_` 开头的需要 JVM 运行时（ADR-006 降级为可选），
  /// 其余 `type=3` 走 JS。实测某真实配置 105 个站点全是 `csp_`，
  /// 用全局标志会把它们全判成可用。
  final bool hasRuntime;

  /// 当前实现能否直接取数。
  bool get isUsable => hasRuntime;
}

/// 首页编排器。
class HomeUseCase {
  /// 构造首页编排器。
  HomeUseCase(
    this.sites, {
    this.runtimeFactory,
    this.cacheTtl = const Duration(minutes: 5),
  });
  final SiteRepository sites;
  final SpiderRuntimeFactory? runtimeFactory;

  /// 首页缓存 TTL，测试可注入短 TTL。
  final Duration cacheTtl;

  final Map<String, _CachedHome> _homeCache = {};

  /// 最近一次成功请求的站点（用于详情页导航）。
  Site? workingSite;

  /// 最近一次成功取数的站点 id；还没成功过时为 `null`。
  int? get workingSiteId => workingSite?.id;

  /// 清空首页缓存（配置变更或用户手动刷新时调用）。
  void clearCache() => _homeCache.clear();

  /// 列出全部启用站点，供 UI 做片源选择。
  Future<List<SourceOption>> listSources() async {
    final enabled = await sites.enabled(searchable: false);
    return [
      for (final s in enabled)
        SourceOption(
          id: s.id,
          name: s.name,
          api: s.api,
          typeCode: s.typeCode,
          hasRuntime: _siteHasRuntime(s),
        ),
    ];
  }

  /// 该站点在当前装配下能否直接取数。
  ///
  /// HTTP 类（type=1/4）零脚本，不需要运行时工厂；其余要工厂真有能力。
  bool _siteHasRuntime(Site s) {
    final kind = classifySiteRuntime(typeCode: s.typeCode, api: s.api);
    if (kind == SiteRuntimeKind.http) return true;
    return runtimeFactory?.supports(typeCode: s.typeCode, api: s.api) ?? false;
  }

  Future<List<Site>> _getEnabledSites({int? siteId}) async {
    final enabled = await sites.enabled(searchable: false);
    if (enabled.isEmpty) return [];
    if (siteId != null) {
      // 与首页片源选择器**同一把尺子**：选择器只让 `isUsable` 的源可点
      // （`SourceOption.isUsable` → `_siteHasRuntime`），这里也必须同口径。
      //
      // 早先这里「无条件尊重用户显式选择，哪怕缺运行时」，理由是「点了没反应
      // 比报一个明确的错更难排查」—— 那个理由在 UI 加上灰显与「(暂不支持)」
      // 副标题之前成立。现在用户根本点不到不可用的源，这个分支在首页路径上
      // **不可达**，属两种意图各写了一半（`docs/CODE_AUDIT_2026-09-27.md` P3-3）。
      //
      // 统一后的行为：显式选到缺运行时的源 → 返回空 → 上层给出明确错误，
      // 而不是拿着一个注定失败的源去撞 8s 的建运行时超时。
      return enabled
          .where((site) => site.id == siteId && _siteHasRuntime(site))
          .toList();
    }
    // 丢掉缺运行时的源。以前这里只看 type 分不出「type=3 的 csp_ 需要 JVM」，
    // 于是 105 个 csp_ 站点会被挨个去试、把 30s 探测预算烧光还全失败。
    // 现在用与分发同一把尺子（classifySiteRuntime）先筛掉。
    final usable = enabled.where(_siteHasRuntime).toList();
    // HTTP 类（type=1/4）优先：零脚本，通常最快可用；JS 类排后作兜底，
    // 避免首页被大量 JS 源拖慢。
    usable.sort((a, b) {
      final aHttp =
          classifySiteRuntime(typeCode: a.typeCode, api: a.api) ==
              SiteRuntimeKind.http
          ? 0
          : 1;
      final bHttp =
          classifySiteRuntime(typeCode: b.typeCode, api: b.api) ==
              SiteRuntimeKind.http
          ? 0
          : 1;
      final byKind = aHttp.compareTo(bHttp);
      return byKind != 0 ? byKind : b.priority.compareTo(a.priority);
    });
    return usable;
  }

  /// 取不到站点列表时的错误文案。
  ///
  /// 显式指定了 [siteId] 时不能说「无可用站点」—— 用户（或上次的
  /// `workingSiteId`）指的是**某一个**源，笼统的文案会让人以为整份配置都坏了。
  /// 缺运行时是这里最常见的成因（`type=3` 里 `csp_` 开头的需要 JVM，
  /// ADR-006 降级为可选）。
  static String _noSiteMessage(int? siteId) =>
      siteId == null ? '无可用站点' : '所选片源不可用（缺少运行时或已停用）';

  /// 单次取数（含建运行时）的总时间预算；超过即停止继续探测。
  static const _probeBudget = Duration(seconds: 30);

  /// 单个站点建运行时的超时。
  static const _createTimeout = Duration(seconds: 8);

  /// 单次请求的超时。
  static const _requestTimeout = Duration(seconds: 5);

  /// 尝试用指定站点列表执行操作，返回第一个成功的结果。
  ///
  /// 失败时汇总前几个站点的真实错误，避免把「所有站点均无法连接」这种
  /// 无信息量的消息抛给用户。
  Future<Result<HttpResponseData, AppError>> _trySites(
    List<Site> siteList,
    Future<Result<HttpResponseData, AppError>> Function(SpiderRuntime runtime)
    action,
  ) async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    for (final site in siteList) {
      if (stopwatch.elapsed > _probeBudget) {
        errors.add('超过 ${_probeBudget.inSeconds}s 未取到数据');
        break;
      }
      SpiderRuntime? runtime;
      try {
        runtime = await _createRuntime(site).timeout(_createTimeout);
        final result = await action(
          runtime,
        ).timeout(_requestTimeout);
        await runtime.dispose();
        if (result.isOk) {
          workingSite = site;
          return result;
        }
        errors.add('${site.name}: ${result.errorOrNull?.message}');
      } on Object catch (e) {
        await runtime?.dispose();
        errors.add('${site.name}: $e');
      }
    }
    final samples = errors.take(3).join('；');
    return Err(
      RemoteError(
        code: ErrorCode.networkTimeout,
        message: '所有站点均无法连接（共尝试 ${siteList.length} 个：$samples）',
      ),
    );
  }

  /// 获取第一个可用站点（用于详情页导航）。
  Future<Site?> getWorkingSite() async {
    final siteList = await _getEnabledSites();
    for (final site in siteList) {
      SpiderRuntime? runtime;
      try {
        runtime = await _createRuntime(site);
        final result = await runtime.home().timeout(const Duration(seconds: 5));
        await runtime.dispose();
        if (result.isOk) {
          workingSite = site;
          return site;
        }
      } on Object {
        await runtime?.dispose();
      }
    }
    return null;
  }

  /// 获取首页推荐（取第一个启用站点的 home API）。
  Future<Result<List<HomeItem>, AppError>> getHome() async {
    final siteList = await _getEnabledSites();
    if (siteList.isEmpty) {
      return const Err(
        LocalError(
          code: ErrorCode.invalidArgument,
          message: '无可用站点',
        ),
      );
    }
    final result = await _trySites(siteList, (runtime) => runtime.home());
    return result.fold(
      (ok) => _parseList(ok.body, ok.finalUrl),
      Err.new,
    );
  }

  /// 获取分类列表。
  Future<Result<List<CategoryItem>, AppError>> getCategories() async {
    final siteList = await _getEnabledSites();
    if (siteList.isEmpty) {
      return const Err(
        LocalError(
          code: ErrorCode.invalidArgument,
          message: '无可用站点',
        ),
      );
    }
    final result = await _trySites(siteList, (runtime) => runtime.category());
    return result.fold(
      (ok) => _parseCategories(ok.body),
      Err.new,
    );
  }

  /// 获取首页完整数据（推荐 + 分类），单次 API 调用。
  ///
  /// Apple CMS v2 的 `?ac=videolist` 返回 `{list: [...], class: [...]}`，
  /// 同时包含推荐和分类。一次调用比 `getHome()` + `getCategories()` 更快且
  /// 保证使用同一个站点。
  Future<Result<HomeData, AppError>> getHomeData({int? siteId}) async {
    final cacheKey = siteId != null ? 'site:$siteId' : 'auto';
    final cached = _homeCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.at) < cacheTtl &&
        cached.data.categories.isNotEmpty) {
      workingSite = cached.site;
      return Ok(cached.data);
    }
    final siteList = await _getEnabledSites(siteId: siteId);
    if (siteList.isEmpty) {
      return Err(
        LocalError(
          code: ErrorCode.invalidArgument,
          message: _noSiteMessage(siteId),
        ),
      );
    }
    final result = await _trySites(siteList, (runtime) => runtime.home());
    return await result.fold(
      (ok) async {
        final base = ok.finalUrl.isNotEmpty
            ? ok.finalUrl
            : workingSite?.api ?? '';
        final recommends = _parseList(ok.body, base);
        final categories = _parseCategories(ok.body);
        if (recommends.isErr) return Err(recommends.errorOrNull!);
        if (categories.isErr) return Err(categories.errorOrNull!);
        var catList = categories.valueOrNull!;
        // 部分源 videolist 不带 class，尝试用 category 接口补全
        if (catList.isEmpty) {
          final catResult = await _trySites(
            siteList,
            (runtime) => runtime.category(),
          );
          catResult.fold(
            (ok2) {
              final parsed = _parseCategories(ok2.body);
              if (parsed.isOk && parsed.valueOrNull!.isNotEmpty) {
                catList = parsed.valueOrNull!;
              }
            },
            (_) {},
          );
        }
        final data = HomeData(
          recommends: recommends.valueOrNull!,
          categories: catList,
        );
        final site = workingSite;
        if (site != null &&
            (data.categories.isNotEmpty || data.recommends.isNotEmpty)) {
          _homeCache[cacheKey] = _CachedHome(data, site, DateTime.now());
        }
        return Ok(data);
      },
      (err) async => Err(err),
    );
  }

  /// 获取分类详情（分页）。
  Future<Result<CategoryDetailResult, AppError>> getCategoryDetail({
    required String typeId,
    int page = 1,
    int? siteId,
  }) async {
    final siteList = await _getEnabledSites(siteId: siteId);
    if (siteList.isEmpty) {
      return Err(
        LocalError(
          code: ErrorCode.invalidArgument,
          message: _noSiteMessage(siteId),
        ),
      );
    }
    final result = await _trySites(
      siteList,
      (runtime) => runtime.categoryDetail(typeId: typeId, page: page),
    );
    return result.fold(
      (ok) {
        final base = ok.finalUrl.isNotEmpty
            ? ok.finalUrl
            : workingSite?.api ?? '';
        return _parseCategoryDetail(ok.body, page, base);
      },
      Err.new,
    );
  }

  /// 根据站点类型创建运行时。
  Future<SpiderRuntime> _createRuntime(Site site) async {
    if (runtimeFactory != null) {
      // 查找配置源 URL（用于解析相对路径脚本）与 spider jar（csp_ 站点）
      String? sourceUrl;
      String? spiderJarUrl;
      String? spiderJarMd5;
      if (site.configId != null) {
        sourceUrl = await sites.configSourceUrl(site.id);
        spiderJarUrl = await sites.configSourceSpider(site.id);
        spiderJarMd5 = await sites.configSourceSpiderMd5(site.id);
      }
      return runtimeFactory!.create(
        typeCode: site.typeCode,
        api: site.api,
        ext: site.ext,
        sourceUrl: sourceUrl,
        spiderJarUrl: spiderJarUrl,
        spiderJarMd5: spiderJarMd5,
      );
    }
    // 降级：总是用 HttpRuntime
    return HttpRuntimeAdapter(HttpRuntime(site.api));
  }

  Result<List<HomeItem>, AppError> _parseList(String body, String? baseUrl) {
    try {
      final json = jsonDecode(body) as Map<String, Object?>;
      final list = json['list'] as List?;
      if (list == null) {
        return const Err(
          LocalError(
            code: ErrorCode.spiderParseFailed,
            message: '首页数据格式非法',
          ),
        );
      }
      final items = list.map((item) {
        final map = item is Map<String, Object?>
            ? item
            : (item is Map
                  ? Map<String, Object?>.from(item)
                  : <String, Object?>{});
        return HomeItem(
          vodId: '${map['vod_id'] ?? ''}',
          vodName: (map['vod_name'] as String?) ?? '',
          vodPic: _resolveImageUrl(map['vod_pic'] as String?, baseUrl),
          vodRemarks: map['vod_remarks'] as String?,
          vodYear: map['vod_year'] as String?,
        );
      }).toList();
      return Ok(items);
    } on Object catch (e) {
      return Err(
        LocalError(
          code: ErrorCode.spiderParseFailed,
          message: '解析失败: $e',
        ),
      );
    }
  }

  Result<List<CategoryItem>, AppError> _parseCategories(String body) {
    try {
      final json = jsonDecode(body) as Map<String, Object?>;
      // Apple CMS v2 home: {"list":[...vod...], "class":[{type_id, type_name}]}
      // Apple CMS v2 category: {"list":[{type_id, type_name}]}
      // TVBox 标准: {"class": [{"type_id":"1", "type_name":"电影"}]}
      // 优先取 class（home 响应里 list 是影片），fallback 到 list（category 响应）。
      final list =
          json['class'] as List? ??
          json['list'] as List? ??
          json['data'] as List? ??
          json['category'] as List? ??
          json['categories'] as List? ??
          json['types'] as List?;
      if (list == null) {
        return const Err(
          LocalError(
            code: ErrorCode.spiderParseFailed,
            message: '分类数据格式非法',
          ),
        );
      }
      final items = list.map((item) {
        final map = item is Map<String, Object?>
            ? item
            : (item is Map
                  ? Map<String, Object?>.from(item)
                  : <String, Object?>{});
        return CategoryItem(
          typeId: '${map['type_id'] ?? ''}',
          typeName: (map['type_name'] as String?) ?? '',
        );
      }).toList();
      return Ok(items);
    } on Object catch (e) {
      return Err(
        LocalError(
          code: ErrorCode.spiderParseFailed,
          message: '解析失败: $e',
        ),
      );
    }
  }

  Result<CategoryDetailResult, AppError> _parseCategoryDetail(
    String body,
    int page,
    String? baseUrl,
  ) {
    try {
      final json = jsonDecode(body) as Map<String, Object?>;
      final list = json['list'] as List?;
      final pageCount =
          (json['pagecount'] as num?)?.toInt() ??
          (json['pageCount'] as num?)?.toInt() ??
          1;
      final total = (json['total'] as num?)?.toInt() ?? 0;

      if (list == null) {
        return const Err(
          LocalError(
            code: ErrorCode.spiderParseFailed,
            message: '分类详情数据格式非法',
          ),
        );
      }
      final items = list.map((item) {
        final map = item is Map<String, Object?>
            ? item
            : (item is Map
                  ? Map<String, Object?>.from(item)
                  : <String, Object?>{});
        return HomeItem(
          vodId: '${map['vod_id'] ?? ''}',
          vodName: (map['vod_name'] as String?) ?? '',
          vodPic: _resolveImageUrl(map['vod_pic'] as String?, baseUrl),
          vodRemarks: map['vod_remarks'] as String?,
          vodYear: map['vod_year'] as String?,
        );
      }).toList();
      return Ok(
        CategoryDetailResult(
          items: items,
          page: page,
          pageCount: pageCount,
          total: total,
        ),
      );
    } on Object catch (e) {
      return Err(
        LocalError(
          code: ErrorCode.spiderParseFailed,
          message: '解析失败: $e',
        ),
      );
    }
  }

  /// 把相对图片地址解析成完整 URL。
  ///
  /// 不少源返回的 `vod_pic` 是相对路径（如 `/upload/xx.jpg`），`Image.network`
  /// 无法直接加载，需按 site.api 的 origin 补全。
  String? _resolveImageUrl(String? url, String? baseUrl) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) return url;
    final base = Uri.tryParse(baseUrl ?? '');
    if (base == null || !base.hasScheme) return url;
    if (url.startsWith('//')) return '${base.scheme}:$url';
    if (url.startsWith('/')) return '${base.scheme}://${base.authority}$url';
    return base.resolve(url).toString();
  }
}

class _CachedHome {
  const _CachedHome(this.data, this.site, this.at);
  final HomeData data;
  final Site site;
  final DateTime at;
}
