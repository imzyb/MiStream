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
  int detailCalls = 0;

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
      r'HD中字$https://cdn.a.com/share/e1'
          r'#第2集$https://cdn.a.com/share/e2'
          r'#第3集$https://cdn.a.com/share/e3'
          r'$$$'
          r'HD中字$https://cdn.a.com/1/index.m3u8'
          r'#第2集$https://cdn.a.com/2/index.m3u8'
          r'#第3集$https://cdn.a.com/3/index.m3u8';
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
      final sites = await _sitesWith();
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
              playUrl: r'HD中字$https://cdn.a.com/share/e1',
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
              playUrl: r'HD中字$https://cdn.a.com/share/e1',
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

  group('浏览器嗅探兜底', () {
    /// 静态 HTML 里没有任何媒体地址，只有一段会在运行时拼地址的脚本。
    const staticMissPage = '<html><body><div id="p"></div></body></html>';

    test('静态嗅探没命中时，用浏览器嗅探拿到的地址起播', () async {
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({
        'https://cdn.a.com/share/e1': const SniffResponse(
          statusCode: 200,
          body: staticMissPage,
          contentType: 'text/html',
        ),
      });
      final browserCalls = <String>[];
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
        resolver: SnifferResolver(fetcher: fetcher.call),
        browserSniffer: (url, headers) async {
          browserCalls.add(url);
          return 'https://cdn.a.com/dynamic/index.m3u8';
        },
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
        'https://cdn.a.com/dynamic/index.m3u8',
      );
      expect(play.viaSniffing, isTrue);
      // 播放大体上还是要带播放页作 Referer。
      expect(play.mediaSource.headers['Referer'], 'https://cdn.a.com/share/e1');
      expect(browserCalls, <String>['https://cdn.a.com/share/e1']);
    });

    test('静态嗅探已命中时不起浏览器（不做预判性调用）', () async {
      // 起浏览器是秒级开销，绝大多数线路静态 HTML 里就有地址，不该白花这钱。
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({
        'https://cdn.a.com/share/e1': const SniffResponse(
          statusCode: 200,
          body: '<script>var u="https://cdn.a.com/real/index.m3u8";</script>',
          contentType: 'text/html',
        ),
        'https://cdn.a.com/real/index.m3u8': _playlist(),
      });
      var browserCalls = 0;
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
        resolver: SnifferResolver(fetcher: fetcher.call),
        browserSniffer: (url, headers) async {
          browserCalls++;
          return null;
        },
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isTrue);
      expect(browserCalls, 0);
    });

    test('浏览器也没嗅到时，网页地址不会丢给播放器', () async {
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({
        'https://cdn.a.com/share/e1': const SniffResponse(
          statusCode: 200,
          body: staticMissPage,
          contentType: 'text/html',
        ),
      });
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(
          // 只用一条线路，把「两级都失败」这条路径隔离开。默认 detail 里还有
          // 第二条直链线路，回退链会切过去并成功，测不到想要的分支。
          _FakeRuntime(
            _detailBody(
              playFrom: 'liangzi',
              playUrl: r'HD中字$https://cdn.a.com/share/e1',
            ),
          ),
        ),
        resolver: SnifferResolver(fetcher: fetcher.call),
        browserSniffer: (url, headers) async => null,
      );

      // 网页线路（非 m3u8 形态）两级都失败时应报错，而不是把网页地址丢给播放器。
      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isFalse);
      expect(result.errorOrNull!.code, ErrorCode.sniffNoMatch);
    });

    test('浏览器返回空串等同于没嗅到', () async {
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({
        'https://cdn.a.com/share/e1': const SniffResponse(
          statusCode: 200,
          body: staticMissPage,
          contentType: 'text/html',
        ),
      });
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(
          _FakeRuntime(
            _detailBody(
              playFrom: 'liangzi',
              playUrl: r'HD中字$https://cdn.a.com/share/e1',
            ),
          ),
        ),
        resolver: SnifferResolver(fetcher: fetcher.call),
        browserSniffer: (url, headers) async => '',
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isFalse);
    });

    test('只装浏览器嗅探器（无静态嗅探）也能工作', () async {
      // 回退链不该因为少装一级而断掉。
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
        browserSniffer: (url, headers) async =>
            'https://cdn.a.com/only-dynamic/index.m3u8',
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/only-dynamic/index.m3u8',
      );
    });

    test('多线路：前一条两级都失败时继续试下一条', () async {
      final sites = await _sitesWith();
      final fetcher = _FakeFetcher({
        'https://cdn.a.com/share/dead': const SniffResponse(
          statusCode: 200,
          body: staticMissPage,
          contentType: 'text/html',
        ),
        'https://cdn.a.com/share/alive': const SniffResponse(
          statusCode: 200,
          body: staticMissPage,
          contentType: 'text/html',
        ),
      });
      final browserCalls = <String>[];
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(
          _FakeRuntime(
            // 两条线路用 $$$ 分隔；用户点的是第一条（dead）。
            _detailBody(
              playFrom: r'liangzi$$$liangzi2',
              playUrl:
                  r'HD中字$https://cdn.a.com/share/dead'
                  r'$$$'
                  r'HD中字$https://cdn.a.com/share/alive',
            ),
          ),
        ),
        resolver: SnifferResolver(fetcher: fetcher.call),
        browserSniffer: (url, headers) async {
          browserCalls.add(url);
          return url.endsWith('alive')
              ? 'https://cdn.a.com/alive/index.m3u8'
              : null;
        },
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/alive/index.m3u8',
      );
      // 用户点的那条排最前，所以先试 dead、再试 alive。
      expect(browserCalls, <String>[
        'https://cdn.a.com/share/dead',
        'https://cdn.a.com/share/alive',
      ]);
    });

    test('两级都没装时保持旧行为，原地址直接返回', () async {
      final sites = await _sitesWith();
      // 线路名带 m3u8 只是名字，地址仍是 share/ 网页形态；这里验证的是
      // 「没装嗅探就原样返回」这条向后兼容路径。
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isTrue);
      final play = result.valueOrNull!;
      expect(play.mediaSource.uri.toString(), 'https://cdn.a.com/share/e1');
      expect(play.viaSniffing, isFalse);
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
