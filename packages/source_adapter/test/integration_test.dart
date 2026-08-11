import 'package:mock_source_server/mock_source_server.dart';
import 'package:search_engine/search_engine.dart';
import 'package:source_adapter/src/source_adapter.dart';
import 'package:spider_host/spider_host.dart';
import 'package:test/test.dart';

void main() {
  group('端到端集成：HttpSpiderSearcher + SearchUseCase', () {
    late MockSourceServer server;
    late HttpRuntime runtime;
    late HttpSpiderSearcher searcher;
    late SearchUseCase searchUseCase;

    setUp(() async {
      server = MockSourceServer();
      await server.start();
      runtime = HttpRuntime(server.apiUrl);
      searcher = HttpSpiderSearcher(runtime);

      // 用 mock 源测试 SearchUseCase
      final provider = _MockSourceProvider([
        const SearchableSource(id: 1, name: 'Mock源', priority: 5),
      ]);

      searchUseCase = SearchUseCase(
        sourceProvider: provider,
        spiderSearcher: searcher,
        timeout: const Duration(seconds: 5),
      );
    });

    tearDown(() async {
      await server.close();
    });

    test('HttpSpiderSearcher 搜索返回结构化结果', () async {
      final result = await searcher.search(1, '海贼王');
      expect(result.error, isNull);
      expect(result.items, isNotEmpty);
      // mock 源返回 "搜索结果-海贼王"
      expect(result.items.first.vodName, contains('海贼王'));
    });

    test('SearchUseCase 完整搜索链路', () async {
      final results = await searchUseCase.search('test').toList();
      // 应有至少一个进度事件
      expect(results, isNotEmpty);
      // 最终结果应完成
      final finalResult = results.last;
      expect(finalResult.isComplete, isTrue);
      expect(finalResult.items, isNotEmpty);
      // 源状态应为 complete
      expect(finalResult.sourceStatuses, hasLength(1));
      expect(finalResult.sourceStatuses.first.status, SearchStatus.complete);
    });

    test('HttpRuntime 直接调用 play 方法', () async {
      final result = await runtime.play(flag: 'qiyi', ids: '1001');
      expect(result.isOk, isTrue);
      final body = result.valueOrNull!.body;
      expect(body, contains('play.m3u8'));
    });
  });

  group('HttpSpiderPlayerApi', () {
    // 需要 mock 服务器多端点支持，后续扩展
  });
}

class _MockSourceProvider implements SourceProvider {
  _MockSourceProvider(this.sources);
  final List<SearchableSource> sources;

  @override
  Future<List<SearchableSource>> getEnabledSites() async => sources;
}
