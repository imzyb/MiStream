/// 应用层装配 -- 组合所有基础设施与 UseCase。
///
/// 这是整个应用的**唯一**组合根：数据库只在 `main.dart` 建一次并交到这里，
/// UI 一律经 `AppScope` 取用，不再自行建库。
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:download/download.dart';
import 'package:live/live.dart';
import 'package:media_sniffer/media_sniffer.dart';
import 'package:meta/meta.dart';
import 'package:mistream/application/config_install_service.dart';
import 'package:mistream/application/detail_use_case.dart';
import 'package:mistream/application/download_use_case.dart';
import 'package:mistream/application/live_epg_settings.dart';
import 'package:mistream/application/live_sort_settings.dart';
import 'package:mistream/application/live_source_fetcher.dart';
import 'package:path/path.dart' as p;
import 'package:player_engine/player_engine.dart';
import 'package:search_engine/search_engine.dart';
import 'package:sniffer/sniffer.dart';
import 'package:source_adapter/source_adapter.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';

/// 应用层装配。
class AppAssembly {
  /// 构造并装配。
  ///
  /// [downloadsRoot] 是下载根目录的绝对路径（`main.dart` 解析后传进来）。
  /// 为 `null` 时下载管理器不设删除边界 —— 只该出现在测试里，产品路径上
  /// 必须给值，否则「删除下载」会递归删掉应用目录之外的东西。
  AppAssembly(this.database, this.repositories, {this.downloadsRoot}) {
    // Spider JS 运行时：优先使用编译后的 exe，fallback 到 dart run
    final exePath = _resolveSpiderJsPath();
    _hostApi = HostApi();
    _runtimeFactory = SpiderRuntimeFactory(
      spiderJsPath: exePath,
      hostApi: _hostApi,
      jvm: _resolveJvmConfig(),
    );

    sourceProvider = StorageSourceProvider(repositories.sites);
    searchUseCase = SearchUseCase(
      sourceProvider: sourceProvider,
      spiderSearcher: _LazySearcher(
        repositories.sites,
        runtimeFactory: _runtimeFactory,
      ),
    );
    detailUseCase = DetailUseCase(
      repositories.sites,
      runtimeFactory: _runtimeFactory,
    );
    snifferResolver = SnifferResolver(
      fetcher: HttpSniffFetcher(timeout: const Duration(seconds: 6)).call,
      verifyDirectMedia: true,
    );
    // 浏览器嗅探器：**惰性**创建，构造时不探测内核（不扫文件系统）。
    // 只有静态嗅探失败时 `PlayUseCase` 才会调它，多数源根本走不到。
    browserSniffer = CdpSnifferLauncher();
    playUseCase = PlayUseCase(
      repositories.sites,
      runtimeFactory: _runtimeFactory,
      resolver: snifferResolver,
      browserSniffer: browserSniffer.sniff,
    );
    homeUseCase = HomeUseCase(
      repositories.sites,
      runtimeFactory: _runtimeFactory,
    );
    // 直播：仓储直连同一个数据库；拉取器持有复用的 HttpClient，一次导入
    // 会串行拉十几个订阅源，不该每个源各建一个客户端。
    liveRepository = DriftLiveRepository(database);
    liveFetcher = LiveSourceFetcher();
    liveImporter = LiveImporter(
      repository: liveRepository,
      fetcher: liveFetcher.call,
    );
    // EPG 与直播源共用同一个 HttpClient：节目单也是「拉一份文本」，多建一个
    // 客户端只是多一份连接池。模板先留空，等 `restoreLiveEpgTemplates()` 或
    // 配置导入时填。
    liveEpgFetcher = EpgFetcher(fetcher: liveFetcher.call);
    // 直播频道排序偏好。包一层是为了不让直播页直接依赖 `storage`
    // （Presentation 层不得 import 基础设施包，`docs/10` §3.3）。
    liveSortPreference = LiveSortPreference(repositories.settings);
    // 配置安装要顺带导入 `lives` 并落库 `epg` 模板，所以两者必须先就位。
    configInstaller = ConfigInstallService(
      repositories,
      liveImporter: liveImporter,
      epgFetcher: liveEpgFetcher,
    );
    // 下载：任务与分片进度落 `download` / `download_segment` 两张表。
    // 此前这两张表建了却零使用，任务只活在内存 `Map` 里 —— 「杀进程后重启
    // 状态恢复」与「断点续传」两条出口标准因此不可能成立。
    downloadRepository = DriftDownloadRepository(database);
    downloadManager = DownloadManager(
      repository: downloadRepository,
      downloadRoot: downloadsRoot,
    );
    downloadUseCase = DownloadUseCase(
      resolveSource: _resolvePlayableSource,
      manager: downloadManager,
      savePathFor: downloadSavePathFor,
    );
  }

