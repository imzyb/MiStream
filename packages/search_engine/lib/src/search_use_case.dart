/// 聚合搜索编排器：多源并发、流式结果、去重合并、失败折叠。
library;

import 'dart:async';

import 'package:search_engine/src/models.dart';

/// 全局并发上限：同时在跑的源不超过这个数（ROADMAP 风险 R9）。
const int kGlobalConcurrency = 8;

/// 单源超时：超过即折叠为失败，不阻塞其它源。
const Duration kSourceTimeout = Duration(seconds: 8);

/// 单源结果条数上限。
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
  /// 构造编排器。
  SearchUseCase({
    required this.sourceProvider,
    required this.spiderSearcher,
    this.concurrency = kGlobalConcurrency,
    this.timeout = kSourceTimeout,
    this.maxResultsPerSource = kMaxResultsPerSource,
  });

  /// 可搜索源的来源。
  final SourceProvider sourceProvider;

  /// 单源搜索的执行者。
  final SpiderSearcher spiderSearcher;

  /// 并发上限。
  final int concurrency;

  /// 单源超时。
  final Duration timeout;

  /// 单源结果条数上限。
  final int maxResultsPerSource;

  /// 执行搜索，返回流式进度。
  Stream<SearchProgress> search(String keyword) {
    final controller = StreamController<SearchProgress>();

    unawaited(_doSearch(keyword, controller));
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
            identityKey: key,
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
  _MergedEntry({
    required this.identityKey,
    required this.title,
    required SearchableSource source,
    required String vodId,
    this.originalTitle,
    this.year,
    this.coverUrl,
    this.remarks,
  }) {
    addSource(source, vodId);
  }

  /// 合并用的键，也是对外暴露的稳定身份（见 [SearchItem.identityKey]）。
  ///
  /// 由构造方传入而不是在这里重算 `normalizeTitle(title)`：键是 `merged` 的
  /// map key，只有一份真相，重算等于又埋一处「同一件事写两遍」。
  final String identityKey;
  final String title;
  final String? originalTitle;
  final String? year;
  final String? coverUrl;
  final String? remarks;
  final List<SearchSourceRef> sources = [];
  int maxPriority = 0;

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
    identityKey: identityKey,
    title: title,
    originalTitle: originalTitle,
    year: year,
    coverUrl: coverUrl,
    remarks: remarks,
    // 按源优先级降序，与 [SearchItem.sources] 的文档一致：调用方（详情页的
    // 片源列表、搜索页的「默认打开哪个源」）都取 `sources.first`，不排序的话
    // 拿到的是**最先命中**的那个源 —— 由并发顺序决定，每次搜索都可能不同。
    sources: List.of(sources)
      ..sort((a, b) => b.sourcePriority.compareTo(a.sourcePriority)),
    maxPriority: maxPriority,
  );
}
