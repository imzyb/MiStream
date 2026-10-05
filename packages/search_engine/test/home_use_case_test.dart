/// [HomeUseCase] tests.
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:search_engine/search_engine.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

class _HomeRuntime implements SpiderRuntime {
  _HomeRuntime(
    this.body, {
    this.failHome = false,
    this.onHome,
    this.categoryBody,
  });

  final String body;

  /// `home()` 是否返回失败。
  ///
  /// 用来构造「第一个站点取数失败、循环必须继续往下走」的场景 ——
  /// 探测预算是否被正确地重置，只有在这种情况下才观察得到。
  final bool failHome;

  /// 每次 `home()` 被调用时回调。
  ///
  /// 用来断言「某个站点**根本没走到取数那一步**」—— 只数 `create` 次数是
  /// 分辨不出来的：建运行时超时被掐掉、和建成功但取数失败，两者对调用次数
  /// 的贡献一样。
  final void Function()? onHome;

  /// `category()` 的响应体；不给则 `category()` 抛 `UnimplementedError`。
  final String? categoryBody;

  int homeCalls = 0;

  @override
  Future<Result<HttpResponseData, AppError>> home({int page = 1}) async {
    homeCalls++;
    onHome?.call();
    if (failHome) {
      return const Err(
        RemoteError(code: ErrorCode.networkTimeout, message: '模拟取数失败'),
      );
    }
    return Ok(
      HttpResponseData(
        status: 200,
        headers: const {},
        body: body,
        finalUrl: 'https://example.com/?ac=videolist',
        elapsedMs: 1,
      ),
    );
  }

  @override
  Future<Result<HttpResponseData, AppError>> category() async {
    final b = categoryBody;
    if (b == null) throw UnimplementedError();
    return Ok(
      HttpResponseData(
        status: 200,
        headers: const {},
        body: b,
        finalUrl: '',
        elapsedMs: 1,
      ),
    );
  }

  @override
  Future<Result<HttpResponseData, AppError>> categoryDetail({
    required String typeId,
    int page = 1,
  }) => throw UnimplementedError();

  @override
  Future<Result<HttpResponseData, AppError>> detail({required String ids}) =>
      throw UnimplementedError();

  @override
  Future<Result<HttpResponseData, AppError>> play({
    required String flag,
    required String ids,
  }) => throw UnimplementedError();

  @override
  Future<Result<HttpResponseData, AppError>> search({
    required String keyword,
    int page = 1,
  }) => throw UnimplementedError();

  @override
  Future<void> dispose() async {}
}

class _HomeFactory implements SpiderRuntimeFactory {
  _HomeFactory(
    this.runtime, {
    this.supportedTypeCodes,
    this.createDelays = const <Duration>[],
    this.runtimeBuilder,
    this.runtimesByApi,
  });

  final SpiderRuntime runtime;

  /// 认哪些 `typeCode`。
  ///
  /// `null` = 任何站点都算「有运行时」（多数用例的默认：假工厂手里永远有一个
  /// 现成的 runtime）；给定集合时只认这些，用来构造「缺运行时」的场景。
  final Set<int>? supportedTypeCodes;

  /// 第 N 次 `create` 要耗时多久（越界则取零）。
  ///
  /// 用来**真的把时间花掉**：`timeout()` 只对「真的还没完成」的 Future 生效，
  /// 一个立刻返回的假工厂永远测不出超时，也测不出「首个 JVM 站点拿长超时」
  /// 这条逻辑 —— 那正是冷启动时 103 个站点全报 8 秒超时的成因。
  final List<Duration> createDelays;

  /// 按调用序号产出 runtime；给定时覆盖 [runtime]。
  final SpiderRuntime Function(int index)? runtimeBuilder;

  /// 按 `api` 产出 runtime，优先于 [runtimeBuilder]。
  ///
  /// 探测是**按站点逐个**发生的，而且同一个站点可能被 `create` 多次（首页取数
  /// 一次、分类回填一次）。用序号绑 runtime 会把「同一站点被建了两次」错当成
  /// 「两个不同站点」—— 断言「回填只问了一个站点」时正好会踩到。按 `api` 绑就
  /// 不会。
  final Map<String, SpiderRuntime>? runtimesByApi;

  /// `create` 被调用了几次。用来断言「缺运行时的源根本没被拿去建运行时」——
  /// 只断言返回错误是不够的，旧实现在报错前会先撞满 8s 的建运行时超时。
  int createCalls = 0;

