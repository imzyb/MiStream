/// 搜索页面：搜索输入 + 源选择 + 流式结果。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mistream/app/app.dart';
import 'package:search_engine/search_engine.dart';

/// 搜索页面。
class SearchPage extends StatefulWidget {
  /// 构造搜索页。
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _items = <SearchItem>[];
  final _sourceStatuses = <SearchSourceStatus>[];
  bool _searching = false;
  StreamSubscription<SearchProgress>? _sub;

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _controller.dispose();
    super.dispose();
  }

  void _search(String keyword) {
    if (keyword.trim().isEmpty) return;

    unawaited(_sub?.cancel());
    setState(() {
      _items.clear();
      _sourceStatuses.clear();
      _searching = true;
    });

    final assembly = AppScope.of(context);

    _sub = assembly.searchUseCase
        .search(keyword)
        .listen(
          (progress) {
            if (!mounted) return;
            setState(() {
              _items
                ..clear()
                ..addAll(progress.items);
              _sourceStatuses
                ..clear()
                ..addAll(progress.sourceStatuses);
              _searching = !progress.isComplete;
            });
          },
          onError: (_) {
            if (mounted) setState(() => _searching = false);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索影片、剧集...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
        actions: [
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              unawaited(_sub?.cancel());
              _controller.clear();
              setState(() {
                _items.clear();
                _sourceStatuses.clear();
                _searching = false;
              });
            },
          ),
        ],
      ),
      body: _items.isEmpty
          ? _searching
                ? _buildStatusList()
                : const Center(
                    child: Text(
                      '输入关键词开始搜索',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) => _SearchResultCard(
                item: _items[index],
                onTap: () => _goDetail(_items[index]),
              ),
            ),
    );
  }

  Widget _buildStatusList() {
    if (_sourceStatuses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sourceStatuses.length,
      itemBuilder: (context, index) {
        final status = _sourceStatuses[index];
        return ListTile(
          leading: _statusIcon(status.status),
          title: Text(status.sourceName),
          subtitle: Text(
            status.error ?? _statusText(status),
            style: TextStyle(
              color: status.status == SearchStatus.error
                  ? Theme.of(context).colorScheme.error
                  : null,
              fontSize: 12,
            ),
          ),
          dense: true,
        );
      },
    );
  }

  Widget _statusIcon(SearchStatus status) {
    return switch (status) {
      SearchStatus.pending => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      SearchStatus.running => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      SearchStatus.complete => const Icon(Icons.check_circle_outline, size: 16),
      SearchStatus.error => const Icon(
        Icons.error_outline,
        size: 16,
        color: Colors.red,
      ),
    };
  }

  String _statusText(SearchSourceStatus status) {
    return switch (status.status) {
      SearchStatus.pending => '等待中',
      SearchStatus.running => '搜索中...',
      SearchStatus.complete => '${status.resultCount} 条结果',
      SearchStatus.error => '失败',
    };
  }

  void _goDetail(SearchItem item) {
    if (item.sources.isEmpty) return;
    final source = item.sources.first;
    unawaited(
      context.pushNamed(
        'detail',
        pathParameters: {
          'siteId': source.sourceId.toString(),
          'vodId': source.vodId,
        },
        extra: item,
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.item, this.onTap});
  final SearchItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 60,
          height: 80,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: item.coverUrl != null
              ? Image.network(
                  item.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.movie, size: 24)),
                )
              : const Center(child: Icon(Icons.movie, size: 24)),
        ),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: _buildSubtitle(context),
      onTap: onTap,
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final parts = <String>[];
    if (item.year != null) parts.add(item.year!);
    if (item.remarks != null) parts.add(item.remarks!);
    if (item.sources.length > 1) parts.add('${item.sources.length} 个源');
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
