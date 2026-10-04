import 'package:source_adapter/source_adapter.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

void main() {
  group('PluginStorageHost', () {
    late AppDatabase db;
    late PluginStorageHost storage;

    setUp(() {
      db = AppDatabase.inMemory();
      storage = PluginStorageHost(PluginStorageDao(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('set 后 get 可读回', () async {
      await storage.set('site:1', 'key1', 'value1');
      expect(await storage.get('site:1', 'key1'), 'value1');
    });

    test('覆盖写更新值', () async {
      await storage.set('site:1', 'key', 'v1');
      await storage.set('site:1', 'key', 'v2');
      expect(await storage.get('site:1', 'key'), 'v2');
    });

    test('delete 后返回 null', () async {
      await storage.set('site:1', 'key', 'value');
      await storage.delete('site:1', 'key');
      expect(await storage.get('site:1', 'key'), isNull);
    });

    test('不存在的 key 返回 null', () async {
      expect(await storage.get('site:1', 'nonexistent'), isNull);
    });

    test('不同 owner 隔离', () async {
      await storage.set('site:1', 'key', 'from-1');
      await storage.set('site:2', 'key', 'from-2');
      expect(await storage.get('site:1', 'key'), 'from-1');
      expect(await storage.get('site:2', 'key'), 'from-2');
    });

    test('totalBytes 按 owner 统计', () async {
      await storage.set('site:1', 'a', 'hello');
      await storage.set('site:1', 'b', 'world');
      await storage.set('site:2', 'c', 'other');
      expect(await storage.totalBytes('site:1'), 10);
      expect(await storage.totalBytes('site:2'), 5);
    });

    test('asHostStorage 装出的回调走同一份数据', () async {
      final hostStorage = storage.asHostStorage();
      await hostStorage.set('site:1', 'k', 'v');
      // 经 HostApi 的回调写进去的，直接查 dao 也读得到——两条路必须是同一份。
      expect(await storage.get('site:1', 'k'), 'v');
      expect(await hostStorage.get('site:1', 'k'), 'v');

      await hostStorage.delete('site:1', 'k');
      expect(await storage.get('site:1', 'k'), isNull);
    });

    test('接进 HostApi 后 host.storage.* 可用', () async {
      final api = HostApi(storage: storage.asHostStorage());

      final (setResult, setErr) = await api.handle('host.storage.set', {
        'instanceId': 'site:1',
        'key': 'k',
        'value': 'v',
      });
      expect(setErr, isNull, reason: '$setResult');

      final (getResult, getErr) = await api.handle('host.storage.get', {
        'instanceId': 'site:1',
        'key': 'k',
      });
      expect(getErr, isNull);
      expect((getResult! as Map<String, Object?>)['value'], 'v');
    });
  });
}
