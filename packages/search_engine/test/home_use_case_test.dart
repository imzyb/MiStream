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
  _HomeFactory(this.runtime);

  final SpiderRuntime runtime;

  @override
  HostApi get hostApi => throw UnimplementedError();

  @override
  String get spiderJsPath => '';

  @override
  Future<SpiderRuntime> create({
    required int typeCode,
    required String api,
    String? ext,
    String? sourceUrl,
  }) async => runtime;

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
}
