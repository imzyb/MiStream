/// [PlayUseCase] 的单测。
///
/// 用内存库 + 假运行时 + 假嗅探器，全程不联网：这里要钉住的是「详情响应 →
/// 线路/集数定位 → 嗅探 → MediaSource」这条编排，而不是任何源站的可用性。
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:media_sniffer/media_sniffer.dart';
import 'package:search_engine/search_engine.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

/// 固定返回同一份 detail 响应的假运行时。
class _FakeRuntime implements SpiderRuntime {
  _FakeRuntime(this.detailBody, {this.detailError});

  final String detailBody;
  final AppError? detailError;
  var detailCalls = 0;

  @override
  Future<Result<HttpResponseData, AppError>> detail({
    required String ids,
  }) async {
    detailCalls++;
    final err = detailError;
    if (err != null) return Err(err);
    return Ok(
      HttpResponseData(
        status: 200,
        headers: const {},
        body: detailBody,
        finalUrl: '',
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
  Future<void> dispose() async {}
}

/// 只为把假运行时注入 [PlayUseCase] 的工厂。
class _FakeFactory implements SpiderRuntimeFactory {
  _FakeFactory(this.runtime);

  final SpiderRuntime runtime;

  @override
  Future<SpiderRuntime> create({
    required int typeCode,
    required String api,
    String? ext,
    String? sourceUrl,
    String? spiderJarUrl,
    String? spiderJarMd5,
  }) async => runtime;

  @override
  String get spiderJsPath => '';

  @override
  HostApi get hostApi => throw UnimplementedError();

  @override
  SpiderJvmConfig? get jvm => null;

  @override
  ProcessLauncher? get jvmLauncher => null;

  @override
  Future<void> dispose() async {}
}

/// 一份典型的 Apple CMS v2 detail 响应：两条线路，各三集。
String _detailBody({
  String playFrom = r'liangzi$$$lzm3u8',
  String? playUrl,
}) {
  final url =
      playUrl ??
      // 第一条是网页线路（share），第二条是直链线路（m3u8）。
      'HD中字\$https://cdn.a.com/share/e1'
          '#第2集\$https://cdn.a.com/share/e2'
          '#第3集\$https://cdn.a.com/share/e3'
          r'$$$'
          'HD中字\$https://cdn.a.com/1/index.m3u8'
          '#第2集\$https://cdn.a.com/2/index.m3u8'
          '#第3集\$https://cdn.a.com/3/index.m3u8';
  return jsonEncode({
    'code': 1,
    'list': [
      {
        'vod_id': 42,
        'vod_name': '样片',
        'vod_play_from': playFrom,
        'vod_play_url': url,
      },
    ],
  });
}

Future<SiteRepository> _sitesWith({
  String api = 'https://api.a.com/api.php/provide/vod/',
  int typeCode = 1,
}) async {
  final db = AppDatabase.inMemory();
  final now = DateTime.now();

  // site.config_id 有外键指向 config_source，且表上有 CHECK 要求 config_id 与
  // plugin_id 恰好一个非空 —— 先建一个配置源，站点才挂得上去。
  final configId = await db
      .into(db.configSources)
      .insert(
        ConfigSourcesCompanion.insert(
          name: '测试配置',
          rawHash: 'h',
          format: 'json',
          createdAt: now,
          updatedAt: now,
        ),
      );

  final repo = SiteRepository(db);
  await repo.upsert(
    SitesCompanion.insert(
      configId: Value(configId),
      siteKey: 'k',
      name: '测试源',
      typeCode: typeCode,
      runtime: 'http',
      api: api,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return repo;
}

/// 按 URL 分派的假抓取器。
class _FakeFetcher {
  _FakeFetcher(this.responses);

  final Map<String, SniffResponse> responses;
  final calls = <String>[];

  Future<SniffResponse> call(String url, Map<String, String> headers) async {
    calls.add(url);
    return responses[url] ?? const SniffResponse(statusCode: 404, body: 'nope');
  }
}

SniffResponse _playlist() => const SniffResponse(
  statusCode: 200,
  body: '#EXTM3U\n#EXTINF:10,\nseg0.ts\n',
  contentType: 'application/vnd.apple.mpegurl',
);

void main() {
  group('线路与集数定位', () {
    test('按 flag 名选中对应线路', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(_detailBody());
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(runtime),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
      );

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/1/index.m3u8',
      );
    });

    test('episodeId 是 0-based 索引', () async {
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
        episodeId: '2',
      );

      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/3/index.m3u8',
      );
    });

    test('flag 不存在时优先挑直链线路', () async {
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: '不存在的线路',
      );

      // 没有匹配的线路时按「直链优先」排序，share 网页线路让位给 m3u8。
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/1/index.m3u8',
      );
    });

