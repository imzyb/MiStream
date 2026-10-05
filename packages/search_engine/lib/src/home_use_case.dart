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
    this.unavailableReason,
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

  /// 不可用时的**原因**（面向用户的中文短句）；可用时为 `null`。
  ///
  /// 只写「(暂不支持)」是不够的。实测那份 105 个站点的配置，用户在界面上看到
  /// 的是一整屏完全相同的「(暂不支持)」—— 他无法判断这是「配置坏了」
  /// 「软件坏了」还是「少装了个可选组件」，只能来问。原因必须写在脸上。
  final String? unavailableReason;

  /// 是否是 jar 形态的源（`api` 以 `csp_` 开头）。
  ///
  /// 即 ADR-006 里那类「实验性 · 二进制不可审计」的源。**即使运行时齐备，
  /// 也要用户显式确认后才加载**（ADR-006 决策第 4 条），所以 UI 需要单独
  /// 认出这一类，不能只靠 [hasRuntime]。
  bool get isExperimentalJar =>
      classifySiteRuntime(typeCode: typeCode, api: api) == SiteRuntimeKind.jvm;

  /// 当前实现能否直接取数。
  bool get isUsable => hasRuntime;
}

/// 探测各档超时。
///
/// 做成一个可注入的记录而不是四个散落的常量，是因为「首个 JVM 站点」那档
/// 必须能测 —— 生产值是 90 秒（要覆盖一次性的 dex→java 转换），用例不可能
/// 真等；而只测「默认值够大」等于没测。
typedef ProbeTimeouts = ({
  /// 单次取数（含建运行时）的总预算；超过即停止继续探测。
  Duration budget,

  /// 单个站点建运行时的超时。
  Duration create,

  /// **首个 JVM 站点**建运行时的超时，见 [HomeUseCase._trySites] 里的说明。
  Duration firstJvmCreate,

  /// 单次请求的超时。
  Duration request,
});

/// 生产默认值。
///
/// `firstJvmCreate` 为什么必须比 `create` 大一个数量级：JVM 蜘蛛的首次
/// `create` 要在运行时侧把 `classes.dex` 转成 java 字节码，**实测约 48 秒**
/// （按原始 jar 的 md5 缓存，之后秒回）。用 8 秒的常规超时会让第一轮探测
/// **全军覆没** —— 而且 JVM 运行时是单线程的，第一个 `create` 卡在转换里时，
/// 后面每个站点的 8 秒也逐个烧掉，`budget` 随即耗尽，界面上就是
/// 「所有站点均无法连接」。
///
/// 2026-10-05 实测复现：清掉 `%TEMP%\mistream-jvm-jars` 后启动，103 个站点
/// 全部报 `TimeoutException after 0:00:08`；而缓存是暖的时候同一个包首页正常
/// 出图。用户点一次「重试」就好（那时缓存已暖），但**第一次**体验就是
/// 「全都不能用」—— 这正是长期被报的症状。
const ProbeTimeouts defaultProbeTimeouts = (
  budget: Duration(seconds: 30),
  create: Duration(seconds: 8),
  firstJvmCreate: Duration(seconds: 90),
  request: Duration(seconds: 5),
);

/// 首页编排器。
class HomeUseCase {
  /// 构造首页编排器。
  ///
  /// [timeouts] 供用例注入短值 —— 生产默认值里「首个 JVM 站点」那条是 90 秒
  /// （要覆盖一次性的 dex→java 转换），用例不可能真等它。
  HomeUseCase(
    this.sites, {
    this.runtimeFactory,
    this.cacheTtl = const Duration(minutes: 5),
    ProbeTimeouts? timeouts,
  }) : timeouts = timeouts ?? defaultProbeTimeouts;
  final SiteRepository sites;
  final SpiderRuntimeFactory? runtimeFactory;

  /// 首页缓存 TTL，测试可注入短 TTL。
  final Duration cacheTtl;