  /// 底层数据库。
  final AppDatabase database;

  /// 仓储集合。
  final Repositories repositories;

  /// 下载根目录；`null` 表示未配置（仅测试）。
  final String? downloadsRoot;

  /// 聚合搜索用例。
  late final SearchUseCase searchUseCase;

  /// 影片详情用例。
  late final DetailUseCase detailUseCase;

  /// 播放编排用例。
  late final PlayUseCase playUseCase;

  /// 首页编排用例。
  late final HomeUseCase homeUseCase;

  /// 播放地址嗅探解析器（静态 HTML + 正则）。
  late final SnifferResolver snifferResolver;

  /// 浏览器嗅探器（CDP），静态嗅探失败后的兜底。
  ///
  /// 暴露出来是为了诊断链路能读到 `lastOutcome`——**为什么没嗅到**这件事
  /// 只有它知道（内核缺失 / 超时 / 页面报错 / 没命中），播放链路只需要一个
  /// 「能不能播」的答案。
  late final CdpSnifferLauncher browserSniffer;

  /// 配置导入与引导状态。
  late final ConfigInstallService configInstaller;

  /// 直播仓储（drift 落库）。
  late final LiveRepository liveRepository;

  /// 直播订阅导入编排（拉取 → 解析 → 合并 → 落库）。
  late final LiveImporter liveImporter;

  /// 直播源 HTTP 拉取器。
  late final LiveSourceFetcher liveFetcher;

  /// 直播 EPG 拉取器（按配置里的 `epg` 模板，单频道按需拉）。
  late final EpgFetcher liveEpgFetcher;

  /// 直播频道排序偏好的读写入口。
  late final LiveSortPreference liveSortPreference;

  /// 下载任务与分片进度的持久化仓储。
  late final DownloadRepository downloadRepository;

  /// 下载管理器（排队、限流、状态落库）。
  late final DownloadManager downloadManager;

  /// 「把某一集加入下载」的编排（解析地址 → 拼路径 → 落库 → 发车）。
  late final DownloadUseCase downloadUseCase;

  /// 源提供者。
  late final StorageSourceProvider sourceProvider;

  /// Spider JS 运行时工厂。
  late final SpiderRuntimeFactory _runtimeFactory;

  /// 宿主 API。
  late final HostApi _hostApi;

  /// 恢复上次导入配置时存下的 EPG 模板。
  ///
  /// 配置原文不入库，模板是单独存的一份；不恢复的话重启后节目单永远是空的。
  /// 启动路径上 `await` 它，是因为播放页拿到频道时模板必须已经就位 ——
  /// 这一条几乎不耗时（一次 KV 读），不值得为它引入「首次使用时再加载」的
  /// 竞态。
  Future<void> restoreLiveEpgTemplates() async {
    liveEpgFetcher.updateTemplates(
      await loadLiveEpgTemplates(repositories.settings),
    );
  }

  /// 从库里恢复下载任务。
  ///
  /// 启动路径上 `await` 它：恢复过程会把上次残留的「下载中」统一降级为
  /// 「已暂停」（崩溃/强杀之后没有任务真的在下），并写回库。不 await 的话，
  /// 用户可能在降级完成前就点了「继续」，两边同时改同一行。
  ///
  /// **恢复不自动续传**：这一步只把状态读回来，是否接着下由用户决定。
  Future<void> restoreDownloads() => downloadManager.restore();

  /// 把 `PlayUseCase` 的结果压成「可下载的媒体源」。
  ///
  /// `PlayResult` 还带着集号、标题、是否经嗅探这些**播放侧**的东西；下载只关心
  /// 地址与请求头，所以在这里收一次。收在装配层而不是让 `DownloadUseCase` 直接
  /// 依赖 `PlayUseCase`，是为了让下载用例能脱离 Spider 运行时与嗅探器单独测。
  Future<Result<MediaSource, AppError>> _resolvePlayableSource({
    required int siteId,
    required String vodId,
    required String flag,
    String? episodeId,
  }) async {
    final result = await playUseCase.getPlayableSource(
      siteId: siteId,
      vodId: vodId,
      flag: flag,
      episodeId: episodeId,
    );
    if (result.isErr) return Err(result.errorOrNull!);
    return Ok(result.valueOrNull!.mediaSource);
  }