    test('集数越界时回到第一集', () async {
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
        episodeId: '99',
      );

      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/1/index.m3u8',
      );
    });

    test('episodeId 非数字时回到第一集', () async {
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
        episodeId: 'abc',
      );

      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/1/index.m3u8',
      );
    });
  });

  group('嗅探接入', () {
    test('网页线路经嗅探换成真实流地址', () async {
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({
        'https://cdn.a.com/share/e1': const SniffResponse(
          statusCode: 200,
          body: '<script>var u="https://cdn.a.com/real/index.m3u8";</script>',
          contentType: 'text/html',
        ),
        'https://cdn.a.com/real/index.m3u8': _playlist(),
      });
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isTrue);
      final play = result.valueOrNull!;
      expect(
        play.mediaSource.uri.toString(),
        'https://cdn.a.com/real/index.m3u8',
      );
      expect(play.viaSniffing, isTrue);
      // 播放时要带上播放页作为 Referer，否则源站会 403。
      expect(play.mediaSource.headers['Referer'], 'https://cdn.a.com/share/e1');
    });

    test('直链线路走快路径，不触发任何抓取', () async {
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({});
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.viaSniffing, isFalse);
      expect(fetcher.calls, isEmpty);
    });

    test('站点域名作为默认 Referer', () async {
      final sites = await _sitesWith(
        api: 'https://api.a.com/api.php/provide/vod/',
      );
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
        resolver: SnifferResolver(fetcher: _FakeFetcher({}).call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
      );

      expect(
        result.valueOrNull!.mediaSource.headers['Referer'],
        'https://api.a.com/',
      );
    });

    test('唯一的网页线路嗅探失败时报错，不把播放页交给播放器', () async {
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({
        'https://cdn.a.com/share/e1': const SniffResponse(
          statusCode: 200,
          body: '<html><body>请安装插件</body></html>',
          contentType: 'text/html',
        ),
      });
      final useCase = PlayUseCase(
        sites,
        // 只有一条网页线路，没有直链可退。
        runtimeFactory: _FakeFactory(
          _FakeRuntime(
            _detailBody(
              playFrom: 'liangzi',
              playUrl: 'HD中字\$https://cdn.a.com/share/e1',
            ),
          ),
        ),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isFalse);
      expect(result.errorOrNull!.code, ErrorCode.sniffNoMatch);
    });

    test('播放页取不回来时归为 sniffPageError', () async {
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({
        'https://cdn.a.com/share/e1': const SniffResponse(
          statusCode: 403,
          body: 'forbidden',
        ),
      });
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(
          _FakeRuntime(
            _detailBody(
              playFrom: 'liangzi',
              playUrl: 'HD中字\$https://cdn.a.com/share/e1',
            ),
          ),
        ),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.errorOrNull!.code, ErrorCode.sniffPageError);
    });

    test('选中的网页线路失败时自动退到直链线路', () async {
      // 一部片多条线路、其中一条挂掉是常态；不该让用户自己回详情页切线路。
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({
        'https://cdn.a.com/share/e1': const SniffResponse(
          statusCode: 404,
          body: 'gone',
        ),
      });
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/1/index.m3u8',
      );
    });

    test('直链验证失败仍交给播放器碰运气', () async {
      // 直链地址探测不通（很多源只认播放器的 range 请求）时不应直接判死，
      // 否则可播的流会被我们自己的探测请求挡掉。
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({});
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
      );

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/1/index.m3u8',
      );
    });
  });

  group('错误路径', () {
    test('站点不存在', () async {
      final sites = await _sitesWith();
      final useCase = PlayUseCase(sites);

      final result = await useCase.getPlayableSource(
        siteId: 999,
        vodId: '42',
        flag: 'x',
      );

      expect(result.isOk, isFalse);
      expect(result.errorOrNull!.code, ErrorCode.invalidArgument);
    });

    test('detail 请求失败时把错误透传', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(
        '',
        detailError: const RemoteError(
          code: ErrorCode.networkTimeout,
          message: '超时',
        ),
      );
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(runtime),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'x',
      );

      expect(result.errorOrNull!.code, ErrorCode.networkTimeout);
    });

    test('detail 返回空列表', () async {
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(
          _FakeRuntime(jsonEncode({'code': 1, 'list': <Object?>[]})),
        ),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'x',
      );

      expect(result.errorOrNull!.code, ErrorCode.spiderParseFailed);
    });

    test('detail 不是 JSON', () async {
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime('<html>502</html>')),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'x',
      );

      expect(result.errorOrNull!.code, ErrorCode.spiderParseFailed);
    });

    test('播放地址为空', () async {
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(
          _FakeRuntime(_detailBody(playFrom: 'only', playUrl: '')),
        ),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'only',
      );

      expect(result.errorOrNull!.code, ErrorCode.spiderParseFailed);
    });
  });
}