  /// `create` 收到的 `api`，**按调用先后**。
  ///
  /// 用来断言探测顺序 —— 顺序是「首页由哪个站点供数」的唯一可观测量，
  /// 也是「有时能用有时不能用」的观察点。
  final List<String> createdApis = <String>[];

  @override
  HostApi get hostApi => throw UnimplementedError();

  @override
  String get spiderJsPath => '';

  @override
  SpiderJvmConfig? get jvm => null;

  @override
  ProcessLauncher? get jvmLauncher => null;

  @override
  ProcessLauncher? get jsLauncher => null;

  @override
  bool supports({required int typeCode, required String api}) =>
      supportedTypeCodes?.contains(typeCode) ?? true;

  @override
  Future<SpiderRuntime> create({
    required int typeCode,
    required String api,
    String? ext,
    String? sourceUrl,
    String? spiderJarUrl,
    String? spiderJarMd5,
  }) async {
    final index = createCalls;
    createCalls++;
    createdApis.add(api);
    if (index < createDelays.length) {
      await Future<void>.delayed(createDelays[index]);
    }
    return runtimesByApi?[api] ?? runtimeBuilder?.call(index) ?? runtime;
  }

  @override
  Future<void> dispose() async {}
}

/// 往库里的站点表插一条站点，返回它。
Future<Site> _insertSite(
  SiteRepository sites, {
  required int configId,
  required String siteKey,
  required String name,
  required int typeCode,
  required String runtime,
  required String api,
  int priority = 0,
}) => sites.upsert(
  SitesCompanion.insert(
    configId: Value(configId),
    siteKey: siteKey,
    name: name,
    typeCode: typeCode,
    runtime: runtime,
    api: api,
    priority: Value(priority),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
);

/// 建一份只有 `configSources` 一行的空库，返回 (db, configId)。
Future<(AppDatabase, int)> _newDb(String rawHash) async {
  final db = AppDatabase.inMemory();
  final configId = await db
      .into(db.configSources)
      .insert(
        ConfigSourcesCompanion.insert(
          name: 'test config',
          rawHash: rawHash,
          format: 'json',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
  return (db, configId);
}

const _okBody =
    '{"class":[{"type_id":"1","type_name":"电影"}],'
    '"list":[{"vod_id":"42","vod_name":"测试影片"}]}';

/// `csp_PanXunlei.home` 的**真实**响应（105 字节，2026-10-05 实测）：
/// `list` 是空的，`class` 里那唯一一条是**提示语不是分类**。
///
/// 这就是「答了 ≠ 答了数据」的标本 —— 站点返回 200 + 完全合法的 JSON，
/// 按「第一个 Ok 就收」会让首页永久停在一张「请去登录」的卡片上。
const String _loginCardBody =
    '{"class":[{"type_id":"0","type_name":"还未登录迅雷账号,请前往【配置中心】登录","type_flag":"1"}],"list":[],"parse":0,"jx":0}';

/// `csp_Douban.home` 的**真实形状**（2026-10-05 实测，20 条推荐 / 0 个分类）：
/// `class` 是**空数组**，`list` 里是 20 条搜索结果。
///
/// 它是「只有推荐」那唯一一个站点，也是跨站回填的触发器 —— 旧实现拿到它之后
/// 会去问别的站点的 `category()`，把 `workingSite` 改成那个站点。
const String _recommendsOnlyBody =
    '{"class":[],"list":[{"vod_id":"42","vod_name":"只有海报"}]}';

/// `csp_Gulu.home` 的**真实形状**（2026-10-05 实测，0 条推荐 / 12 个分类）：
/// `list` 是**空数组**，`class` 里有 12 个带名字的分类。它是「只有分类」那
/// 45 个站点之一。
const String _categoriesOnlyBody =
    '{"class":[{"type_id":"movie","type_name":"电影"}],'
    '"list":[],"filters":{}}';

/// `csp_Gulu.category()` 的**真实响应**（2026-10-05 实测，3727 字节）：
/// 一份**影片**列表，没有 `class`、没有 `type_id`/`type_name`。
///
/// 这是 `_parseCategories` 那条 `list` fallback 的陷阱标本 —— 旧实现把每条
/// 影片都当成一条分类，产出 `CategoryItem(typeId:'902056', typeName:'')`，
/// 首页「分类」行于是渲染成一排**没有文字的空白灰块**。
const String _videoListAsCategoriesBody =
    '{"list":[{"vod_id":"902056","vod_name":"兰香如故","vod_remarks":"已完结"},'
    '{"vod_id":"948475","vod_name":"余红旧事","vod_remarks":"已完结"}]}';

void main() {
  test(
    'getHomeData parses recommendations and classes from one home call',
    () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final configId = await db
          .into(db.configSources)
          .insert(
            ConfigSourcesCompanion.insert(
              name: 'test config',
              rawHash: 'hash',
              format: 'json',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          );
      final sites = SiteRepository(db);
      await sites.upsert(
        SitesCompanion.insert(
          configId: Value(configId),
          siteKey: 'mock',
          name: 'Mock',
          typeCode: 1,
          runtime: 'http',
          api: 'https://example.com/api.php/provide/vod/',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      final runtime = _HomeRuntime(
        jsonEncode({
          'class': [
            {'type_id': '1', 'type_name': '电影'},
          ],
          'list': [
            {'vod_id': '42', 'vod_name': '测试影片'},
          ],
        }),
      );
      final useCase = HomeUseCase(
        sites,
        runtimeFactory: _HomeFactory(runtime),
      );

      final result = await useCase.getHomeData();

      expect(result.isOk, isTrue);
      expect(runtime.homeCalls, 1);
      expect(result.valueOrNull!.recommends.single.vodId, '42');
      expect(result.valueOrNull!.recommends.single.vodName, '测试影片');
      expect(result.valueOrNull!.categories.single.typeId, '1');
      expect(result.valueOrNull!.categories.single.typeName, '电影');
      expect(useCase.workingSiteId, isNotNull);
    },
  );

  test('getHomeData honors an explicitly selected site', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final configId = await db
        .into(db.configSources)
        .insert(
          ConfigSourcesCompanion.insert(
            name: 'test config',
            rawHash: 'hash-2',
            format: 'json',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
    final sites = SiteRepository(db);
    final selected = await sites.upsert(
      SitesCompanion.insert(
        configId: Value(configId),
        siteKey: 'selected',
        name: 'Selected',
        typeCode: 1,
        runtime: 'http',
        api: 'https://selected.example/api',
        priority: const Value(1),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await sites.upsert(
      SitesCompanion.insert(
        configId: Value(configId),
        siteKey: 'higher-priority',
        name: 'Higher priority',
        typeCode: 1,
        runtime: 'http',
        api: 'https://higher.example/api',
        priority: const Value(100),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final runtime = _HomeRuntime(
      jsonEncode({
        'class': [
          {'type_id': '1', 'type_name': '电影'},
        ],
        'list': [
          {'vod_id': '42', 'vod_name': '测试影片'},
        ],
      }),
    );
    final useCase = HomeUseCase(
      sites,
      runtimeFactory: _HomeFactory(runtime),
    );

    final result = await useCase.getHomeData(siteId: selected.id);

    expect(result.isOk, isTrue);
    expect(useCase.workingSiteId, selected.id);
    expect(runtime.homeCalls, 1);
  });

  test('getHomeData 第二次命中缓存不再建运行时', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final configId = await db
        .into(db.configSources)
        .insert(
          ConfigSourcesCompanion.insert(
            name: 'cache config',
            rawHash: 'hash-cache',
            format: 'json',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
    final sites = SiteRepository(db);
    await sites.upsert(
      SitesCompanion.insert(
        configId: Value(configId),
        siteKey: 'cache-mock',
        name: 'CacheMock',
        typeCode: 1,
        runtime: 'http',
        api: 'https://cache.example/api',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final runtime = _HomeRuntime(
      jsonEncode({
        'class': [
          {'type_id': '1', 'type_name': '电影'},
        ],
        'list': [
          {'vod_id': '1', 'vod_name': '缓存影片'},
        ],
      }),
    );
    final useCase = HomeUseCase(
      sites,
      runtimeFactory: _HomeFactory(runtime),
      cacheTtl: const Duration(minutes: 5),
    );

    final r1 = await useCase.getHomeData();
    expect(r1.isOk, isTrue);
    expect(runtime.homeCalls, 1);

    final r2 = await useCase.getHomeData();
    expect(r2.isOk, isTrue);
    // 命中缓存，不再调 runtime
    expect(runtime.homeCalls, 1);
    expect(r2.valueOrNull!.recommends.single.vodName, '缓存影片');

    useCase.clearCache();
    final r3 = await useCase.getHomeData();
    expect(r3.isOk, isTrue);
    expect(runtime.homeCalls, 2);
  });

  test('显式选到缺运行时的源：与选择器同口径，且不拿它去建运行时', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final configId = await db
        .into(db.configSources)
        .insert(
          ConfigSourcesCompanion.insert(
            name: 'runtime gating',
            rawHash: 'hash-3',
            format: 'json',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
    final sites = SiteRepository(db);
    await sites.upsert(
      SitesCompanion.insert(
        configId: Value(configId),
        siteKey: 'http-ok',
        name: 'HTTP 源',
        typeCode: 1,
        runtime: 'http',
        api: 'https://ok.example/api',
        priority: const Value(10),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    // type=3 要 JS 运行时，而下面那个工厂只认 type=1，所以它缺运行时。
    final noRuntime = await sites.upsert(
      SitesCompanion.insert(
        configId: Value(configId),
        siteKey: 'js-unsupported',
        name: 'JS 源',
        typeCode: 3,
        runtime: 'js',
        api: 'https://js.example/api',
        priority: const Value(99),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    // 这个 runtime 不该被用到（缺运行时的源根本走不到建运行时那一步），
    // 内容给个合法的空壳即可。类型参数显式写出来，否则空字面量推断不出类型。
    final runtime = _HomeRuntime(
      jsonEncode(<String, Object?>{'class': <Object?>[], 'list': <Object?>[]}),
    );
    final factory = _HomeFactory(runtime, supportedTypeCodes: {1});
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    // 选择器那一侧 —— 这是「灰显并禁用」的依据。
    final options = await useCase.listSources();
    expect(
      options.firstWhere((o) => o.id == noRuntime.id).isUsable,
      isFalse,
      reason: '选择器据此把该源灰显、onTap 置 null',
    );
    expect(
      options.firstWhere((o) => o.typeCode == 1).isUsable,
      isTrue,
      reason: '对照组：HTTP 类零脚本，不需要运行时工厂',
    );

    // 取数那一侧 —— 必须是同一把尺子。
    // 旧实现在这里「无条件尊重用户显式选择」，会把这个注定失败的源交给
    // `_trySites`，先建运行时再撞满 8s 超时，最后报一句笼统的
    // 「所有站点均无法连接（共尝试 1 个：…）」。
    final result = await useCase.getHomeData(siteId: noRuntime.id);

    expect(result.isErr, isTrue);
    expect(
      result.errorOrNull!.message,
      '所选片源不可用（缺少运行时或已停用）',
    );
    expect(
      factory.createCalls,
      0,
      reason: '不该为缺运行时的源建运行时 —— 这条才是「口径一致」的实质',
    );
  });

  // ── 冷启动超时（2026-10-05 实测复现的「所有站点均无法连接」） ──────────────
  //
  // JVM 蜘蛛的首次 `create` 要在运行时侧把 `classes.dex` 转成 java 字节码，
  // 实测约 48 秒。用 8 秒的常规超时会让第一轮探测全军覆没，而 JVM 运行时是
  // 单线程的，后面每个站点的 8 秒也逐个烧掉，探测预算随即耗尽 —— 界面上就是
  // 「所有站点均无法连接（共尝试 103 个：… TimeoutException after 0:00:08）」。
  //
  // 这四条用例必须**真的把时间花掉**（`createDelays`）才有效：`timeout()` 对
  // 一个立刻返回的 Future 是不生效的，秒回的假工厂永远测不出这条逻辑。

  const coldTimeouts = (
    budget: Duration(seconds: 30),
    create: Duration(milliseconds: 50),
    firstJvmCreate: Duration(seconds: 5),
    request: Duration(seconds: 5),
  );

  test('冷启动：首个 JVM 站点的 create 用 firstJvmCreate 而不是 create', () async {
    final (db, configId) = await _newDb('cold-jvm');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-cold',
      name: 'JVM 源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Cold',
    );
    final factory = _HomeFactory(
      _HomeRuntime(_okBody),
      createDelays: const [Duration(milliseconds: 300)],
    );
    final useCase = HomeUseCase(
      sites,
      runtimeFactory: factory,
      timeouts: coldTimeouts,
    );

    final result = await useCase.getHomeData();

    expect(
      result.isOk,
      isTrue,
      reason: '300ms 的首次转换 > create(50ms) 但 < firstJvmCreate(5s)，旧实现会在这里超时',
    );
    expect(result.valueOrNull!.recommends.single.vodId, '42');
    expect(factory.createCalls, 1);
  });

  test('对照：把 firstJvmCreate 退回 create，同一场景必然超时', () async {
    // 没有这条，上面那条可能只是因为「延迟没生效」而假绿 —— 早前在
    // ShimGapScan 上就吃过一次「两边都报 0 缺口」的假全绿。
    final (db, configId) = await _newDb('cold-control');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-cold',
      name: 'JVM 源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Cold',
    );
    final factory = _HomeFactory(
      _HomeRuntime(_okBody),
      createDelays: const [Duration(milliseconds: 300)],
    );
    final useCase = HomeUseCase(
      sites,
      runtimeFactory: factory,
      timeouts: (
        budget: coldTimeouts.budget,
        create: coldTimeouts.create,
        // 故意退回常规值 —— 复现 2026-10-05 那个「103 个站点全 8 秒超时」。
        firstJvmCreate: coldTimeouts.create,
        request: coldTimeouts.request,
      ),
    );

    final result = await useCase.getHomeData();

    expect(result.isErr, isTrue);
    expect(result.errorOrNull!.message, contains('TimeoutException'));
    expect(result.errorOrNull!.message, contains('共尝试 1 个'));
  });

  test('首个 JVM 转换的耗时不计入探测预算', () async {
    final (db, configId) = await _newDb('cold-budget');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-a',
      name: 'JVM A',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_A',
      priority: 20,
    );
    await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-b',
      name: 'JVM B',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_B',
      priority: 10,
    );
    final ok = _HomeRuntime(_okBody);
    final factory = _HomeFactory(
      ok,
      createDelays: const [Duration(milliseconds: 300)],
      runtimeBuilder: (i) => i == 0 ? _HomeRuntime('{}', failHome: true) : ok,
    );
    final useCase = HomeUseCase(
      sites,
      runtimeFactory: factory,
      timeouts: (
        budget: const Duration(milliseconds: 100),
        create: const Duration(milliseconds: 50),
        firstJvmCreate: const Duration(seconds: 5),
        request: const Duration(seconds: 5),
      ),
    );

    final result = await useCase.getHomeData();

    expect(
      factory.createCalls,
      2,
      reason: '不重置预算的话，首次转换的 300ms 会直接顶爆 100ms 预算，第二个站点根本不会被试到',
    );
    expect(result.isOk, isTrue);
  });

  test('只有首个 JVM 站点拿长超时，后续回到常规超时', () async {
    final (db, configId) = await _newDb('cold-once');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    for (final (key, priority) in const [('a', 30), ('b', 20), ('c', 10)]) {
      await _insertSite(
        sites,
        configId: configId,
        siteKey: 'csp-$key',
        name: 'JVM ${key.toUpperCase()}',
        typeCode: 3,
        runtime: 'jvm',
        api: 'csp_${key.toUpperCase()}',
        priority: priority,
      );
    }
    final ok = _HomeRuntime(_okBody);
    // 第 i 个 runtime 的 home 被调到时记下 i，用来断言「谁真的走到了取数」。
    final homeOrder = <int>[];
    final factory = _HomeFactory(
      ok,
      // 前两次 create 都慢：第一次是转换（该拿长超时），第二次是普通冷启
      // （该按常规超时被掐掉），第三次快。
      createDelays: const [
        Duration(milliseconds: 300),
        Duration(milliseconds: 300),
        Duration.zero,
      ],
      runtimeBuilder: (i) => _HomeRuntime(
        i == 2 ? _okBody : '{}',
        failHome: i != 2,
        onHome: () => homeOrder.add(i),
      ),
    );
    final useCase = HomeUseCase(
      sites,
      runtimeFactory: factory,
      timeouts: coldTimeouts,
    );

    final result = await useCase.getHomeData();

    expect(
      factory.createCalls,
      3,
      reason: '三个站点都要被试到 —— 第二个的建运行时超时不该中断整个循环',
    );
    expect(
      homeOrder,
      [0, 2],
      reason:
          '第二次慢 create（300ms > create 50ms）必须被掐掉，它的 home 不该被调用；若它也拿到 firstJvmCreate，homeOrder 会是 [0,1,2]',
    );
    expect(result.isOk, isTrue);
    expect(result.valueOrNull!.recommends.single.vodId, '42');
  });

  test('getWorkingSite 与首页同一套超时策略', () async {
    final (db, configId) = await _newDb('working-site');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    final id = await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-w',
      name: 'JVM W',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_W',
    );
    final factory = _HomeFactory(
      _HomeRuntime(_okBody),
      createDelays: const [Duration(milliseconds: 300)],
    );
    final useCase = HomeUseCase(
      sites,
      runtimeFactory: factory,
      timeouts: coldTimeouts,
    );

    expect(await useCase.getWorkingSite(), isNotNull);
    expect(useCase.workingSiteId, id.id);
  });

  // ── 「答了」≠「答了数据」（2026-10-05 冷启动实测暴露） ────────────────────
  //
  // `csp_PanXunlei` 的 home 返回 200 + 合法 JSON，但 `list` 空、`class` 里只有
  // 一句「还未登录迅雷账号」。按「第一个 Ok 就收」，首页会永久停在这么一张
  // 卡片上 —— 用户看到的就是「这个站点不能用」，而它跟连接、超时、转换都无关。

  test('第一个站点「答了但没内容」时继续往下试，落到有内容的站点', () async {
    final (db, configId) = await _newDb('empty-first');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-login',
      name: '需要登录的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Login',
      priority: 20,
    );
    final good = await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-good',
      name: '有内容的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Good',
      priority: 10,
    );
    final factory = _HomeFactory(
      _HomeRuntime(_okBody),
      runtimeBuilder: (i) => _HomeRuntime(i == 0 ? _loginCardBody : _okBody),
    );
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    final result = await useCase.getHomeData();

    expect(result.isOk, isTrue);
    expect(
      factory.createCalls,
      2,
      reason:
          '第一个源只答了一句「请去登录」，必须继续往下试 —— '
          '「第一个 Ok 就收」正是把首页钉死在那张卡片上的原因',
    );
    expect(result.valueOrNull!.recommends.single.vodId, '42');
    expect(
      useCase.workingSiteId,
      good.id,
      reason: 'workingSite 要落在真正有内容的源上，否则详情页导航会挂在空源上',
    );
  });

  test('所有站点都「答了但没内容」：返回兜底，而不是谎报「无法连接」', () async {
    final (db, configId) = await _newDb('all-empty');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    for (final (key, priority) in const [('a', 20), ('b', 10)]) {
      await _insertSite(
        sites,
        configId: configId,
        siteKey: 'csp-$key',
        name: '登录源 ${key.toUpperCase()}',
        typeCode: 3,
        runtime: 'jvm',
        api: 'csp_${key.toUpperCase()}',
        priority: priority,
      );
    }
    final factory = _HomeFactory(_HomeRuntime(_loginCardBody));
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    final result = await useCase.getHomeData();

    expect(
      result.isOk,
      isTrue,
      reason:
          '站点明明答了 200，报「所有站点均无法连接」是不实描述 —— '
          '会把排查方向引到网络/运行时上',
    );
    expect(result.valueOrNull!.recommends, isEmpty);
    expect(
      result.valueOrNull!.categories.single.typeName,
      contains('还未登录迅雷账号'),
      reason: '兜底返回的内容原样透出，用户至少知道要去登录',
    );
    expect(factory.createCalls, 2, reason: '两个站点都要试过才判定「全都没内容」');
    expect(useCase.workingSiteId, isNotNull);
  });

  test('getCategories 跳过「分类为空」的站点', () async {
    final (db, configId) = await _newDb('cat-empty');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    for (final (key, priority) in const [('a', 20), ('b', 10)]) {
      await _insertSite(
        sites,
        configId: configId,
        siteKey: 'csp-$key',
        name: '源 ${key.toUpperCase()}',
        typeCode: 3,
        runtime: 'jvm',
        api: 'csp_${key.toUpperCase()}',
        priority: priority,
      );
    }
    final factory = _HomeFactory(
      _HomeRuntime(_okBody),
      runtimeBuilder: (i) => _HomeRuntime(
        _okBody,
        categoryBody: i == 0
            ? '{"list":[]}'
            : '{"class":[{"type_id":"1","type_name":"电影"}]}',
      ),
    );
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    final result = await useCase.getCategories();

    expect(result.isOk, isTrue);
    expect(factory.createCalls, 2, reason: '第一个源返回空分类，必须继续往下试');
    expect(result.valueOrNull!.single.typeName, '电影');
  });

  // ── 探测顺序：为什么「有时能用有时不能用」 ─────────────────────────────────
  //
  // 这份真实配置 **103 个站点全是 `priority = 0`**，而 Dart 的 `List.sort`
  // 对**对等键不稳定**（>32 元素走 dual-pivot quicksort）。没有全序兜底时
  // 「先试哪个」等于随机，首页跟着换站点。

  test('上次成功取过数的站点排到最前（哪怕 priority 更低）', () async {
    final (db, configId) = await _newDb('lastok-first');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-stale',
      name: '没成功过的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Stale',
      priority: 50,
    );
    final proven = await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-proven',
      name: '上次成功的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Proven',
      priority: 0,
    );
    await sites.updateStatus(
      proven.id,
      status: 'ok',
      lastOkAt: DateTime.utc(2026, 10, 5, 12),
    );

    final factory = _HomeFactory(_HomeRuntime(_okBody));
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    await useCase.getHomeData();

    expect(
      factory.createdApis,
      ['csp_Proven'],
      reason: '`priority` 高的那个反而排在后面 —— 顺序要由「上次成功」决定，否则同一份配置每次启动的首页可能来自不同站点',
    );
    expect(useCase.workingSiteId, proven.id);
  });

  test('成功取数后把 last_ok_at 落库（下次启动才能收敛）', () async {
    final (db, configId) = await _newDb('record-ok');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    final site = await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-ok',
      name: '源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Ok',
    );
    expect((await sites.byId(site.id))!.lastOkAt, isNull);

    final useCase = HomeUseCase(
      sites,
      runtimeFactory: _HomeFactory(_HomeRuntime(_okBody)),
    );
    await useCase.getHomeData();

    final after = await sites.byId(site.id);
    expect(
      after!.lastOkAt,
      isNotNull,
      reason:
          '`site` 表的 status/last_ok_at/last_latency_ms 与 '
          'SiteRepository.updateStatus 早就存在，但一直没人调用 —— '
          '不落库，排序就永远只能靠 priority（这份配置全是 0）',
    );
    expect(after.status, 'ok');
    expect(after.lastLatencyMs, isNotNull);
  });

  test('priority 全相同时探测顺序按 id 升序，不是快排的任意排列', () async {
    final (db, configId) = await _newDb('stable-order');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    // 40 > 32，Dart 的 List.sort 走 dual-pivot quicksort，对等键不稳定。
    for (var i = 0; i < 40; i++) {
      await _insertSite(
        sites,
        configId: configId,
        siteKey: 'csp-$i',
        name: '源 $i',
        typeCode: 3,
        runtime: 'jvm',
        api: 'csp_S$i',
      );
    }
    // 全部只答「请去登录」，于是 40 个都会被试到 —— 顺序完整可观察。
    final factory = _HomeFactory(_HomeRuntime(_loginCardBody));
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    await useCase.getHomeData();

    expect(factory.createdApis, hasLength(40));
    final rows = await sites.enabled(searchable: false);
    rows.sort((a, b) => a.id.compareTo(b.id));
    expect(
      factory.createdApis,
      [for (final s in rows) s.api],
      reason: '必须有一个全序的兜底键，否则「先试哪个」由快排的内部交换决定',
    );
  });

  // ── 首页两行必须来自同一个站点 ─────────────────────────────────────────────
  //
  // 2026-10-05 实测 103 个站点的 `home` 形状（`_probe_home_shape.dart`）：
  // 两行齐全 4 个、只有推荐 1 个（`csp_Douban`）、只有分类 45 个（`csp_Gulu`
  // 是其一）、其余 53 个都没有或失败。
  //
  // 只要求「有推荐」时，首页会选中 `csp_Douban`（`class` 为空数组）→ 触发跨站
  // 回填 → 回填成功把 `workingSite` 改成另一个站点。结果：顶栏站点名与推荐的
  // 实际来源不一致，`_navigateToDetail` 拿到的 `siteId` 是错的 —— 首页看起来
  // 有 9 张卡片，点任何一张都必然失败。

  test('首选「一次 home 同时给出推荐和分类」的站点，哪怕它排在后面', () async {
    final (db, configId) = await _newDb('prefer-complete');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-partial',
      name: '只有海报的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Partial',
      priority: 10,
    );
    final full = await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-full',
      name: '两行齐全的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Full',
      priority: 5,
    );
    final factory = _HomeFactory(
      _HomeRuntime(_okBody),
      runtimesByApi: {
        'csp_Partial': _HomeRuntime(_recommendsOnlyBody),
        'csp_Full': _HomeRuntime(_okBody),
      },
    );
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    final result = await useCase.getHomeData();

    expect(
      factory.createdApis,
      ['csp_Partial', 'csp_Full'],
      reason: '第一个源只给了海报没给分类，不能就此收工 —— 它会让两行来自不同站点',
    );
    expect(useCase.workingSiteId, full.id);
    expect(result.valueOrNull!.recommends.single.vodId, '42');
    expect(
      result.valueOrNull!.categories.single.typeName,
      '电影',
      reason: '两行必须同源：分类得来自真正供数的那一个站点',
    );
  });

  test('全是「答了但不完整」时，兜底选有海报的那个，不是先遇到的那个', () async {
    final (db, configId) = await _newDb('fallback-rank');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-notice',
      name: '只有提示语的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Notice',
      priority: 10,
    );
    final poster = await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-poster',
      name: '只有海报的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Poster',
      priority: 5,
    );
    final factory = _HomeFactory(
      _HomeRuntime(_loginCardBody),
      runtimesByApi: {
        'csp_Notice': _HomeRuntime(_loginCardBody),
        'csp_Poster': _HomeRuntime(_recommendsOnlyBody),
      },
    );
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    final result = await useCase.getHomeData();

    expect(
      factory.createdApis.take(2),
      ['csp_Notice', 'csp_Poster'],
      reason: '两个站点都要试过才判定「没有两行齐全的站点」（第 3 次是分类回填，见下条用例）',
    );
    expect(
      result.valueOrNull!.recommends.single.vodId,
      '42',
      reason: '兜底要按「用户能拿它做什么」分档：有海报（2 分）胜过只有提示语（1 分）。只留一个兜底槽时，先遇到的提示语会盖住后面的海报墙',
    );
    expect(useCase.workingSiteId, poster.id);
  });

  test('分类回填只在供数站点上做，不去问别的站点', () async {
    final (db, configId) = await _newDb('no-cross-site');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    final poster = await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-poster',
      name: '只有海报的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Poster',
      priority: 10,
    );
    await _insertSite(
      sites,
      configId: configId,
      siteKey: 'csp-cats',
      name: '只有分类的源',
      typeCode: 3,
      runtime: 'jvm',
      api: 'csp_Cats',
      priority: 5,
    );
    final factory = _HomeFactory(
      _HomeRuntime(_okBody),
      runtimesByApi: {
        // 供数站点自己的 category() 给的是一份**影片列表**（csp_Gulu 的真实形状）。
        'csp_Poster': _HomeRuntime(
          _recommendsOnlyBody,
          categoryBody: _videoListAsCategoriesBody,
        ),
        // 另一个站点有真分类 —— 旧实现会去问它，然后把 workingSite 改成它。
        'csp_Cats': _HomeRuntime(
          _categoriesOnlyBody,
          categoryBody: '{"class":[{"type_id":"1","type_name":"电影"}]}',
        ),
      },
    );
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    final result = await useCase.getHomeData();

    expect(
      useCase.workingSiteId,
      poster.id,
      reason:
          '推荐来自海报源，`workingSite` 就必须是它 —— 被回填改成分类源之后，`_navigateToDetail` 会拿错的 siteId 去查 `msearch:` 这种 vod_id',
    );
    expect(
      result.valueOrNull!.categories,
      isEmpty,
      reason: '影片列表不是分类，一条都不该透出来（否则渲染成一排空白灰块）',
    );
    expect(
      factory.createdApis.where((a) => a == 'csp_Cats'),
      hasLength(1),
      reason: '分类源只在首页探测里被建过一次，回填不该再去问它',
    );
  });

  test('分类接口返回影片列表时跳过该站点，不产出没有名字的分类', () async {
    final (db, configId) = await _newDb('videolist-not-categories');
    addTearDown(db.close);
    final sites = SiteRepository(db);
    for (final (key, priority) in const [('a', 20), ('b', 10)]) {
      await _insertSite(
        sites,
        configId: configId,
        siteKey: 'csp-$key',
        name: '源 ${key.toUpperCase()}',
        typeCode: 3,
        runtime: 'jvm',
        api: 'csp_${key.toUpperCase()}',
        priority: priority,
      );
    }
    final factory = _HomeFactory(
      _HomeRuntime(_okBody),
      runtimesByApi: {
        // csp_Gulu.category() 的真实响应：一份影片列表。
        'csp_A': _HomeRuntime(
          _okBody,
          categoryBody: _videoListAsCategoriesBody,
        ),
        'csp_B': _HomeRuntime(
          _okBody,
          categoryBody: '{"class":[{"type_id":"1","type_name":"电影"}]}',
        ),
      },
    );
    final useCase = HomeUseCase(sites, runtimeFactory: factory);

    final result = await useCase.getCategories();

    expect(
      factory.createCalls,
      2,
      reason:
          '影片列表里没有 type_id/type_name，一条分类都算不上 —— '
          '必须继续往下试，而不是把「兰香如故」当成分类收下',
    );
    expect(result.valueOrNull!.single.typeName, '电影');
    expect(result.valueOrNull!.single.typeId, '1');
  });
}
