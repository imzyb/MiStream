import 'dart:async';

import 'package:search_engine/src/models.dart';
import 'package:search_engine/src/search_use_case.dart';
import 'package:test/test.dart';

class _MockSourceProvider implements SourceProvider {
  _MockSourceProvider(this.sources);
  final List<SearchableSource> sources;

  @override
  Future<List<SearchableSource>> getEnabledSites() async => sources;
}

class _MockSearcher implements SpiderSearcher {
  final Map<int, SpiderSearchResult> _results = {};
  final Map<int, Completer<SpiderSearchResult>> _pending = {};
  final List<int> _callOrder = [];

  void setResult(int sourceId, SpiderSearchResult result) {
    final c = _pending.remove(sourceId);
    if (c != null) {
      c.complete(result);
    } else {
      _results[sourceId] = result;
    }
  }

  void setDelay(int sourceId, Duration delay) {
    _pending[sourceId] = Completer<SpiderSearchResult>();
  }

  @override
  Future<SpiderSearchResult> search(int sourceId, String keyword) async {
    _callOrder.add(sourceId);
    final pending = _pending.remove(sourceId);
    if (pending != null) {
      return pending.future;
    }
    return _results[sourceId] ?? const SpiderSearchResult();
  }
}

void main() {
  group('normalizeTitle', () {
    test('去空格', () {
      expect(normalizeTitle(' 海贼王 '), '海贼王');
    });

    test('全角转半角', () {
      expect(normalizeTitle('海贼王（2024）'), '海贼王');
    });

    test('去后缀', () {
      expect(normalizeTitle('海贼王[HD]'), '海贼王');
      expect(normalizeTitle('海贼王(1080P)'), '海贼王');
    });
  });

  group('SearchUseCase', () {
    test('空源列表直接完成', () async {
      final useCase = SearchUseCase(
        sourceProvider: _MockSourceProvider([]),
        spiderSearcher: _MockSearcher(),
      );
      final results = await useCase.search('test').toList();
      expect(results.last.isComplete, isTrue);
      expect(results.last.items, isEmpty);
    });

    test('单源返回结果', () async {
      final searcher = _MockSearcher()
        ..setResult(
          1,
          const SpiderSearchResult(
            items: [
              SpiderRawItem(vodId: '1', vodName: '剧A'),
            ],
          ),
        );
      final useCase = SearchUseCase(
        sourceProvider: _MockSourceProvider([
          const SearchableSource(id: 1, name: '源1', priority: 5),
        ]),
        spiderSearcher: searcher,
      );
      final results = await useCase.search('test').toList();
      final finalResult = results.last;
      expect(finalResult.items, hasLength(1));
      expect(finalResult.items.first.title, '剧A');
    });

    test('多源返回结果去重合并', () async {
      final searcher = _MockSearcher()
        ..setResult(
          1,
          const SpiderSearchResult(
            items: [
              SpiderRawItem(vodId: '1', vodName: '剧A'),
            ],
          ),
        )
        ..setResult(
          2,
          const SpiderSearchResult(
            items: [
              SpiderRawItem(vodId: '2', vodName: '剧A'),
            ],
          ),
        );
      final useCase = SearchUseCase(
        sourceProvider: _MockSourceProvider([
          const SearchableSource(id: 1, name: '源1', priority: 5),
          const SearchableSource(id: 2, name: '源2', priority: 3),
        ]),
        spiderSearcher: searcher,
      );
      final results = await useCase.search('test').toList();
      final finalResult = results.last;
      // 两个源都返回了"剧A"，应合并为一条
      expect(finalResult.items, hasLength(1));
      expect(finalResult.items.first.sources, hasLength(2));
    });

    test('源超时不阻塞其他源', () async {
      final searcher = _MockSearcher()
        ..setResult(
          1,
          const SpiderSearchResult(
            items: [
              SpiderRawItem(vodId: '1', vodName: '剧A'),
            ],
          ),
        )
        // 源2 会超时
        ..setDelay(2, const Duration(seconds: 60))
        ..setResult(
          3,
          const SpiderSearchResult(
            items: [
              SpiderRawItem(vodId: '3', vodName: '剧C'),
            ],
          ),
        );
      final useCase = SearchUseCase(
        sourceProvider: _MockSourceProvider([
          const SearchableSource(id: 1, name: '源1', priority: 5),
          const SearchableSource(id: 2, name: '源2', priority: 3),
          const SearchableSource(id: 3, name: '源3', priority: 1),
        ]),
        spiderSearcher: searcher,
        timeout: const Duration(milliseconds: 10),
      );
      final results = await useCase.search('test').toList();
      final finalResult = results.last;
      // 源2 超时，源1和源3的结果应到达
      expect(finalResult.items.length, greaterThanOrEqualTo(1));
      expect(finalResult.isComplete, isTrue);
      // 源2 状态应为 error
      final source2Status = finalResult.sourceStatuses.firstWhere(
        (s) => s.sourceId == 2,
      );
      expect(source2Status.status, SearchStatus.error);
    });

    test('源失败不影响其他源', () async {
      final searcher = _MockSearcher()
        ..setResult(
          1,
          const SpiderSearchResult(
            items: [
              SpiderRawItem(vodId: '1', vodName: '剧A'),
            ],
          ),
        )
        ..setResult(2, const SpiderSearchResult(error: '挂了'));
      final useCase = SearchUseCase(
        sourceProvider: _MockSourceProvider([
          const SearchableSource(id: 1, name: '源1', priority: 5),
          const SearchableSource(id: 2, name: '源2', priority: 3),
        ]),
        spiderSearcher: searcher,
        timeout: const Duration(seconds: 5),
      );
      final results = await useCase.search('test').toList();
      final finalResult = results.last;
      expect(finalResult.items, hasLength(1));
      expect(finalResult.isComplete, isTrue);
    });

    test('并发上限控制', () async {
      final searcher = _MockSearcher();
      // 3 个源，并发上限 2
      for (var i = 1; i <= 3; i++) {
        searcher.setResult(
          i,
          SpiderSearchResult(
            items: [
              SpiderRawItem(vodId: '$i', vodName: '剧$i'),
            ],
          ),
        );
      }
      final useCase = SearchUseCase(
        sourceProvider: _MockSourceProvider([
          const SearchableSource(id: 1, name: '源1', priority: 5),
          const SearchableSource(id: 2, name: '源2', priority: 3),
          const SearchableSource(id: 3, name: '源3', priority: 1),
        ]),
        spiderSearcher: searcher,
        concurrency: 2,
        timeout: const Duration(seconds: 5),
      );
      final results = await useCase.search('test').toList();
      final finalResult = results.last;
      expect(finalResult.items, hasLength(3));
      expect(finalResult.isComplete, isTrue);
    });
  });
}
