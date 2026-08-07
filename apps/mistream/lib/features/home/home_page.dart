import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 首页：展示分类与推荐内容。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiStream'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.pushNamed('search'),
            tooltip: '搜索',
          ),
        ],
      ),
      body: ListView(
        children: [
          const _SectionHeader('推荐'),
          const _PlaceholderGrid(),
          const _SectionHeader('分类'),
          const _CategoryList(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _PlaceholderGrid extends StatelessWidget {
  const _PlaceholderGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const _MediaCard(),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: const Center(child: Icon(Icons.movie, size: 40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '示例影片',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList();

  @override
  Widget build(BuildContext context) {
    const categories = ['电影', '剧集', '综艺', '动漫', '纪录片'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories
            .map(
              (c) => ActionChip(
                label: Text(c),
                onPressed: () {},
              ),
            )
            .toList(),
      ),
    );
  }
}
