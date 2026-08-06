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
  });
}
