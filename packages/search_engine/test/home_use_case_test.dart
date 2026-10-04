/// [HomeUseCase] tests.
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:search_engine/search_engine.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

class _HomeRuntime implements SpiderRuntime {
  _HomeRuntime(this.body);

  final String body;
  int homeCalls = 0;

  @override
  Future<Result<HttpResponseData, AppError>> home({int page = 1}) async {
    homeCalls++;
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
  Future<Result<HttpResponseData, AppError>> category() =>
      throw UnimplementedError();

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
  _HomeFactory(this.runtime, {this.supportedTypeCodes});

  final SpiderRuntime runtime;

  /// 认哪些 `typeCode`。
  ///
  /// `null` = 任何站点都算「有运行时」（多数用例的默认：假工厂手里永远有一个
  /// 现成的 runtime）；给定集合时只认这些，用来构造「缺运行时」的场景。
  final Set<int>? supportedTypeCodes;

  /// `create` 被调用了几次。用来断言「缺运行时的源根本没被拿去建运行时」——
  /// 只断言返回错误是不够的，旧实现在报错前会先撞满 8s 的建运行时超时。
  int createCalls = 0;

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
    createCalls++;
    return runtime;
  }

  @override
  Future<void> dispose() async {}
}

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
}
