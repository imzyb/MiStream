/// 聚合搜索编排器：多源并发、流式结果、去重合并、失败折叠。
library;

import 'dart:async';

import 'package:search_engine/src/models.dart';

const int kGlobalConcurrency = 8;
const Duration kSourceTimeout = Duration(seconds: 8);
const int kMaxResultsPerSource = 50;

/// 标题归一化。
String normalizeTitle(String title) {
  var t = title.trim();
  t = t.replaceAll('　', ' ').replaceAll('（', '(').replaceAll('）', ')');
  t = t.replaceAll('，', ',').replaceAll('？', '?').replaceAll('！', '!');
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAll(RegExp(r'[（(][^）)]*[）)]$'), '');
  t = t.replaceAll(RegExp(r'[【\[][^\】\]]*[\】\]]$'), '');
  return t.trim();
}

/// 聚合搜索编排器。
class SearchUseCase {
  final SourceProvider sourceProvider;
  final SpiderSearcher spiderSearcher;
  final int concurrency;
  final Duration timeout;
  final int maxResultsPerSource;

  SearchUseCase({
    required this.sourceProvider,
    required this.spiderSearcher,
    this.concurrency = kGlobalConcurrency,
    this.timeout = kSourceTimeout,
    this.maxResultsPerSource = kMaxResultsPerSource,
  });

  /// 执行搜索，返回流式进度。
  Stream<SearchProgress> search(String keyword) {
    final controller = StreamController<SearchProgress>();

    _doSearch(keyword, controller);
    return controller.stream;
  }

  Future<void> _doSearch(
    String keyword,
    StreamController<SearchProgress> controller,
  ) async {
    try {
      final sources = await sourceProvider.getEnabledSites();
      if (sources.isEmpty || controller.isClosed) {
        controller.add(SearchProgress(keyword: keyword, isComplete: true));
        await controller.close();
        return;
      }

      final statuses = List<SearchSourceStatus>.generate(
        sources.length,
        (i) => SearchSourceStatus(
          sourceId: sources[i].id,
          sourceName: sources[i].name,
        ),
      );
      final merged = <String, _MergedEntry>{};

      void emit() {
        if (controller.isClosed) return;
        final items = merged.values.map((e) => e.toSearchItem()).toList()
          ..sort((a, b) {
            final p = b.maxPriority.compareTo(a.maxPriority);
            return p != 0 ? p : a.title.compareTo(b.title);
          });
        controller.add(
          SearchProgress(
            keyword: keyword,
            items: items,
            sourceStatuses: List.of(statuses),
            isComplete: statuses.every(
              (s) =>
                  s.status == SearchStatus.complete ||
                  s.status == SearchStatus.error,
            ),
          ),
        );
      }

      // 先发初始状态
      emit();

      // 将所有源索引装入队列，用 concurrency 个 worker 并发消费
      final queue = List<int>.generate(sources.length, (i) => i);
      final workers = List.generate(
        concurrency,
        (_) => _worker(
          queue,
          sources,
          keyword,
          statuses,
          merged,
          emit,
        ),
      );

      await Future.wait(workers);
      emit();
    } on Object catch (e) {
      if (!controller.isClosed) controller.addError(e);
    } finally {
      if (!controller.isClosed) await controller.close();
    }
  }

  Future<void> _worker(
    List<int> queue,
    List<SearchableSource> sources,
    String keyword,
    List<SearchSourceStatus> statuses,
    Map<String, _MergedEntry> merged,
    void Function() emit,
  ) async {
    while (true) {
      // Dart 单线程事件循环，queue.removeAt 天然原子
      if (queue.isEmpty) break;
      final index = queue.removeAt(0);

      await _searchOne(
        sources[index],
        keyword,
        index,
        statuses,
        merged,
        emit,
      );
    }
  }

  Future<void> _searchOne(
    SearchableSource source,
    String keyword,
    int index,
    List<SearchSourceStatus> statuses,
    Map<String, _MergedEntry> merged,
    void Function() emit,
  ) async {
    statuses[index] = SearchSourceStatus(
      sourceId: source.id,
      sourceName: source.name,
      status: SearchStatus.running,
    );
    emit();

    try {
      final result = await spiderSearcher
          .search(source.id, keyword)
          .timeout(timeout);

      if (result.error != null) {
        statuses[index] = SearchSourceStatus(
          sourceId: source.id,
          sourceName: source.name,
          status: SearchStatus.error,
          error: result.error,
        );
        emit();
        return;
      }

      var count = 0;
      for (final item in result.items) {
        if (count >= maxResultsPerSource) break;
        final key = normalizeTitle(item.vodName);
        if (merged.containsKey(key)) {
          merged[key]!.addSource(source, item.vodId);
        } else {
          merged[key] = _MergedEntry(
            title: item.vodName,
            originalTitle: item.vodName,
            year: item.vodYear,
            coverUrl: item.vodPic,
            remarks: item.vodRemarks,
            source: source,
            vodId: item.vodId,
          );
        }
        count++;
      }

      statuses[index] = SearchSourceStatus(
        sourceId: source.id,
        sourceName: source.name,
        status: SearchStatus.complete,
        resultCount: count,
      );
      emit();
    } on TimeoutException {
      statuses[index] = SearchSourceStatus(
        sourceId: source.id,
        sourceName: source.name,
        status: SearchStatus.error,
        error: '超时',
      );
      emit();
    } on Object catch (e) {
      statuses[index] = SearchSourceStatus(
        sourceId: source.id,
        sourceName: source.name,
        status: SearchStatus.error,
        error: e.toString(),
      );
      emit();
    }
  }
}

class _MergedEntry {
  final String title;
  final String? originalTitle;
  final String? year;
  final String? coverUrl;
  final String? remarks;
  final List<SearchSourceRef> sources = [];
  int maxPriority = 0;

  _MergedEntry({
    required this.title,
    this.originalTitle,
    this.year,
    this.coverUrl,
    this.remarks,
    required SearchableSource source,
    required String vodId,
  }) {
    addSource(source, vodId);
  }

  void addSource(SearchableSource source, String vodId) {
    sources.add(
      SearchSourceRef(
        sourceId: source.id,
        sourceName: source.name,
        vodId: vodId,
        sourcePriority: source.priority,
      ),
    );
    if (source.priority > maxPriority) maxPriority = source.priority;
  }

  SearchItem toSearchItem() => SearchItem(
    title: title,
    originalTitle: originalTitle,
    year: year,
    coverUrl: coverUrl,
    remarks: remarks,
    sources: List.of(sources),
    maxPriority: maxPriority,
  );
}
