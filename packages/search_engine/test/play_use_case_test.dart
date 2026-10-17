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
  _FakeRuntime(
    this.detailBody, {
    this.detailError,
    this.detailThrow,
    this.disposeThrow,
    this.playBody,
    this.playThrow,
    this.playDelay,
  });

  final String detailBody;
  final AppError? detailError;

  /// 非空时 `detail` 直接抛这个异常，用来验证「异常路径也要回收运行时」。
  ///
  /// 类型是 [Error] 而非 `Object`：`only_throw_errors` 只允许抛 [Error] /
  /// [Exception] 子类，`Object?` 会让 `throw` 那两行判为告警。
  final Error? detailThrow;

  /// 非空时 `dispose` 抛这个异常，用来验证回收失败不掩盖业务结果。
  final Error? disposeThrow;

  /// `play`（= TVBox 的 `playerContent`）要返回的响应体。
  ///
  /// `null` = 这个蜘蛛没实现 `playerContent`，按 [UnimplementedError] 抛 ——
  /// 真实世界里相当一部分 HTTP 型站点就是这样，`PlayUseCase` 必须能退回旧路径。
  final String? playBody;

  /// 非空时 `play` 直接抛这个异常。
  final Error? playThrow;

  /// `play` 的耗时。用 [Future.delayed] 真的把时间花掉，否则 `timeout()`
  /// 对立刻返回的 Future 不生效，「超时后不再逐条试」这条根本测不出来。
  final Duration? playDelay;

  int detailCalls = 0;

  /// `dispose` 被调用次数：运行时回收是本文件的重点断言之一。
  int disposeCalls = 0;

  /// `play` 收到的 `(flag, ids)`，按调用先后 —— 用来断言「问过哪几条线路」。
  final List<({String flag, String ids})> playCalls =
      <({String flag, String ids})>[];

  @override
  Future<Result<HttpResponseData, AppError>> detail({
    required String ids,
  }) async {
    detailCalls++;
    final boom = detailThrow;
    if (boom != null) throw boom;
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
  }) async {
    playCalls.add((flag: flag, ids: ids));
    final boom = playThrow;
    if (boom != null) throw boom;
    final delay = playDelay;
    if (delay != null) await Future<void>.delayed(delay);
    final body = playBody;
    if (body == null) throw UnimplementedError();
    return Ok(
      HttpResponseData(
        status: 200,
        headers: const {},
        body: body,
        finalUrl: '',
        elapsedMs: 1,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    final boom = disposeThrow;
    if (boom != null) throw boom;
  }
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
  ProcessLauncher? get jsLauncher => null;

  // 假工厂手里永远有一个现成的 runtime，所以任何站点都算「有运行时」。
  @override
  bool supports({required int typeCode, required String api}) => true;

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

/// 一份**真实形态**的 detail 响应：`vod_play_url` 里放的不是 URL，而是蜘蛛
/// 自己的私有占位符。
///
/// 抄自 `csp_YunDuo` 的实测返回（片名、线路名、占位符前缀都照原样保留）：
///
///   vod_play_from = "PO蓝光$$$ZJ4K"
///   vod_play_url  = "第1集$token@PAN1-F2DH0r3KULNMgCWfhqnva_…==@PAN1
///                    $$$第1集$token@zijian_Uvhb8ej0DzhXyRJKwV1Qjg…@zijianm3u8"
///
/// 这类值**没有 scheme、没有 host**，直接交给 mpv 或嗅探器必然全灭 —— 只有
/// `playerContent` 能把它换成真地址。所以「线路解析正确」的用例不能用它，
/// 而「必须走 playerContent」的用例非用它不可。
String _tokenDetailBody() => jsonEncode({
  'code': 1,
  'list': [
    {
      'vod_id': 42,
      'vod_name': '样片',
      'vod_play_from': r'PO蓝光$$$ZJ4K',
      'vod_play_url':
          r'第1集$token@PAN1-F2DH0r3KULNMgCWfhqnva_kDl8Yy3rQ==@PAN1'
          r'$$$'
          r'第1集$token@zijian_Uvhb8ej0DzhXyRJKwV1Qjg7tPm4nA@zijianm3u8',
    },
  ],
});

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

    test('集数越界时报错，不回退到第一集', () async {
      // 回退是危险的：用户点第 99 集却看到第 1 集，且进度会记到错的位置上。
      // 该源只有 3 集，越界就该明确失败。
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

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.code, ErrorCode.notFound);
      expect(result.errorOrNull!.message, contains('第 100 集'));
    });

    test('只有部分线路缺这一集时跳过该线路，其它线路照常播', () async {
      // 各线路集数不等是常态：点第 5 集时，3 集的那条线路应当被跳过，
      // 而不是悄悄回退成「第 1 集」混进候选里。
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(
          _FakeRuntime(
            _detailBody(
              playFrom: r'short$$$full',
              playUrl:
                  r'第1集$https://cdn.a.com/short1.m3u8'
                  r'$$$'
                  r'第1集$https://cdn.a.com/f1.m3u8'
                  r'#第2集$https://cdn.a.com/f2.m3u8'
                  r'#第3集$https://cdn.a.com/f3.m3u8'
                  r'#第4集$https://cdn.a.com/f4.m3u8'
                  r'#第5集$https://cdn.a.com/f5.m3u8',
            ),
          ),
        ),
      );

      // 用户选中的是集数不足的那条（short），它没有第 5 集。
      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'short',
        episodeId: '4',
      );

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/f5.m3u8',
      );
      // 绝不能是 short 线路的第 1 集。
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        isNot('https://cdn.a.com/short1.m3u8'),
      );
    });

    test('剧集串里的空段不会让序号错位', () async {
      // 详情页与播放页都用 split('#') 的真实下标定位，空段占位但不计入集号。
      // 若详情页改回「非空剧集计数」，它会为第 3 项生成 id '1'，播放端就会取到
      // 空段并报「播放地址为空」——这个用例把两端的约定钉在一起。
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(
          _FakeRuntime(
            _detailBody(
              playFrom: 'only',
              playUrl:
                  r'第1集$https://cdn.a.com/e1.m3u8##第4集$https://cdn.a.com/e4.m3u8',
            ),
          ),
        ),
      );

      // 真实下标 2 = 第 4 集。
      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'only',
        episodeId: '2',
      );

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/e4.m3u8',
      );
    });

    test('剧集名留空（只有分隔符）时也能取到地址', () async {
      // 按「整串就是地址」处理会把 $ 一起交给播放器，那是必然打不开的地址。
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(
          _FakeRuntime(
            _detailBody(
              playFrom: 'only',
              playUrl: r'$https://cdn.a.com/noname.m3u8',
            ),
          ),
        ),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'only',
      );

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/noname.m3u8',
      );
    });

    test('episodeId 非数字时回到第一集', () async {
      // 与「越界」不同：拿不到有效集号时按第一集处理是合理的兜底。
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

  group('播放结果回填集号', () {
    test('PlayResult 带上归一后的集号', () async {
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

      expect(result.valueOrNull!.episodeIndex, const EpisodeIndex(2));
    });

    test('未指定集号时回填第一集', () async {
      // 播放页要用它写历史，不该再自己解析一遍入参。
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
      );

      expect(result.valueOrNull!.episodeIndex, EpisodeIndex.first);
    });

    test('脏集号也回填第一集', () async {
      final sites = await _sitesWith();
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(_FakeRuntime(_detailBody())),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
        episodeId: '-3',
      );

      expect(result.valueOrNull!.episodeIndex, EpisodeIndex.first);
    });
  });

  // ── 蜘蛛自己的 playerContent 是起播的第一顺位 ─────────────────────────────
  //
  // 2026-10-05 实测 `csp_YunDuo` 的 `vod_play_url` 给的是
  // `token@PAN1-F2DH0r3KULNMgCWfhqnva_…==@PAN1` —— **没有 scheme、没有 host**，
  // 是蜘蛛自己的私有占位符。旧实现把它直接交给嗅探器，于是
  // `No host specified in URI` / 请求失败，这类站点的播放**必然全灭**。
  //
  // 只有 `runtime.play(flag, ids)`（= TVBox 的 `playerContent`）能把它换成真
  // 地址，而且会**一并给出反盗链所需的 Referer**（实测 `PO蓝光` 给的是
  // `http://43.248.3.46:7788`，与站点域名完全不同）。

  group('蜘蛛 playerContent（起播第一顺位）', () {
    test('parse:0 的地址直接采用，并带上蜘蛛给的 Referer', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(
        _tokenDetailBody(),
        playBody: jsonEncode({
          'parse': 0,
          'url': 'http://43.248.3.46:7788/m3u8/pan1.php?token=abc.m3u8',
          'header': {
            'User-Agent': 'UA-from-spider',
            'Referer': 'http://43.248.3.46:7788',
          },
        }),
      );
      final fetcher = _FakeFetcher(const {});
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(runtime),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'PO蓝光',
      );

      expect(result.isOk, isTrue);
      final play = result.valueOrNull!;
      expect(
        play.mediaSource.uri.toString(),
        'http://43.248.3.46:7788/m3u8/pan1.php?token=abc.m3u8',
      );
      expect(
        play.mediaSource.headers['Referer'],
        'http://43.248.3.46:7788',
        reason: '反盗链的 Referer 只有 playerContent 给得出来，站点域名是错的',
      );
      expect(play.mediaSource.headers['User-Agent'], 'UA-from-spider');
      expect(play.viaSniffing, isFalse);
      expect(
        fetcher.calls,
        isEmpty,
        reason: 'parse:0 已经是流地址，不该再为它发一次嗅探请求',
      );
      expect(
        runtime.playCalls.single.flag,
        'PO蓝光',
        reason: '用户点的那条线路排最前，第一条就问它',
      );
    });

    test('header 是 JSON 字符串时仍采用 url，并把头解出来', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(
        _tokenDetailBody(),
        playBody: jsonEncode({
          'parse': 0,
          'url': 'https://cdn.a.com/direct/index.m3u8',
          // 实测 `csp_AppQi` 就是这个形状：header 不是对象，而是**被再编码了
          // 一次**的 JSON 字符串。旧代码 `as Map?` 抛类型错误 → 整条响应被判
          // 成脏数据，连 url 一起丢掉。
          'header': jsonEncode({
            'User-Agent': 'UA-from-spider',
            'Referer': 'https://cdn.a.com',
          }),
        }),
      );
      final fetcher = _FakeFetcher(const {});
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(runtime),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'PO蓝光',
      );

      expect(result.isOk, isTrue, reason: 'header 形状脏不该让整条线路作废');
      final play = result.valueOrNull!;
      expect(
        play.mediaSource.uri.toString(),
        'https://cdn.a.com/direct/index.m3u8',
      );
      expect(play.mediaSource.headers['Referer'], 'https://cdn.a.com');
      expect(play.mediaSource.headers['User-Agent'], 'UA-from-spider');
      expect(play.viaSniffing, isFalse);
    });

    test('parse:1 的网页地址交给嗅探链换成真实流地址', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(
        _tokenDetailBody(),
        playBody: jsonEncode({
          'parse': 1,
          'url': 'https://site.a.com/play/unknown?source=zijianm3u8',
          'header': {'Referer': 'https://site.a.com'},
        }),
      );
      final fetcher = _FakeFetcher({
        'https://site.a.com/play/unknown?source=zijianm3u8':
            const SniffResponse(
              statusCode: 200,
              body:
                  '<script>var u="https://cdn.a.com/real/index.m3u8";</script>',
              contentType: 'text/html',
            ),
        'https://cdn.a.com/real/index.m3u8': _playlist(),
      });
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(runtime),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'ZJ4K',
      );

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/real/index.m3u8',
      );
      expect(result.valueOrNull!.viaSniffing, isTrue);
    });

    test('playerContent 超时后不再逐条试，直接退回旧路径', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(
        _detailBody(),
        playDelay: const Duration(milliseconds: 200),
      );
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
        runtimeFactory: _FakeFactory(runtime),
        resolver: SnifferResolver(fetcher: fetcher.call),
        playerContentTimeout: const Duration(milliseconds: 30),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isTrue);
      expect(
        runtime.playCalls,
        hasLength(1),
        reason:
            '一次超时说明这个蜘蛛的 playerContent 根本不可用（拿空 id 做同步 HTTP '
            '是常见实现），再逐条问只是白等 6 秒 × 线路数',
      );
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/real/index.m3u8',
        reason: '超时之后仍要退回嗅探路径，不能整次起播失败',
      );
    });

    test('蜘蛛 play 抛异常只跳过该条，不终止后续线路', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(
        _detailBody(),
        playThrow: StateError('spider boom'),
      );
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
        runtimeFactory: _FakeFactory(runtime),
        resolver: SnifferResolver(fetcher: fetcher.call),
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'liangzi',
      );

      expect(result.isOk, isTrue);
      expect(
        runtime.playCalls,
        hasLength(2),
        reason:
            '抛异常只是这条线路没解析出来，不能像超时那样判「整个 playerContent '
            '不可用」—— 后一条线路仍要问',
      );
      expect(
        result.valueOrNull!.mediaSource.uri.toString(),
        'https://cdn.a.com/real/index.m3u8',
      );
    });

    test('蜘蛛没实现 playerContent 时退回旧路径（详情里的原值）', () async {
      final sites = await _sitesWith();
      // playBody 不给 → play() 抛 UnimplementedError。
      final runtime = _FakeRuntime(_detailBody());
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
        runtimeFactory: _FakeFactory(runtime),
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
        'https://cdn.a.com/real/index.m3u8',
      );
    });

    test('token 形态的候选绝不喂给嗅探器（不起浏览器、不发请求）', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(_tokenDetailBody());
      final fetcher = _FakeFetcher(const {});
      final browserCalls = <String>[];
      final useCase = PlayUseCase(
        sites,
        runtimeFactory: _FakeFactory(runtime),
        resolver: SnifferResolver(fetcher: fetcher.call),
        browserSniffer: (url, headers) async {
          browserCalls.add(url);
          return null;
        },
      );

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'PO蓝光',
      );

      expect(result.isOk, isFalse, reason: '蜘蛛没实现 playerContent，确实没有可播线路');
      expect(
        fetcher.calls,
        isEmpty,
        reason: '`token@…` 没有 host，取页面必然失败 —— 连请求都不该发',
      );
      expect(
        browserCalls,
        isEmpty,
        reason: '浏览器兜底贵得多（要起一个进程），更不能浪费在没有 host 的占位符上',
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

    test('两级都没装时也要给一个能播的原始地址：优先直链形态的候选', () async {
      final sites = await _sitesWith();
      // 线路名带 m3u8 只是名字，地址仍是 share/ 网页形态；这里验证的是
      // 「没装嗅探器时的最后退路」——**必须给出一条原始地址**，不能报错。
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
      // ⚠️ 这里刻意**不是** `candidates.first`（= 用户点的那条 `share/e1`）。
      //
      // 用户点的 `liangzi` 是**网页线路**（`/share/e1`），没有嗅探器就解不出
      // 真实流地址；而同片的 `lzm3u8` 是直链（`/1/index.m3u8`）。两者都没法
      // 验证时，把直链形态的那条原样交出去，比死守用户点的网页线路、返回一个
      // 必然打不开的地址更可能播出来。跨线路兜底本来就是既有行为（有嗅探器时
      // 也是「挨个试到第一条能用的为止」），这里只是把它延伸到「没装嗅探器」。
      expect(play.mediaSource.uri.toString(), 'https://cdn.a.com/1/index.m3u8');
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

  group('运行时回收', () {
    // type=3 的 runtime 背后是一个常驻子进程（JS 或 JVM）。漏回收不会立刻报错，
    // 只会让进程数随播放次数单调增长，所以必须在这里钉死三条路径都 dispose。
    test('成功路径：取完详情即回收', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(_detailBody());
      final useCase = PlayUseCase(sites, runtimeFactory: _FakeFactory(runtime));

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'lzm3u8',
      );

      expect(result.isOk, isTrue);
      expect(runtime.disposeCalls, 1);
    });

    test('业务失败路径：detail 返回 Err 也要回收', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(
        '',
        detailError: const RemoteError(
          code: ErrorCode.networkTimeout,
          message: '超时',
        ),
      );
      final useCase = PlayUseCase(sites, runtimeFactory: _FakeFactory(runtime));

      final result = await useCase.getPlayableSource(
        siteId: 1,
        vodId: '42',
        flag: 'x',
      );

      expect(result.isErr, isTrue);
      expect(runtime.disposeCalls, 1);
    });

    test('异常路径：detail 抛异常也要回收', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime('', detailThrow: StateError('子进程崩了'));
      final useCase = PlayUseCase(sites, runtimeFactory: _FakeFactory(runtime));

      try {
        await useCase.getPlayableSource(siteId: 1, vodId: '42', flag: 'x');
      } on Object {
        // 异常是否被归一化成 AppError 不在本用例范围内，这里只关心回收。
      }

      expect(runtime.disposeCalls, 1);
    });

    test('回收抛异常不掩盖业务结果', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(
        _detailBody(),
        disposeThrow: StateError('回收失败'),
      );
      final useCase = PlayUseCase(sites, runtimeFactory: _FakeFactory(runtime));

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
      expect(runtime.disposeCalls, 1);
    });

    test('站点不存在时不创建运行时（没有可泄漏的对象）', () async {
      final sites = await _sitesWith();
      final runtime = _FakeRuntime(_detailBody());
      final useCase = PlayUseCase(sites, runtimeFactory: _FakeFactory(runtime));

      final result = await useCase.getPlayableSource(
        siteId: 999,
        vodId: '42',
        flag: 'x',
      );

      expect(result.isErr, isTrue);
      expect(runtime.detailCalls, 0);
      expect(runtime.disposeCalls, 0);
    });
  });
}