  /// 探测用的各档超时。
  final ProbeTimeouts timeouts;

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
          unavailableReason: _runtimeGapReason(s),
        ),
    ];
  }

  /// 站点不可用的原因；可用时返回 `null`。
  ///
  /// 与 [_siteHasRuntime] **共用同一把尺子**（`classifySiteRuntime`），否则
  /// 「能不能用」和「为什么不能用」会各说各话 —— 那种状态下 UI 会把一个可用的
  /// 源说成缺运行时，用户照着提示去装 JRE 也修不好。
  String? _runtimeGapReason(Site s) {
    if (_siteHasRuntime(s)) return null;
    return switch (classifySiteRuntime(typeCode: s.typeCode, api: s.api)) {
      // 这两种成因在界面上必须分开说：JVM 运行时是可选的、要用户自己动手装
      // （ADR-006），而 JS 运行时是产品自带的能力 —— 后者缺失属于装包不完整。
      SiteRuntimeKind.jvm => '需要 JVM 运行时（实验性可选组件）',
      SiteRuntimeKind.js => '需要 JS 运行时（当前装配未就绪）',
      SiteRuntimeKind.unsupported => '类型不支持（type=${s.typeCode}）',
      // HTTP 类零脚本，[_siteHasRuntime] 对它恒真，走不到这里。
      SiteRuntimeKind.http => null,
    };
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
    usable.sort(_compareSites);
    return usable;
  }

  /// 站点探测顺序：**上次成功的 → HTTP 类 → 配置优先级 → id 升序**。
  ///
  /// 最后那条 `id` 兜底不是装饰，它是「有时能用有时不能用」的解药。
  ///
  /// 这份真实配置 **103 个站点全是 `priority = 0`**，而 Dart 的 `List.sort`
  /// 对**对等键是不稳定的**（元素数 > 32 时走 dual-pivot quicksort，不是
  /// 插入排序）。没有兜底键时，「第一个被试的站点是谁」由快排的内部交换决定 ——
  /// 输入一样时它确定，但只要 `enabled()` 的行序有任何扰动（SQLite 无
  /// `ORDER BY` 的返回序、配置重导入后的 rowid 变化），首页就会换一个站点，
  /// 用户看到的就是「昨天能用今天不能用」。**加一条全序兜底，行为就钉死了。**
  ///
  /// 第一条（`lastOkAt`）让顺序**自我收敛**：首次启动挨个试出来的那个能用的
  /// 站点，下一次启动直接排到最前。见 [_recordSuccess]。
  static int _compareSites(Site a, Site b) {
    final aOk = a.lastOkAt;
    final bOk = b.lastOkAt;
    if (aOk != null || bOk != null) {
      if (aOk == null) return 1;
      if (bOk == null) return -1;
      final byRecency = bOk.compareTo(aOk);
      if (byRecency != 0) return byRecency;
    }
    // HTTP 类（type=1/4）优先：零脚本，通常最快可用；JS/JVM 类排后作兜底，
    // 避免首页被大量脚本源拖慢。
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
    if (byKind != 0) return byKind;
    final byPriority = b.priority.compareTo(a.priority);
    if (byPriority != 0) return byPriority;
    return a.id.compareTo(b.id);
  }

  /// 记下「这个站点刚刚取数成功」。
  ///
  /// `site` 表里 `status` / `last_ok_at` / `last_latency_ms` 这几列**从 v1 就
  /// 在**，`SiteRepository.updateStatus` 也早就写好 —— 但全仓库**没有任何代码
  /// 调用它**（属 `docs/CODE_AUDIT_*.md` 那类「声明了却没人用」的缺口）。
  /// 后果就是 [_compareSites] 里说的：排序只能靠 `priority`，而这份配置 103 个
  /// 站点全是 0，等于没排。
  ///
  /// 现在把成功落库，下次启动把上次成功的站点排到最前。
  ///
  /// **失败不记**，这是刻意的：失败的成因多半在站点侧或上游（要登录、限流、
  /// 改版），拿一个会过期的计数去熔断站点，比不熔断更糟 —— 用户会看着一个
  /// 明明恢复了的站点被永久跳过。`_trySites` 本来就会挨个往下试，兜底已经有了。
  Future<void> _recordSuccess(Site site, Duration elapsed) async {
    try {
      await sites.updateStatus(
        site.id,
        status: 'ok',
        lastOkAt: DateTime.now().toUtc(),
        lastLatencyMs: elapsed.inMilliseconds,
      );
    } on Object {
      // 记状态是**优化**，不是正确性的一部分：写库失败绝不能把一次已经成功的
      // 取数变成失败，更不能把首页的异常往上抛。
    }
  }

  /// 取不到站点列表时的错误文案。
  ///
  /// 显式指定了 [siteId] 时不能说「无可用站点」—— 用户（或上次的
  /// `workingSiteId`）指的是**某一个**源，笼统的文案会让人以为整份配置都坏了。
  /// 缺运行时是这里最常见的成因（`type=3` 里 `csp_` 开头的需要 JVM，
  /// ADR-006 降级为可选）。
  static String _noSiteMessage(int? siteId) =>
      siteId == null ? '无可用站点' : '所选片源不可用（缺少运行时或已停用）';

  /// 尝试用指定站点列表执行操作，返回第一个**被 [accept] 认可**的结果。
  ///
  /// 失败时汇总前几个站点的真实错误，避免把「所有站点均无法连接」这种
  /// 无信息量的消息抛给用户。
  ///
  /// [accept] 为什么必要 —— **「答了」不等于「答了数据」**。实测
  /// `csp_PanXunlei` 的 `home` 返回 200 + 完全合法的 JSON：
  ///
  /// ```json
  /// {"class":[{"type_id":"0","type_name":"还未登录迅雷账号,请前往【配置中心】登录",
  ///            "type_flag":"1"}],
  ///  "list":[],"parse":0,"jx":0}
  /// ```
  ///
  /// `list` 是空的，`class` 里那唯一一条是**提示语不是分类**。按「第一个 Ok 就
  /// 收」，首页会永久停在这么一张「请去登录」的卡片上，用户看到的就是
  /// 「首页没内容 / 这个站点不能用」—— 而这跟连接、超时、转换统统无关。
  ///
  /// 现在遇到这种站点：**记下来当兜底，继续往下试**，直到某个站点真的给出
  /// 可解析的内容。全都给不出内容时返回兜底的那个 —— 那时至少「站点答了」是
  /// 事实，比报「所有站点均无法连接」（明显不实）准确。
  ///
  /// 不传 [accept] 时保持原语义（第一个 Ok 就收），调用方按需选择。
  Future<Result<HttpResponseData, AppError>> _trySites(
    List<Site> siteList,
    Future<Result<HttpResponseData, AppError>> Function(SpiderRuntime runtime)
    action, {
    bool Function(String body)? accept,
  }) async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    // 第一个「答了但没内容」的响应，以及它是哪个站点给的。
    Result<HttpResponseData, AppError>? fallback;
    Site? fallbackSite;
    // 还没为任何一个 JVM 站点建过运行时。第一次可能要付那笔一次性的
    // dex→java 转换，所以给它更长的超时、并把这段耗时从探测预算里剔除。
    //
    // 判据用 `classifySiteRuntime` 而不是「是不是第一个站点」：站点列表是
    // HTTP 优先排序的，第一个站点通常是 HTTP（`_createRuntime` 是瞬时的），
    // 按序号判会把长超时浪费在它身上，真正的 JVM 站点照样只有 8 秒。
    var jvmCold = true;
    for (final site in siteList) {
      if (stopwatch.elapsed > timeouts.budget) {
        errors.add('超过 ${timeouts.budget.inSeconds}s 未取到数据');
        break;
      }
      final isJvm =
          classifySiteRuntime(typeCode: site.typeCode, api: site.api) ==
          SiteRuntimeKind.jvm;
      final needsWarmUp = isJvm && jvmCold;
      // 这个站点自己的耗时（建运行时 + 取数）。`stopwatch` 是整轮探测的预算
      // 计时器、而且会被 reset，拿它记 `last_latency_ms` 会记成前几个站点的
      // 累计值。
      final siteWatch = Stopwatch()..start();
      SpiderRuntime? runtime;
      try {
        runtime = await _createRuntime(site).timeout(
          needsWarmUp ? timeouts.firstJvmCreate : timeouts.create,
        );
        if (isJvm) {
          // 无论成功失败，转换都已经做过（或已经在做），后续 create 是热的。
          jvmCold = false;
          // 一次性开销不计入探测预算，否则转换一做完预算就烧光了，
          // 后面 100 个站点会被「超过 30s 未取到数据」一刀切掉。
          stopwatch.reset();
        }
        final result = await action(
          runtime,
        ).timeout(timeouts.request);
        await runtime.dispose();
        if (result.isOk) {
          final body = result.valueOrNull!.body;
          if (accept == null || accept(body)) {
            workingSite = site;
            await _recordSuccess(site, siteWatch.elapsed);
            return result;
          }
          fallback ??= result;
          fallbackSite ??= site;
          errors.add('${site.name}: 响应里没有可用内容');
          continue;
        }
        errors.add('${site.name}: ${result.errorOrNull?.message}');
      } on Object catch (e) {
        if (isJvm) {
          jvmCold = false;
          stopwatch.reset();
        }
        await runtime?.dispose();
        errors.add('${site.name}: $e');
      }
    }
    if (fallback != null) {
      workingSite = fallbackSite;
      return fallback;
    }
    final samples = errors.take(3).join('；');
    return Err(
      RemoteError(
        code: ErrorCode.networkTimeout,
        message: '所有站点均无法连接（共尝试 ${siteList.length} 个：$samples）',
      ),
    );
  }

  /// 首页响应里是否**真的有内容**（至少一条推荐）。
  ///
  /// 只看 `list`：首页的主体是海报墙，`list` 空就是「没有首页内容」。而
  /// `class` 不能作为判据 —— 上面 `csp_PanXunlei` 那个例子正说明 `class` 里
  /// 可以塞一句提示语。只带 `class` 不带 `list` 的站点（如 `csp_Djuu`）会
  /// 因此被跳过，但那是**有意的**：它给不出海报，让位给能给海报的站点，
  /// 用户看到的东西更多；全都给不出时还有 [fallback] 兜着。
  bool _hasHomeContent(String body) =>
      _parseList(body, null).valueOrNull?.isNotEmpty ?? false;

  /// 分类响应里是否真的有分类。
  bool _hasCategories(String body) =>
      _parseCategories(body).valueOrNull?.isNotEmpty ?? false;

  /// 分类详情响应里是否真的有影片。
  bool _hasCategoryItems(String body, int page) =>
      _parseCategoryDetail(body, page, null).valueOrNull?.items.isNotEmpty ??
      false;

  /// 获取第一个可用站点（用于详情页导航）。
  ///
  /// 与 [_trySites] **同一套超时策略**：首个 JVM 站点拿长超时（覆盖一次性的
  /// dex→java 转换）。早先这里既不给 `_createRuntime` 加超时、又把请求写死成
  /// 5 秒，冷缓存下要么无限等、要么在别的站点上白等 —— 两条路都和首页不一致。
  ///
  /// 判据也和首页一致：**答了不等于答了数据**，用 [_hasHomeContent] 而不是
  /// 「result.isOk」。否则一个「请去登录」的站点会被当成可用站点记进
  /// `workingSite`，详情页导航就挂在一个取不到详情的源上。
  Future<Site?> getWorkingSite() async {
    final siteList = await _getEnabledSites();
    var jvmCold = true;
    for (final site in siteList) {
      final isJvm =
          classifySiteRuntime(typeCode: site.typeCode, api: site.api) ==
          SiteRuntimeKind.jvm;
      final siteWatch = Stopwatch()..start();
      SpiderRuntime? runtime;
      try {
        runtime = await _createRuntime(site).timeout(
          isJvm && jvmCold ? timeouts.firstJvmCreate : timeouts.create,
        );
        if (isJvm) jvmCold = false;
        final result = await runtime.home().timeout(timeouts.request);
        await runtime.dispose();
        if (result.isOk && _hasHomeContent(result.valueOrNull!.body)) {
          workingSite = site;
          await _recordSuccess(site, siteWatch.elapsed);
          return site;
        }
      } on Object {
        if (isJvm) jvmCold = false;
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
    final result = await _trySites(
      siteList,
      (runtime) => runtime.home(),
      accept: _hasHomeContent,
    );
    return result.fold((ok) => _parseList(ok.body, ok.finalUrl), Err.new);
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
    final result = await _trySites(
      siteList,
      (runtime) => runtime.category(),
      accept: _hasCategories,
    );
    return result.fold((ok) => _parseCategories(ok.body), Err.new);
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
    final result = await _trySites(
      siteList,
      (runtime) => runtime.home(),
      accept: _hasHomeContent,
    );
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
            accept: _hasCategories,
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
      accept: (body) => _hasCategoryItems(body, page),
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