  /// 由影片名与集名生成下载保存路径。
  ///
  /// 路径拼装收在应用层，UI 只传标题 —— 否则「下载根目录在哪」这件事会散落到
  /// 每个调 `createTask` 的地方（旧实现就是每个调用点各写一遍硬编码的
  /// `/downloads/<标题>`）。
  ///
  /// **一集一个目录**（`<根>/<影片名>/<集名>`）：HLS 下载把分片写成
  /// `segment_000000.ts` 这种固定名字，同一部剧的多集如果共用一个目录，第二集
  /// 会直接覆盖第一集的分片 —— 两份任务各自以为自己下完了，合出来的文件是
  /// 两集混在一起。电影（[episodeName] 为空）就落在影片名那一层。
  ///
  /// 两级名字都过 [sanitizeDownloadName]：集名来自源站，`第 03 集` 这种带空格
  /// 的名字直接当目录名会被 Windows 悄悄吃掉尾随空格。
  String downloadSavePathFor(String vodName, [String? episodeName]) {
    final root = downloadsRoot;
    final show = sanitizeDownloadName(vodName);
    final episode = episodeName == null || episodeName.isEmpty
        ? null
        : sanitizeDownloadName(episodeName, fallback: '未命名');
    final relative = episode == null ? show : p.join(show, episode);
    return root == null ? relative : p.join(root, relative);
  }

  /// 关闭底层资源。
  Future<void> dispose() async {
    downloadManager.dispose();
    liveFetcher.close();
    await database.close();
  }

  /// 诊断：当前解析到的 JS 运行时路径。
  static String debugSpiderJsPath() => _resolveSpiderJsPath();

  /// 诊断：当前解析到的 JVM 配置；`null` 表示 JVM 不可用。
  static SpiderJvmConfig? debugJvmConfig() => _resolveJvmConfig();

  /// 定位 spider_js_runtime 可执行文件。
  ///
  /// 开发时通过 `dart run` 执行 Dart 脚本；编译后优先使用同目录下的 exe。
  static String _resolveSpiderJsPath() {
    final sep = Platform.pathSeparator;
    // 编译后：exe 旁边有 spider_js_runtime.exe
    final exeDir = File(Platform.resolvedExecutable).parent;
    final compiledExe = File('${exeDir.path}$sep${'spider_js_runtime.exe'}');
    if (compiledExe.existsSync()) return compiledExe.path;

    // 开发时：向上找 runtimes/spider_js/bin/spider_js_runtime.dart
    var dir = exeDir;
    for (var i = 0; i < 12; i++) {
      dir = dir.parent;
      final scriptPath =
          '${dir.path}${sep}runtimes${sep}spider_js${sep}bin${sep}spider_js_runtime.dart';
      if (File(scriptPath).existsSync()) return scriptPath;
    }
    // 额外：从当前工作目录找（flutter run 时 Directory.current 为项目根）
    final cwdScript =
        '${Directory.current.path}${sep}runtimes${sep}spider_js${sep}bin${sep}spider_js_runtime.dart';
    if (File(cwdScript).existsSync()) return cwdScript;
    // fallback：相对路径，依赖 melos 相对根
    return 'runtimes${sep}spider_js${sep}bin${sep}spider_js_runtime.dart';
  }

