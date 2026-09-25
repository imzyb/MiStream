/// [DetailUseCase] tests.
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:mistream/application/detail_use_case.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

class _DetailRuntime implements SpiderRuntime {
  _DetailRuntime(this.body, {this.error, this.throwOnDetail});

  final String body;
  final AppError? error;
  final Error? throwOnDetail;
  int detailCalls = 0;
  bool disposed = false;

  @override
  Future<Result<HttpResponseData, AppError>> detail({
    required String ids,
  }) async {
    detailCalls++;
    final thrown = throwOnDetail;
    if (thrown != null) throw thrown;
    final err = error;
    if (err != null) return Err(err);
    return Ok(
      HttpResponseData(
        status: 200,
        headers: const {},
        body: body,
        finalUrl: 'https://example.com/?ac=detail',
        elapsedMs: 1,
      ),
    );
  }

  @override
  Future<Result<HttpResponseData, AppError>> home({int page = 1}) =>
      throw UnimplementedError();

  @override
  Future<Result<HttpResponseData, AppError>> category() =>
      throw UnimplementedError();

  @override
  Future<Result<HttpResponseData, AppError>> categoryDetail({
    required String typeId,
    int page = 1,
  }) => throw UnimplementedError();

  @override
  Future<Result<HttpResponseData, AppError>> search({
    required String keyword,
    int page = 1,
  }) => throw UnimplementedError();

