import 'package:live/live.dart';
// `storage` 也导出同名的 drift 行类 `LiveChannel` / `LiveGroup`，必须加前缀，
// 否则每个字面量都会报「imported from both」。
import 'package:storage/storage.dart' as db;
import 'package:test/test.dart';

/// 造一个「有分组 + 无分组 + 多地址」的解析结果。
LiveParseResult _sample() => const LiveParseResult(
  groups: [
    LiveGroup(id: '央视', name: '央视', order: 0),
    LiveGroup(id: '卫视', name: '卫视', order: 1),
  ],
  channels: [
    LiveChannel(
      id: 'a1',
      name: 'CCTV1',
      url: 'http://a/cctv1.m3u8',
      groupId: '央视',
      extraUrls: ['http://b/cctv1.m3u8', 'http://c/cctv1.m3u8'],
    ),
    LiveChannel(
      id: 'a2',
      name: '湖南卫视',
      url: 'http://a/hunan.m3u8',
      groupId: '卫视',
    ),
    // 无分组 —— 旧实现就是在这一步 `continue` 丢掉的。
    LiveChannel(id: 'a3', name: '无分组频道', url: 'http://a/none.m3u8'),
  ],
);

void main() {
  group('地址编解码', () {
    test('多地址往返', () {
      const urls = ['http://a/x.m3u8', 'http://b/x.m3u8'];
      expect(decodeLiveUrls(encodeLiveUrls(urls)), urls);
    });

    test('地址里的分隔符不产生歧义', () {
      // 这正是选 JSON 而不是拼接的理由：地址自己就带 `,` `;` `#` `|`。
      const urls = [
        'http://a/x.m3u8?key=tx&play=0,1',
        'http://b/y.m3u8#frag|pipe',
      ];
      expect(decodeLiveUrls(encodeLiveUrls(urls)), urls);
    });

    test('兼容旧实现的裸 URL 形态', () {
      expect(decodeLiveUrls('http://a/x.m3u8'), ['http://a/x.m3u8']);
    });

    test('空值返回空列表', () {
      expect(decodeLiveUrls(null), isEmpty);
      expect(decodeLiveUrls(''), isEmpty);
      expect(decodeLiveUrls('   '), isEmpty);
    });

    test('以 [ 开头但不是合法 JSON 时按裸 URL 处理', () {
      expect(decodeLiveUrls('[http://a/x.m3u8'), ['[http://a/x.m3u8']);
    });

    test('过滤非字符串与空白项', () {
      expect(
        decodeLiveUrls('["http://a", 123, "  ", "http://b"]'),
        ['http://a', 'http://b'],
      );
    });
  });

  group('DriftLiveRepository.replaceAll', () {
    late db.AppDatabase database;
    late DriftLiveRepository repo;

    setUp(() {
      database = db.AppDatabase.inMemory();
      repo = DriftLiveRepository(database);
    });

    tearDown(() => database.close());

    test('未分组频道不丢，并落成「未分组」分组', () async {
      await repo.replaceAll(_sample());

      final channels = await repo.getChannels();
      expect(channels.length, 3, reason: '未分组频道不能在落库时被丢掉');

      final groups = await repo.getGroups();
      expect(groups.map((g) => g.name), contains('未分组'));
      expect(groups.length, 3, reason: '央视 + 卫视 + 未分组');
    });

    test('分组视图各桶之和等于全部频道数', () async {
      await repo.replaceAll(_sample());

      final byGroup = await repo.getChannelsByGroup();
      final total = byGroup.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );
      expect(total, (await repo.getChannels()).length);
    });

    test('多地址完整往返（主地址 + 备用地址）', () async {
      await repo.replaceAll(_sample());

      final cctv1 = (await repo.getChannels()).firstWhere(
        (c) => c.name == 'CCTV1',
      );
      expect(cctv1.url, 'http://a/cctv1.m3u8');
      expect(cctv1.extraUrls, ['http://b/cctv1.m3u8', 'http://c/cctv1.m3u8']);
      expect(cctv1.allUrls.length, 3);
    });

    test('单地址频道读回后没有备用地址', () async {
      await repo.replaceAll(_sample());

      final hunan = (await repo.getChannels()).firstWhere(
        (c) => c.name == '湖南卫视',
      );
      expect(hunan.url, 'http://a/hunan.m3u8');
      expect(hunan.extraUrls, isEmpty);
    });

    test('二次导入是替换而非追加', () async {
      await repo.replaceAll(_sample());
      await repo.replaceAll(
        const LiveParseResult(
          groups: [],
          channels: [LiveChannel(id: 'z', name: '唯一频道', url: 'http://z')],
        ),
      );

      final channels = await repo.getChannels();
      expect(channels.length, 1);
      expect(channels.single.name, '唯一频道');
    });

    test('重新导入后收藏按频道名保留', () async {
      await repo.replaceAll(_sample());
      final cctv1 = (await repo.getChannels()).firstWhere(
        (c) => c.name == 'CCTV1',
      );
      await repo.addFavorite(cctv1.id);
      expect((await repo.getFavorites()).map((c) => c.name), ['CCTV1']);

      // 新结果里地址与主键全变，但「这个台」还在。
      await repo.replaceAll(
        const LiveParseResult(
          groups: [LiveGroup(id: '央视', name: '央视', order: 0)],
          channels: [
            LiveChannel(
              id: 'brand-new',
              name: 'CCTV1',
              url: 'http://new/1.m3u8',
              groupId: '央视',
            ),
          ],
        ),
      );

      final favorites = await repo.getFavorites();
      expect(favorites.map((c) => c.name), ['CCTV1'], reason: '收藏不该被刷新抹掉');
      expect(
        favorites.single.url,
        'http://new/1.m3u8',
        reason: '保留的是「收藏了哪个台」，不是旧地址',
      );
    });

    test('频道在新结果里消失时收藏也随之消失', () async {
      await repo.replaceAll(_sample());
      final hunan = (await repo.getChannels()).firstWhere(
        (c) => c.name == '湖南卫视',
      );
      await repo.addFavorite(hunan.id);

      await repo.replaceAll(
        const LiveParseResult(
          groups: [],
          channels: [LiveChannel(id: 'z', name: '别的台', url: 'http://z')],
        ),
      );

      expect(await repo.getFavorites(), isEmpty);
    });

    test('未被收藏的频道不会被误标为收藏', () async {
      await repo.replaceAll(_sample());

      expect(await repo.getFavorites(), isEmpty);
    });
  });
}
