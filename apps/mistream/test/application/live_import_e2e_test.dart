/// 「导入含 `lives` 的配置 → 频道列表正确分组」的端到端验证（**数据面**）。
///
/// 覆盖从**配置文本**到**分组视图**的完整链路：
///
/// ```
/// ConfigParser.parse → LiveConfig
///   → LiveSubscription → LiveImporter（拉取 → 解析 → 合并）
///   → DriftLiveRepository → getChannelsByGroup
/// ```
///
/// 刻意不引 `flutter_test`、不起回环：本环境跑不了 widget 测试，也禁止本地
/// 回环（`config_install_service_test.dart` 两条都占，所以进不了进程内垫片）。
/// 这里验证的是**数据对不对**，不是**画得对不对** —— UI 渲染归 Flutter 管。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:core_config/core_config.dart';
import 'package:live/live.dart';
import 'package:mistream/application/config_install_service.dart';
import 'package:mistream/application/live_epg_settings.dart';
import 'package:storage/storage.dart' as db;
import 'package:test/test.dart';

/// 一份贴近真实的配置：`lives` 里既有相对地址也有绝对地址，
/// 还带着 `logo` 模板 —— 字段形状抄自实测的 `gaotianliuyun/gao` 0821.json。
const _configJson = '''
{
  "sites": [
    {"key": "s1", "name": "站点1", "type": 1, "api": "http://api.example/"}
  ],
  "lives": [
    {
      "name": "央视组",
      "type": 0,
      "url": "./cctv.txt",
      "logo": "https://logo.example/tv/{name}.png",
      "epg": "http://epg.example/?ch={name}"
    },
    {"name": "卫视组", "type": 0, "url": "https://b.example/satellite.txt"}
  ]
}
''';

const _cctvTxt = '''
央视频道,#genre#
CCTV1,http://a/1.m3u8
CCTV1,http://a/2.m3u8
CCTV2,http://a/3.m3u8
''';

const _satelliteTxt = '''
卫视频道,#genre#
湖南卫视,http://b/1.m3u8
''';

/// 一份 EPG 接口响应（字段抄自 `epg.51zmt.top` 实测）。
const _epgJson = '''
{"channel_name": "CCTV-1综合", "date": "2026-10-01",
 "epg_data": [{"start": "01:03", "end": "01:47", "title": "新闻30分"}]}
''';

