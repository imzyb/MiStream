/// 搜索 P50 基准（ROADMAP M4 出口标准 `search P50 < 3s`）。
///
/// 用纯内存 mock 源（无网络）在本地测量 `SearchUseCase.search` 的端到端耗时，
/// 包含并发调度、去重、流式合并全链路。mock 源的 `SpiderSearcher` 固定 20ms
/// 延迟，模拟真实宿主的最小开销；真实网络下 P50 应在此基础上 + 网络 RTT。
library;

import 'package:search_engine/src/models.dart';
import 'package:search_engine/src/search_use_case.dart';
import 'package:test/test.dart';

class _P50Provider implements SourceProvider {
  _P50Provider(this.sources);
  final List<SearchableSource> sources;
  @override
  Future<List<SearchableSource>> getEnabledSites() async => sources;
}

class _P50Searcher implements SpiderSearcher {
  @override
  Future<SpiderSearchResult> search(int sourceId, String keyword) async {
    // 模拟宿主侧最小延迟
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return SpiderSearchResult(
      items: [SpiderRawItem(vodId: '$sourceId', vodName: '影片$sourceId')],
    );
  }
}

void main() {
  test('search P50 < 3s（5 源并发，本地 mock）', () async {
    final useCase = SearchUseCase(
      sourceProvider: _P50Provider([
        for (var i = 1; i <= 5; i++)
          SearchableSource(id: i, name: '源$i', priority: 5),
      ]),
      spiderSearcher: _P50Searcher(),
      concurrency: 8,
      timeout: const Duration(seconds: 8),
    );

    const runs = 10;
    final elapsedMs = <int>[];
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      final results = await useCase.search('海贼王').toList();
      sw.stop();
      expect(results.last.isComplete, isTrue);
      expect(results.last.items, isNotEmpty);
      elapsedMs.add(sw.elapsedMilliseconds);
    }

    elapsedMs.sort();
    final p50 = elapsedMs[elapsedMs.length ~/ 2];
    final p95 = elapsedMs[(elapsedMs.length * 0.95).floor().clamp(0, runs - 1)];

    // 输出供 CI 日志观察
    // ignore: avoid_print -- 基准日志需打印
    print('P50=${p50}ms P95=${p95}ms samples=$elapsedMs');

    expect(p50, lessThan(3000), reason: 'P50 $p50 ms 超过 3s 预算');
    expect(p95, lessThan(5000), reason: 'P95 $p95 ms 超过 5s 预算');
  });
}