  /// 解析 JVM 运行时（spider_jvm）配置。
  ///
  /// 需要 java + 编译好的 spider_jvm_runtime.jar + libs 目录。找不到 java 或
  /// jar 时返回 null（csp_ 站点将报「JVM 运行时未配置」）。
  static SpiderJvmConfig? _resolveJvmConfig() {
    final javaPath = _resolveJavaPath();
    final base = _projectRoot();
    final runtimeJar = File(
      '${base.path}${Platform.pathSeparator}runtimes'
      '${Platform.pathSeparator}spider_jvm${Platform.pathSeparator}build'
      '${Platform.pathSeparator}spider_jvm_runtime.jar',
    );
    final libsDir = Directory(
      '${base.path}${Platform.pathSeparator}runtimes'
      '${Platform.pathSeparator}spider_jvm${Platform.pathSeparator}libs',
    );
    if (javaPath == null || !runtimeJar.existsSync() || !libsDir.existsSync()) {
      return null;
    }
    final cacheDir = Directory(
      '${Directory.systemTemp.path}'
      '${Platform.pathSeparator}mistream-jvm-spiders',
    );
    return SpiderJvmConfig(
      javaPath: javaPath,
      runtimeJarPath: runtimeJar.path,
      libsDirPath: libsDir.path,
      jarCacheDir: cacheDir,
    );
  }

  /// 定位 java 可执行文件：`JAVA_HOME` 优先，其次在 `PATH` 里逐个目录找。
  ///
  /// 只认 `JAVA_HOME` 是不够的：用 winget / scoop / 绿色版 JDK 装的机器常常只把
  /// `java` 放进 `PATH` 而不设 `JAVA_HOME`。漏掉这一路，`classifySiteRuntime`
  /// 判为 jvm 的站点（`api` 以 `csp_` 开头）会被整体当成「无运行时」——片源列表
  /// 里灰显不可点，探测阶段也直接跳过，整份 `csp_` 配置看起来完全不可用。
  static String? _resolveJavaPath() => resolveJavaPath(
    javaHome: Platform.environment['JAVA_HOME'],
    pathValue: Platform.environment['PATH'],
  );

  /// [_resolveJavaPath] 的实际逻辑。
  ///
  /// 环境值显式收参而不是自己读 `Platform.environment`，是为了可测——进程内的
  /// 环境变量改不了，只能把「值」传进来；否则「PATH 回退」这一条最关键的路径
  /// 就永远只能靠人工在真实机器上碰运气验证。
  @visibleForTesting
  static String? resolveJavaPath({String? javaHome, String? pathValue}) {
    if (javaHome != null && javaHome.isNotEmpty) {
      final candidate = File(
        '$javaHome${Platform.pathSeparator}bin'
        '${Platform.pathSeparator}$_javaExecutableName',
      );
      if (candidate.existsSync()) return candidate.path;
    }
    return findExecutableOnPath(pathValue, _javaExecutableName);
  }

  /// java 可执行文件名；Windows 带 `.exe` 后缀。
  static String get _javaExecutableName =>
      Platform.isWindows ? 'java.exe' : 'java';

  /// 在 `PATH` 值里逐个目录找 [executable]，返回第一个存在的绝对路径。
  ///
  /// 用 `existsSync` 逐目录探测，而不是 `Process.run('java', ['-version'])`：
  /// 本机进程创建有已知缺陷（命名管道忙），环境探测必须避免起子进程。
  @visibleForTesting
  static String? findExecutableOnPath(String? pathValue, String executable) {
    if (pathValue == null || pathValue.isEmpty) return null;
    final separator = Platform.isWindows ? ';' : ':';
    for (final rawDir in pathValue.split(separator)) {
      // PATH 里出现空段（`;;`）或多余空白是常态，跳过即可，不必当错误。
      final dir = rawDir.trim();
      if (dir.isEmpty) continue;
      final candidate = File('$dir${Platform.pathSeparator}$executable');
      if (candidate.existsSync()) return candidate.path;
    }
    return null;
  }

  /// 向上找项目根目录（含 runtimes/ 的目录）。
  static Directory _projectRoot() {
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 10; i++) {
      if (Directory(
        '${dir.path}${Platform.pathSeparator}runtimes',
      ).existsSync()) {
        return dir;
      }
      dir = dir.parent;
    }
    return Directory.current;
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
      String? spiderJarUrl;
      String? spiderJarMd5;
      if (site.configId != null) {
        sourceUrl = await sites.configSourceUrl(site.id);
        spiderJarUrl = await sites.configSourceSpider(site.id);
        spiderJarMd5 = await sites.configSourceSpiderMd5(site.id);
      }
      final runtime = await runtimeFactory!.create(
        typeCode: site.typeCode,
        api: site.api,
        ext: site.ext,
        sourceUrl: sourceUrl,
        spiderJarUrl: spiderJarUrl,
        spiderJarMd5: spiderJarMd5,
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
