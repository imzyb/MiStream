import 'package:flutter/material.dart';

/// 搜索页面：搜索输入 + 源选择 + 流式结果。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _items = <_SearchResultItem>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String keyword) {
    // TODO: 接入 SearchUseCase
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
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
              setState(() => _items.clear());
            },
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(
              child: Text('输入关键词开始搜索', style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) => _SearchResultCard(_items[index]),
            ),
    );
  }
}

class _SearchResultItem {
  final String title;
  const _SearchResultItem({required this.title});
}

class _SearchResultCard extends StatelessWidget {
  final _SearchResultItem item;
  const _SearchResultCard(this.item);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 80,
          height: 112,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: const Center(child: Icon(Icons.movie)),
        ),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () {},
    );
  }
}