void main() {
  late db.AppDatabase database;
  late db.Repositories repositories;
  late DriftLiveRepository liveRepository;
  late List<String> requested;
  late Map<String, String> bodies;

  setUp(() {
    database = db.AppDatabase.inMemory();
    repositories = db.Repositories(database);
    liveRepository = DriftLiveRepository(database);
    requested = [];
    bodies = {};
  });

  tearDown(() => database.close());

  Future<String> fetcher(String url, {String? userAgent}) async {
    requested.add(url);
    final body = bodies[url];
    if (body == null) throw StateError('拉不到 $url');
    return body;
  }

  ConfigInstallService build({EpgFetcher? epgFetcher}) => ConfigInstallService(
    repositories,
    liveImporter: LiveImporter(repository: liveRepository, fetcher: fetcher),
    epgFetcher: epgFetcher,
  );

  Future<ConfigImportResult> parseConfig() async {
    final result = ConfigImportService.import(
      Uint8List.fromList(utf8.encode(_configJson)),
    );
    expect(result.isOk, isTrue, reason: '测试夹具本身得是合法配置');
    return result.valueOrNull!;
  }

  test('导入配置后频道按分组落库，相对地址被解析', () async {
    bodies['https://cfg.example/d/cctv.txt'] = _cctvTxt;
    bodies['https://b.example/satellite.txt'] = _satelliteTxt;

    final result = await parseConfig();
    final installed = await build().install(
      result,
      sourceUrl: 'https://cfg.example/d/0821.json',
    );

    expect(installed, 1, reason: '站点数照旧返回');

    // `./cctv.txt` 必须被解析成配置同目录，否则会去请求一个 404 地址。
    expect(requested, contains('https://cfg.example/d/cctv.txt'));

    final byGroup = await liveRepository.getChannelsByGroup();
    expect(byGroup.keys.map((g) => g.name).toSet(), {'央视频道', '卫视频道'});
    expect(
      byGroup.values.fold<int>(0, (sum, list) => sum + list.length),
      3,
      reason: 'CCTV1 的两条地址合并成一个频道',
    );
  });

  test('多地址在落库后仍然完整（换台才有备用线路可试）', () async {
    bodies['https://cfg.example/d/cctv.txt'] = _cctvTxt;
    bodies['https://b.example/satellite.txt'] = _satelliteTxt;

    await build().install(
      await parseConfig(),
      sourceUrl: 'https://cfg.example/d/0821.json',
    );

    final cctv1 = (await liveRepository.getChannels()).firstWhere(
      (c) => c.name == 'CCTV1',
    );
    expect(cctv1.allUrls, ['http://a/1.m3u8', 'http://a/2.m3u8']);
  });

  test('订阅的 logo 模板展开到频道图标', () async {
    bodies['https://cfg.example/d/cctv.txt'] = _cctvTxt;
    bodies['https://b.example/satellite.txt'] = _satelliteTxt;

    await build().install(
      await parseConfig(),
      sourceUrl: 'https://cfg.example/d/0821.json',
    );

    final channels = await liveRepository.getChannels();
    final cctv1 = channels.firstWhere((c) => c.name == 'CCTV1');
    expect(cctv1.logo, 'https://logo.example/tv/CCTV1.png');

    // 卫视组那份订阅没写 logo 模板，不该凭空长出图标。
    final hunan = channels.firstWhere((c) => c.name == '湖南卫视');
    expect(hunan.logo, isNull);
  });

  test('站点照样落库（直播是附加项，不替代站点）', () async {
    bodies['https://cfg.example/d/cctv.txt'] = _cctvTxt;
    bodies['https://b.example/satellite.txt'] = _satelliteTxt;

    await build().install(
      await parseConfig(),
      sourceUrl: 'https://cfg.example/d/0821.json',
    );

    final sites = await repositories.sites.enabled();
    expect(sites.map((s) => s.name), contains('站点1'));
  });

  test('直播源全部拉不到时，配置导入仍然成功', () async {
    // 一个 body 都不给 → 两个源都失败。
    final result = await parseConfig();

    final installed = await build().install(
      result,
      sourceUrl: 'https://cfg.example/d/0821.json',
    );

    expect(installed, 1, reason: '直播源挂了不该让整份配置导入失败');
    expect(await repositories.sites.enabled(), hasLength(1));
    expect(await liveRepository.getChannels(), isEmpty);
  });

  test('配置里没有 lives 时不报错也不写频道', () async {
    // 注意：`ConfigImportService` 要求至少有一个站点（空 sites 会判
    // `configEmpty`），所以夹具里得留一个站点。
    final result = ConfigImportService.import(
      Uint8List.fromList(
        utf8.encode(
          '{"sites": [{"key": "s", "name": "S", "type": 1, "api": "http://x/"}]}',
        ),
      ),
    );

    await build().install(result.valueOrNull!);

    expect(await liveRepository.getChannels(), isEmpty);
    expect(requested, isEmpty, reason: '没有 lives 就不该去拉直播源');
  });

  test('没有注入 liveImporter 时跳过 lives（不影响站点安装）', () async {
    final service = ConfigInstallService(repositories);
    final result = await parseConfig();

    final installed = await service.install(result);

    expect(installed, 1);
    expect(requested, isEmpty, reason: '没配 importer 就不该去拉直播源');
  });

  test('导入配置时 EPG 模板当场接进拉取器', () async {
    bodies['https://cfg.example/d/cctv.txt'] = _cctvTxt;
    bodies['https://b.example/satellite.txt'] = _satelliteTxt;
    bodies['http://epg.example/?ch=CCTV1'] = _epgJson;

    final epgFetcher = EpgFetcher(fetcher: (url) => fetcher(url));
    expect(epgFetcher.hasTemplates, isFalse, reason: '装配时还没有模板');

    await build(epgFetcher: epgFetcher).install(
      await parseConfig(),
      sourceUrl: 'https://cfg.example/d/0821.json',
    );

    // 配置里的 `epg` 是含 `{name}` 的模板，不是能直接请求的地址。
    expect(epgFetcher.templates, ['http://epg.example/?ch={name}']);

    final epg = await epgFetcher.loadFor('1', 'CCTV1');
    expect(epg, isNotNull);
    expect(epg!.programs.single.title, '新闻30分');
  });

  test('重启后从设置恢复 EPG 模板，节目单仍能拉到', () async {
    bodies['https://cfg.example/d/cctv.txt'] = _cctvTxt;
    bodies['https://b.example/satellite.txt'] = _satelliteTxt;
    bodies['http://epg.example/?ch=CCTV1'] = _epgJson;

    await build().install(
      await parseConfig(),
      sourceUrl: 'https://cfg.example/d/0821.json',
    );

    // 配置原文不入库，模板是单独存的一份 —— 不存的话重启后 EPG 就没了。
    expect(await loadLiveEpgTemplates(repositories.settings), [
      'http://epg.example/?ch={name}',
    ]);

    // 模拟重启：全新的拉取器 + 从设置恢复的模板。
    final restarted = EpgFetcher(
      fetcher: (url) => fetcher(url),
      templates: await loadLiveEpgTemplates(repositories.settings),
    );
    final epg = await restarted.loadFor('1', 'CCTV1');
    expect(epg, isNotNull);
    expect(epg!.programs, hasLength(1));
  });

  test('配置里没有 epg 时清掉上一份配置留下的模板', () async {
    bodies['https://cfg.example/d/cctv.txt'] = _cctvTxt;
    bodies['https://b.example/satellite.txt'] = _satelliteTxt;

    await build().install(
      await parseConfig(),
      sourceUrl: 'https://cfg.example/d/0821.json',
    );
    expect(await loadLiveEpgTemplates(repositories.settings), isNotEmpty);

    // 第二份配置有 lives，但没写 epg。
    final second = ConfigImportService.import(
      Uint8List.fromList(
        utf8.encode(
          '{"sites":[{"key":"s","name":"S","type":1,"api":"http://x/"}],'
          '"lives":[{"name":"卫视组","url":"https://b.example/satellite.txt"}]}',
        ),
      ),
    );
    await build().install(
      second.valueOrNull!,
      sourceUrl: 'https://cfg.example/d/2.json',
    );

    // 配置是模板的唯一权威来源：留着上一份的模板会去拉一个早就换掉的接口。
    expect(await loadLiveEpgTemplates(repositories.settings), isEmpty);
  });
}
