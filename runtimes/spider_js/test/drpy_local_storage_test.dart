import 'package:storage/src/database/database.dart';
import 'package:storage/src/dao/plugin_storage_dao.dart';
import 'package:spider_js/src/drpy/local_storage.dart';
import 'package:test/test.dart';

void main() {
  group('LocalStorage', () {
    late AppDatabase db;
    late PluginStorageDao dao;
    late LocalStorage storage;

    setUp(() {
      db = AppDatabase.inMemory();
      dao = PluginStorageDao(db);
      storage = LocalStorage(dao, 'site:1');
    });

    tearDown(() async {
      await db.close();
    });

    test('set 后 get 可读回', () async {
      await storage.set('key1', 'value1');
      expect(await storage.get('key1'), 'value1');
    });

    test('覆盖写更新值', () async {
      await storage.set('key', 'v1');
      await storage.set('key', 'v2');
      expect(await storage.get('key'), 'v2');
    });

    test('delete 后返回 null', () async {
      await storage.set('key', 'value');
      await storage.delete('key');
      expect(await storage.get('key'), isNull);
    });

    test('不存在的 key 返回 null', () async {
      expect(await storage.get('nonexistent'), isNull);
    });

    test('不同 owner 隔离', () async {
      final s1 = LocalStorage(dao, 'site:1');
      final s2 = LocalStorage(dao, 'site:2');
      await s1.set('key', 'from-1');
      await s2.set('key', 'from-2');
      expect(await s1.get('key'), 'from-1');
      expect(await s2.get('key'), 'from-2');
    });

    test('totalBytes 返回正确字节数', () async {
      await storage.set('a', 'hello');
      await storage.set('b', 'world');
      expect(await storage.totalBytes(), 10);
    });
  });
}
