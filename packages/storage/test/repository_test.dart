import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:storage/src/database/database.dart';
import 'package:storage/src/repository/repositories.dart';
import 'package:test/test.dart';

void main() {
  group('HistoryRepository', () {
    late AppDatabase db;
    late Repositories repos;

    setUp(() async {
      db = AppDatabase.inMemory();
      await db.customStatement('PRAGMA foreign_keys = OFF');
      repos = Repositories(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('upsert 插入新历史并可读回', () async {
      final h = await repos.histories.upsert(
        siteId: 1,
        vodId: 'v1',
        vodName: '剧A',
        episodeIndex: 2,
        positionMs: 5000,
        durationMs: 60000,
      );
      expect(h.id, greaterThan(0));
      expect(h.episodeIndex, 2);
      expect(h.positionMs, 5000);
    });

    test('upsert 同 (site, vod) 更新而不是新增', () async {
      await repos.histories.upsert(siteId: 1, vodId: 'v1', vodName: '剧A');
      final again = await repos.histories.upsert(
        siteId: 1,
        vodId: 'v1',
        vodName: '剧A',
        positionMs: 999,
      );
      expect(again.positionMs, 999);
      expect(await repos.histories.recent(), hasLength(1));
    });

    test('recent 按 playedAt 倒序且限长', () async {
      await repos.histories.upsert(
        siteId: 1,
        vodId: 'a',
        vodName: '早',
        playedAt: DateTime.utc(2026),
      );
      await repos.histories.upsert(
        siteId: 1,
        vodId: 'b',
        vodName: '晚',
        playedAt: DateTime.utc(2026, 2),
      );
      final recent = await repos.histories.recent();
      expect(recent.map((e) => e.vodId).toList(), ['b', 'a']);
      expect(await repos.histories.recent(limit: 1), hasLength(1));
    });

    test('deleteVod / clear', () async {
      await repos.histories.upsert(siteId: 1, vodId: 'v1', vodName: '剧A');
      await repos.histories.deleteVod(1, 'v1');
      expect(await repos.histories.byVod(1, 'v1'), isNull);
      await repos.histories.upsert(siteId: 2, vodId: 'v2', vodName: '剧B');
      await repos.histories.clear();
      expect(await repos.histories.recent(), isEmpty);
    });
  });

  group('FavoriteRepository', () {
    late AppDatabase db;
    late Repositories repos;

    setUp(() async {
      db = AppDatabase.inMemory();
      await db.customStatement('PRAGMA foreign_keys = OFF');
      repos = Repositories(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('add 后 isFavorite / byVod 命中，重复 add 不重复插入', () async {
      await repos.favorites.add(siteId: 1, vodId: 'v1', vodName: '剧A');
      expect(await repos.favorites.isFavorite(1, 'v1'), isTrue);
      await repos.favorites.add(
        siteId: 1,
        vodId: 'v1',
        vodName: '剧A',
        vodRemarks: '更新',
      );
      expect(await repos.favorites.byFolder(''), hasLength(1));
      expect((await repos.favorites.byVod(1, 'v1'))?.vodRemarks, '更新');
    });

    test('remove 返回是否删掉', () async {
      await repos.favorites.add(siteId: 1, vodId: 'v1', vodName: '剧A');
      expect(await repos.favorites.remove(1, 'v1'), isTrue);
      expect(await repos.favorites.isFavorite(1, 'v1'), isFalse);
      expect(await repos.favorites.remove(1, 'v1'), isFalse);
    });

    test('markChecked 标记最近检查状态', () async {
      await repos.favorites.add(siteId: 1, vodId: 'v1', vodName: '剧A');
      await repos.favorites.markChecked(1, 'v1', latestRemarks: '已更新到12');
      final f = await repos.favorites.byVod(1, 'v1');
      expect(f?.latestRemarks, '已更新到12');
    });

    test('folders 去重列出', () async {
      await repos.favorites.add(
        siteId: 1,
        vodId: 'a',
        vodName: 'A',
        folder: '追',
      );
      await repos.favorites.add(
        siteId: 1,
        vodId: 'b',
        vodName: 'B',
        folder: '追',
      );
      await repos.favorites.add(siteId: 1, vodId: 'c', vodName: 'C');
      expect(await repos.favorites.folders(), ['', '追']);
    });
  });

  group('SearchHistoryRepository', () {
    late AppDatabase db;
    late Repositories repos;

    setUp(() async {
      db = AppDatabase.inMemory();
      await db.customStatement('PRAGMA foreign_keys = OFF');
      repos = Repositories(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('record 首次插入 hit=1，重复命中自增', () async {
      await repos.searchHistories.record('海贼王');
      await repos.searchHistories.record('海贼王');
      final rows = await repos.searchHistories.recent();
      expect(rows, hasLength(1));
      expect(rows.single.hitCount, 2);
    });

    test('recent 按 lastAt 倒序', () async {
      await repos.searchHistories.record('甲', at: DateTime.utc(2026));
      await repos.searchHistories.record('乙', at: DateTime.utc(2026, 2));
      final rows = await repos.searchHistories.recent();
      expect(rows.map((e) => e.keyword).toList(), ['乙', '甲']);
    });

    test('remove / clear', () async {
      await repos.searchHistories.record('甲');
      await repos.searchHistories.remove('甲');
      expect(await repos.searchHistories.recent(), isEmpty);
    });
  });

  group('SiteRepository 与 ConfigSourceRepository', () {
    late AppDatabase db;
    late Repositories repos;

    setUp(() async {
      db = AppDatabase.inMemory();
      await db.customStatement('PRAGMA foreign_keys = OFF');
      repos = Repositories(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('configSource add/byId/all', () async {
      final id = await repos.configSources.add(
        ConfigSourcesCompanion.insert(
          name: '我的源',
          rawHash: 'abc',
          format: 'plain',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(id, greaterThan(0));
      expect((await repos.configSources.byId(id))?.name, '我的源');
      expect(await repos.configSources.all(), hasLength(1));
    });

    test('site upsert 无 id 插入并回读自增 id；带 id 覆盖', () async {
      final s1 = await repos.sites.upsert(
        SitesCompanion.insert(
          configId: const Value(1),
          siteKey: 'ks',
          name: '站点A',
          typeCode: 1,
          runtime: 'js',
          api: '/api.php',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(s1.id, greaterThan(0));

      final s2 = await repos.sites.upsert(
        SitesCompanion.insert(
          id: Value(s1.id),
          configId: const Value(1),
          siteKey: 'ks',
          name: '站点A改',
          typeCode: 1,
          runtime: 'js',
          api: '/api.php',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(s2.id, s1.id);
      expect(s2.name, '站点A改');
      final byConfig = await repos.sites.byConfig(1);
      expect(byConfig, hasLength(1));
      expect(byConfig.single.name, '站点A改');
    });

    test('configSourceSpider 返回站点所属配置源的 spider jar URL', () async {
      final configId = await repos.configSources.add(
        ConfigSourcesCompanion.insert(
          name: '带jar源',
          rawHash: 'abc',
          format: 'plain',
          spider: const Value('https://example.com/fan.jar'),
          spiderMd5: const Value('d41d8cd98f00b204e9800998ecf8427e'),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      final site = await repos.sites.upsert(
        SitesCompanion.insert(
          configId: Value(configId),
          siteKey: 'csp_fan',
          name: '蜘蛛源',
          typeCode: 3,
          runtime: 'jvm',
          api: 'csp_Fan',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(
        await repos.sites.configSourceSpider(site.id),
        'https://example.com/fan.jar',
      );
      expect(await repos.sites.configSourceUrl(site.id), isNull);
    });
  });

  group('SiteRepository · spider jar 地址解析', () {
    late AppDatabase db;
    late Repositories repos;

    setUp(() async {
      db = AppDatabase.inMemory();
      await db.customStatement('PRAGMA foreign_keys = OFF');
      repos = Repositories(db);
    });

    tearDown(() async {
      await db.close();
    });

    /// 建一个配置源 + 一个 `csp_` 站点，返回站点 id。
    Future<int> seed({String? url, String? spider, String? spiderMd5}) async {
      final configId = await repos.configSources.add(
        ConfigSourcesCompanion.insert(
          name: '源',
          url: Value(url),
          rawHash: 'h',
          format: 'plain',
          spider: Value(spider),
          spiderMd5: Value(spiderMd5),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      final site = await repos.sites.upsert(
        SitesCompanion.insert(
          configId: Value(configId),
          siteKey: 'csp_fan',
          name: '蜘蛛源',
          typeCode: 3,
          runtime: 'jvm',
          api: 'csp_Fan',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      return site.id;
    }

    /// 回归：首页「所有站点均无法连接」的真实根因。
    ///
    /// `qist/tvbox` 的 `xiaosa/api.json` 写的是
    /// `"spider": "./spider.jar;md5;af187…"`。修前 [configSourceSpider] 原样
    /// 返回这一整串，下游 `JvmRuntimeFactory._ensureJar` 见它不是 http(s) 就当
    /// **本地文件路径**去找，抛 `spider jar 不存在: ./spider.jar`；该配置 105 个
    /// `csp_` 站点因此全部取数失败。
    test('相对路径 + 内联 md5：解析成配置源同目录的绝对 URL', () async {
      const configUrl =
          'https://raw.githubusercontent.com/qist/tvbox/refs/heads/master/xiaosa/api.json';
      final id = await seed(
        url: configUrl,
        spider: './spider.jar;md5;af187c2a2be1bcbb5e183d77e740b21b',
      );
      expect(
        await repos.sites.configSourceSpider(id),
        'https://raw.githubusercontent.com/qist/tvbox/refs/heads/master/'
        'xiaosa/spider.jar',
      );
      // 内联的 md5 **故意不采纳**：它和内联 URL 同龄，上游换过 jar 之后一样
      // 过期（实测 af187c2a… → abc13bea…）。采纳它等于拿一个已知过期的期望值
      // 去卡住一次本来能成功的下载。返回 null = 本次不校验。
      expect(await repos.sites.configSourceSpiderMd5(id), isNull);
    });

    /// 2026-09-25 之后导入的行：`parseSpiderField` 已把 md5 拆进列里，
    /// `spider` 只剩相对路径。这条同样要解析——不能只在「带 md5 后缀」时动手。
    test('已拆分的相对路径：同样解析（md5 走列）', () async {
      final id = await seed(
        url: 'https://example.com/a/b/api.json',
        spider: './spider.jar',
        spiderMd5: 'abc123',
      );
      expect(
        await repos.sites.configSourceSpider(id),
        'https://example.com/a/b/spider.jar',
      );
      expect(await repos.sites.configSourceSpiderMd5(id), 'abc123');
    });

    test('绝对 URL 原样返回，内联 md5 段不混进 URL', () async {
      final id = await seed(
        url: 'https://example.com/api.json',
        spider: 'https://cdn.example.com/fan.jar;md5;deadbeef',
      );
      expect(
        await repos.sites.configSourceSpider(id),
        'https://cdn.example.com/fan.jar',
      );
      expect(await repos.sites.configSourceSpiderMd5(id), isNull);
    });

    /// 本地文件 / Base64 / 剪贴板导入的配置源没有 http(s) base，无从解析——
    /// 原样交给下游按本地路径处理，不要硬拼出一个假地址。
    test('配置源非 http(s)：原样返回，不硬拼 base', () async {
      final id = await seed(url: r'C:\conf\api.json', spider: './spider.jar');
      expect(await repos.sites.configSourceSpider(id), './spider.jar');
    });

    test('配置源 url 为 null：原样返回', () async {
      final id = await seed(spider: './spider.jar');
      expect(await repos.sites.configSourceSpider(id), './spider.jar');
    });

    test('spider 为空或纯空白：返回 null', () async {
      expect(
        await repos.sites.configSourceSpider(await seed(spider: '')),
        isNull,
      );
      expect(
        await repos.sites.configSourceSpider(await seed(spider: '   ')),
        isNull,
      );
      expect(await repos.sites.configSourceSpider(await seed()), isNull);
    });

    // 插件站点（`config_id` 为 null）没有配置源可查：innerJoin 一行都连不上，
    // 必须**返回 null** 而不是抛 —— 调用方拿 null 就当「无 jar 可用」继续走。
    test('站点无配置源（插件站点）：返回 null，而不是抛异常', () async {
      final site = await repos.sites.upsert(
        SitesCompanion.insert(
          pluginId: const Value('plugin_a'),
          siteKey: 'plugin_x',
          name: '插件站点',
          typeCode: 1,
          runtime: 'http',
          api: 'https://example.com/api.php',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(await repos.sites.configSourceSpider(site.id), isNull);
      expect(await repos.sites.configSourceSpiderMd5(site.id), isNull);
    });
  });
}