  @override
  Future<Result<HttpResponseData, AppError>> play({
    required String flag,
    required String ids,
  }) => throw UnimplementedError();

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _DetailFactory implements SpiderRuntimeFactory {
  _DetailFactory(this.runtime, {this.createError});

  final _DetailRuntime runtime;
  final Error? createError;

  int? lastTypeCode;
  String? lastApi;
  String? lastSourceUrl;
  String? lastSpiderJarUrl;
  String? lastSpiderJarMd5;

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

  // 假工厂手里永远有一个现成的 runtime，所以任何站点都算「有运行时」。
  @override
  bool supports({required int typeCode, required String api}) => true;

  @override
  Future<SpiderRuntime> create({
    required int typeCode,
    required String api,
    String? ext,
    String? sourceUrl,
    String? spiderJarUrl,
    String? spiderJarMd5,
  }) async {
    final error = createError;
    if (error != null) throw error;
    lastTypeCode = typeCode;
    lastApi = api;
    lastSourceUrl = sourceUrl;
    lastSpiderJarUrl = spiderJarUrl;
    lastSpiderJarMd5 = spiderJarMd5;
    return runtime;
  }

  @override
  Future<void> dispose() async {}
}

const _detailBody = {
  'list': [
    {
      'vod_id': '42',
      'vod_name': '测试影片',
      'vod_pic': 'https://img.example/poster.jpg',
      'vod_year': '2024',
      'vod_area': '中国大陆',
      'vod_class': '剧情,悬疑',
      'vod_remarks': '更新至 8 集',
      'vod_content': '<p>这是一个<b>简介</b>，含 HTML。</p>',
      'vod_play_from': r'量子m3u8$$$无尽',
      'vod_play_url':
          r'第1集$https://cdn.example/e01.m3u8#第2集$https://cdn.example/e02.m3u8'
          r'$$$第1集$https://page.example/play?id=1#第2集$https://page.example/play?id=2',
    },
  ],
};

/// 构造一个带配置源（url + spider jar + md5）的 type=3 站点。
Future<Site> _seedType3Site(
  AppDatabase db, {
  bool withConfigSource = true,
}) async {
  var configId = 0;
  if (withConfigSource) {
    configId = await db
        .into(db.configSources)
        .insert(
          ConfigSourcesCompanion.insert(
            name: 'qist',
            url: const Value('https://config.example/tvbox.json'),
            spider: const Value('https://config.example/spider.jar'),
            spiderMd5: const Value('0123456789abcdef0123456789abcdef'),
            rawHash: 'hash',
            format: 'json',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
  }
  final repo = SiteRepository(db);
  return repo.upsert(
    SitesCompanion.insert(
      configId: Value(configId == 0 ? null : configId),
      siteKey: 'fan',
      name: '饭太硬',
      typeCode: 3,
      runtime: 'js',
      api: 'csp_Fan',
      ext: const Value('https://spider.example/ext.js'),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
}

void main() {
  group('DetailUseCase', () {
    test('type=3 站点走运行时工厂并解析出线路与剧集', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final site = await _seedType3Site(db);

      final runtime = _DetailRuntime(jsonEncode(_detailBody));
      final factory = _DetailFactory(runtime);
      final useCase = DetailUseCase(
        SiteRepository(db),
        runtimeFactory: factory,
      );

      final result = await useCase.load(siteId: site.id, vodId: '42');

      expect(result.isOk, isTrue, reason: '${result.errorOrNull?.message}');
      final detail = result.valueOrNull!;
      expect(factory.lastTypeCode, 3);
      expect(factory.lastApi, 'csp_Fan');
      expect(detail.name, '测试影片');
      expect(detail.pic, 'https://img.example/poster.jpg');
      expect(detail.year, '2024');
      expect(detail.area, '中国大陆');
      expect(detail.genre, '剧情,悬疑');
      expect(detail.remarks, '更新至 8 集');
      expect(detail.description, '这是一个简介，含 HTML。');
      expect(detail.flags, ['量子m3u8', '无尽']);
      expect(detail.episodes['量子m3u8'], hasLength(2));
      expect(detail.episodes['量子m3u8']!.first.name, '第1集');
      expect(detail.episodes['量子m3u8']!.first.id, '0');
      expect(detail.episodes['量子m3u8']![1].id, '1');
      expect(detail.episodes['无尽']![1].name, '第2集');
      expect(runtime.detailCalls, 1);
      expect(runtime.disposed, isTrue, reason: '用完的运行时应收缴');
    });

    test('type=3 站点把配置源 url/spider jar/md5 透传给工厂', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final site = await _seedType3Site(db);

      final runtime = _DetailRuntime(jsonEncode(_detailBody));
      final factory = _DetailFactory(runtime);
      final useCase = DetailUseCase(
        SiteRepository(db),
        runtimeFactory: factory,
      );

      await useCase.load(siteId: site.id, vodId: '42');

      expect(factory.lastSourceUrl, 'https://config.example/tvbox.json');
      expect(factory.lastSpiderJarUrl, 'https://config.example/spider.jar');
      expect(
        factory.lastSpiderJarMd5,
        '0123456789abcdef0123456789abcdef',
      );
    });

    test('运行时返回错误时透传', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final site = await _seedType3Site(db);

      final runtime = _DetailRuntime(
        '',
        error: const RemoteError(
          code: ErrorCode.scriptRuntimeError,
          message: '脚本执行失败',
        ),
      );
      final useCase = DetailUseCase(
        SiteRepository(db),
        runtimeFactory: _DetailFactory(runtime),
      );

      final result = await useCase.load(siteId: site.id, vodId: '42');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.message, '脚本执行失败');
      expect(runtime.disposed, isTrue, reason: '失败路径也要回收运行时');
    });

    test('运行时创建失败转成错误而不是抛出', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final site = await _seedType3Site(db);

      final useCase = DetailUseCase(
        SiteRepository(db),
        runtimeFactory: _DetailFactory(
          _DetailRuntime(''),
          createError: StateError('JVM 运行时未配置（spider_jvm 未安装）'),
        ),
      );

      final result = await useCase.load(siteId: site.id, vodId: '42');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.code, ErrorCode.invalidState);
      expect(result.errorOrNull!.message, contains('JVM 运行时未配置'));
    });

    test('运行时 detail 抛异常时透传错误并回收运行时', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final site = await _seedType3Site(db);

      final runtime = _DetailRuntime('', throwOnDetail: StateError('进程崩溃'));
      final useCase = DetailUseCase(
        SiteRepository(db),
        runtimeFactory: _DetailFactory(runtime),
      );

      final result = await useCase.load(siteId: site.id, vodId: '42');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.code, ErrorCode.runtimeCrashed);
      expect(result.errorOrNull!.message, contains('进程崩溃'));
      expect(runtime.detailCalls, 1);
      expect(runtime.disposed, isTrue);
    });

    test('详情返回非法 JSON 时报解析错误', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final site = await _seedType3Site(db);

      final runtime = _DetailRuntime('not-json');
      final useCase = DetailUseCase(
        SiteRepository(db),
        runtimeFactory: _DetailFactory(runtime),
      );

      final result = await useCase.load(siteId: site.id, vodId: '42');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.code, ErrorCode.invalidResultSchema);
    });

    test('站点不存在时报 notFound', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final useCase = DetailUseCase(
        SiteRepository(db),
        runtimeFactory: _DetailFactory(_DetailRuntime('{}')),
      );

      final result = await useCase.load(siteId: 999, vodId: '42');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.code, ErrorCode.notFound);
    });

    test('parseDetail 对空线路给出空剧集', () {
      final detail = DetailUseCase.parseDetail(
        const {'vod_name': '无线路'},
      );
      expect(detail.name, '无线路');
      expect(detail.flags, isEmpty);
      expect(detail.episodes, isEmpty);
      expect(detail.description, isEmpty);
    });
  });
}
