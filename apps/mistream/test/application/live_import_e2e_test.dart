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

  ConfigInstallService build() => ConfigInstallService(
    repositories,
    liveImporter: LiveImporter(repository: liveRepository, fetcher: fetcher),
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
}
