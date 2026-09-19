import 'package:flutter_test/flutter_test.dart';
import 'package:mock_source_server/mock_source_server.dart';
import 'package:search_engine/search_engine.dart';
import 'package:mistream/application/config_install_service.dart';
import 'package:mistream/application/detail_use_case.dart';
import 'package:source_adapter/source_adapter.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';

void main() {
  group('M5 Mock 源垂直集成', () {
    late MockSourceServer server;
    late AppDatabase db;
    late Repositories repositories;

    setUp(() async {
      server = MockSourceServer();
      await server.start();
      db = AppDatabase.inMemory();
      repositories = Repositories(db);
    });

    tearDown(() async {
      await db.close();
      await server.close();
    });

    test('配置导入后可以完成搜索、详情与播放地址获取', () async {
      final installer = ConfigInstallService(repositories);

      final install = await installer.installFromUrl(
        '${server.baseUrl}/config.json',
      );
      expect(install.isOk, isTrue);
      expect(install.valueOrNull, 2);

      final sites = await repositories.sites.enabled();
      expect(sites, hasLength(2));

      final sourceProvider = StorageSourceProvider(repositories.sites);
      final searcher = HttpSpiderSearcher(HttpRuntime(server.apiUrl));
      final search = SearchUseCase(
        sourceProvider: sourceProvider,
        spiderSearcher: searcher,
        timeout: const Duration(seconds: 5),
      );

      final searchEvents = await search.search('海贼王').toList();
      final searchResult = searchEvents.last;
      expect(searchResult.isComplete, isTrue);
      expect(searchResult.items, isNotEmpty);
      expect(searchResult.items.first.sources, hasLength(2));
      expect(searchResult.items.first.sources.first.vodId, '3001');

      final httpSite = sites.firstWhere((site) => site.typeCode == 1);
      final detail = DetailUseCase(repositories.sites).load(
        siteId: httpSite.id,
        vodId: '1001',
      );
      final detailResult = await detail;
      expect(
        detailResult.isOk,
        isTrue,
        reason: detailResult.errorOrNull?.message,
      );
      expect(detailResult.valueOrNull!.name, '测试电影');
      expect(detailResult.valueOrNull!.flags, contains('qiyi'));
      expect(detailResult.valueOrNull!.episodes['qiyi'], hasLength(2));

      final play = PlayUseCase(repositories.sites).getPlayableSource(
        siteId: httpSite.id,
        vodId: '1001',
        flag: 'qiyi',
        episodeId: '0',
      );
      final playResult = await play;
      expect(playResult.isOk, isTrue);
      expect(
        playResult.valueOrNull!.mediaSource.uri.toString(),
        'https://example.com/ep1.m3u8',
      );
    });
  });
}
