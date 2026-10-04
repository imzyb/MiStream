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

  group('结果的身份与排序', () {
    test('identityKey 用归一化后的键，不是源返回的原始标题', () async {
      // 身份键就是合并去重键。UI 拿它当 ValueKey —— 若换成原始标题，
      // 同一部片在不同源下的身份会不一致，卡片重排时被当成新项重建。
      final searcher = _MockSearcher()
        ..setResult(
          1,
          const SpiderSearchResult(
            items: [SpiderRawItem(vodId: '1', vodName: '海贼王（2024）')],
          ),
        )
        ..setResult(
          2,
          const SpiderSearchResult(
            items: [SpiderRawItem(vodId: '2', vodName: '海贼王[HD]')],
          ),
        );

      final useCase = SearchUseCase(
        sourceProvider: _MockSourceProvider([
          const SearchableSource(id: 1, name: '源1', priority: 5),
          const SearchableSource(id: 2, name: '源2', priority: 3),
        ]),
        spiderSearcher: searcher,
      );

      final items = (await useCase.search('test').toList()).last.items;

      // 两个源的标题归一化后相同 → 合并为一条。
      expect(items, hasLength(1));
      expect(items.single.identityKey, '海贼王');
      // 展示标题仍是源给的原文（先到的那个源），与身份键刻意不同。
      expect(items.single.title, '海贼王（2024）');
      expect(items.single.sources, hasLength(2));
    });

    test('同一批结果的 identityKey 互不重复', () async {
      // 撞 key 会让 Flutter 直接抛 Duplicate keys，必须在引擎侧就保证唯一。
      final searcher = _MockSearcher()
        ..setResult(
          1,
          const SpiderSearchResult(
            items: [
              SpiderRawItem(vodId: '1', vodName: '剧A'),
              SpiderRawItem(vodId: '2', vodName: '剧B'),
              SpiderRawItem(vodId: '3', vodName: '剧C'),
            ],
          ),
        )
        ..setResult(
          2,
          const SpiderSearchResult(
            items: [
              SpiderRawItem(vodId: '4', vodName: '剧A（2024）'),
              SpiderRawItem(vodId: '5', vodName: '剧D'),
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

      final items = (await useCase.search('test').toList()).last.items;
      final keys = items.map((e) => e.identityKey).toList();

      expect(items, hasLength(4));
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('sources 按源优先级降序，first 是优先级最高的源', () async {
      // 并发顺序由源列表顺序决定：源1（低优先级）先被消费、先命中，于是它
      // 先进入 sources。不排序的话 `sources.first` 拿到的是**最先命中**的源，
      // 而详情页与搜索页都靠它决定「默认打开哪个源」。
      final searcher = _MockSearcher()
        ..setResult(
          1,
          const SpiderSearchResult(
            items: [SpiderRawItem(vodId: '1', vodName: '剧A')],
          ),
        )
        ..setResult(
          2,
          const SpiderSearchResult(
            items: [SpiderRawItem(vodId: '2', vodName: '剧A')],
          ),
        );

      final useCase = SearchUseCase(
        sourceProvider: _MockSourceProvider([
          const SearchableSource(id: 1, name: '源1', priority: 1),
          const SearchableSource(id: 2, name: '源2', priority: 9),
        ]),
        spiderSearcher: searcher,
      );

      final item = (await useCase.search('test').toList()).last.items.single;

      expect(item.sources.map((s) => s.sourceId), [2, 1]);
      expect(item.sources.first.sourcePriority, 9);
      // maxPriority 与排在最前的源一致，两者不该各说各话。
      expect(item.maxPriority, item.sources.first.sourcePriority);
    });
  });
}
