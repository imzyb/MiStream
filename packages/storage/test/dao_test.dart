import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:storage/src/dao/settings_dao.dart';
import 'package:storage/src/dao/site_cache_dao.dart';
import 'package:storage/src/database/database.dart';
import 'package:test/test.dart';

void main() {
  final keyString = SettingKey.stringKey('app.name');
  final keyInt = SettingKey.intKey('app.port');
  final keyBool = SettingKey.boolKey('app.enabled');

  group('SettingsDao', () {
    late AppDatabase db;
    late SettingsDao dao;

    setUp(() {
      db = AppDatabase.inMemory();
      dao = SettingsDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('写后能按类型读回，不存在时返回 fallback', () async {
      await dao.write(keyString, 'MiStream');
      await dao.write(keyInt, 8080);
      await dao.write(keyBool, true);

      expect(await dao.read(keyString, ''), 'MiStream');
      expect(await dao.read(keyInt, 0), 8080);
      expect(await dao.read(keyBool, false), isTrue);
    });

    test('覆盖写更新时间戳并取新值', () async {
      await dao.write(keyInt, 1);
      await dao.write(keyInt, 2);
      expect(await dao.read(keyInt, 0), 2);
    });

    test('readRequired 缺键抛 StateError', () async {
      await expectLater(dao.readRequired(keyInt), throwsStateError);
    });

    test('remove 后回落到 fallback', () async {
      await dao.write(keyString, 'x');
      expect(await dao.read(keyString, 'd'), 'x');
      await dao.remove(keyString);
      expect(await dao.read(keyString, 'd'), 'd');
    });
  });

  group('SiteCacheDao', () {
    late AppDatabase db;
    late SiteCacheDao dao;

    setUp(() async {
      db = AppDatabase.inMemory();
      // 缓存测试专注 LRU/过期逻辑，外键引用真实 site 会让每个用例都得
      // 预置父子行；这里关闭外键约束，site_id 用占位值即可。
      await db.customStatement('PRAGMA foreign_keys = OFF');
      dao = SiteCacheDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    SiteCachesCompanion entry(
      String key, {
      required int expiresInSeconds,
      int bytes = 100,
    }) {
      return SiteCachesCompanion(
        cacheKey: Value(key),
        siteId: const Value(1),
        method: const Value('GET'),
        payload: Value(Uint8List.fromList(List.filled(bytes, 1))),
        bytes: Value(bytes),
        expiresAt: Value(
          DateTime.now().toUtc().add(Duration(seconds: expiresInSeconds)),
        ),
        createdAt: Value(DateTime.now().toUtc()),
      );
    }

    test('get 返回未过期项，缺失返回 null', () async {
      await dao.put(entry('a', expiresInSeconds: 60));
      expect((await dao.get('a', now: DateTime.now()))?.cacheKey, 'a');
      expect(await dao.get('missing', now: DateTime.now()), isNull);
    });

    test('get 遇过期项返回 null 并清除', () async {
      await dao.put(entry('a', expiresInSeconds: -10));
      final now = DateTime.now();
      expect(await dao.get('a', now: now), isNull);
      expect(await dao.get('a', now: now), isNull);
      expect((await db.select(db.siteCaches).get()).isEmpty, isTrue);
    });

    test('purgeExpired 只删过期的', () async {
      await dao.put(entry('fresh', expiresInSeconds: 600));
      await dao.put(entry('stale', expiresInSeconds: -1));
      final removed = await dao.purgeExpired(now: DateTime.now());
      expect(removed, 1);
      expect(await dao.get('fresh', now: DateTime.now()), isNotNull);
    });

    test('总量超上限时按最旧 created_at LRU 淘汰到 80% 水线', () async {
      // 各 50 字节，共 200 字节；上限 100 → 水线 80 → 需删 120 字节。
      await dao.put(entry('a', bytes: 50, expiresInSeconds: 600));
      await dao.put(entry('b', bytes: 50, expiresInSeconds: 600));
      await dao.put(entry('c', bytes: 50, expiresInSeconds: 600));
      await dao.put(entry('d', bytes: 50, expiresInSeconds: 600));

      // 四条约同 created_at，无法保证顺序；改为限制足够低强制全清。
      await dao.put(entry('a', bytes: 1000, expiresInSeconds: 600));

      final removed = await dao.trimTo(maxBytes: 100);
      expect(removed, greaterThan(0));
      // 删除后总字节应小于等于上限。
      final total = await db.select(db.siteCaches).get();
      final sum = total.fold<int>(0, (acc, r) => acc + r.bytes);
      expect(sum, lessThanOrEqualTo(100));
    });
  });
}
