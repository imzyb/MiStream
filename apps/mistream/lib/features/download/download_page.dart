/// 下载页：任务列表 + 四个状态分组。
library;

import 'dart:async' show unawaited;

import 'package:download/download.dart';
import 'package:flutter/material.dart';
import 'package:mistream/app/app.dart' show AppScope;
import 'package:mistream/application/app_assembly.dart';

import 'package:mistream/features/common/common.dart' show EmptyView;

/// 下载页。
///
/// 管理器**不在这里创建**：它是进程级单例，由 [AppAssembly] 持有。旧实现是
/// `DownloadPage` 自己 `new DownloadManager()` —— 于是「进下载页」和「杀进程
/// 重启」看到的是两份互不相干的内存状态，落库了也读不到。
class DownloadPage extends StatefulWidget {
  /// 构造下载页。
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  late final AppAssembly _assembly;
  late final DownloadManager _manager;
  bool _depsReady = false;
  int _selectedTab = 0;

  static const _tabLabels = ['进行中', '等待中', '已完成', '失败'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _assembly = AppScope.of(context);
    _manager = _assembly.downloadManager;
    _manager.addListener(_onChanged);
  }

  @override
  void dispose() {
    // 只退订，**不 dispose**：管理器归装配层所有，页签切走再切回来不该把
    // 正在下载的任务一起干掉。
    _manager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<DownloadTask> get _activeTasks => _manager.activeTasks;

  /// 「等待中」按**调度顺序**（优先级降序、同级按创建时间），而不是创建顺序。
  List<DownloadTask> get _pendingTasks => _manager.pendingTasks;

  List<DownloadTask> get _completedTasks => _manager.completedTasks;

  List<DownloadTask> get _failedTasks => _manager.failedTasks;

  List<DownloadTask> get _currentTasks => switch (_selectedTab) {
    0 => _activeTasks,
    1 => _pendingTasks,
    2 => _completedTasks,
    _ => _failedTasks,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载'),
        actions: [
          if (_completedTasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearCompleted,
              tooltip: '清除已完成',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDownloadDialog,
        tooltip: '新建下载',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTabBar() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          for (var i = 0; i < _tabLabels.length; i++)
            _buildTab(i, _tabLabels[i], _tabCount(i)),
        ],
      ),
    );
  }

  int _tabCount(int index) => switch (index) {
    0 => _activeTasks.length,
    1 => _pendingTasks.length,
    2 => _completedTasks.length,
    _ => _failedTasks.length,
  };

  Widget _buildTab(int index, String label, int count) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
              if (count > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final tasks = _currentTasks;

    if (tasks.isEmpty) {
      return EmptyView(
        icon: _selectedTab == 2 ? Icons.check_circle : Icons.download,
        title: _selectedTab == 2 ? '暂无完成的任务' : '该分组暂无任务',
        subtitle: '点击右下角按钮新建下载',
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return _buildTaskTile(tasks[index]);
      },
    );
  }

  Widget _buildTaskTile(DownloadTask task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _buildTaskIcon(task),
        title: Text(
          // `title` 是影片名；从影片页发起的下载要带上集名才分得清是哪一集。
          task.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildProgressBar(task),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatBytes(task.downloadedBytes),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _statusLabel(task.status),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getStatusColor(task.status),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: _buildTaskActions(task),
      ),
    );
  }

  Widget _buildTaskIcon(DownloadTask task) {
    IconData icon;
    Color color;

    switch (task.status) {
      case DownloadStatus.downloading:
        icon = Icons.downloading;
        color = Colors.blue;
      case DownloadStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
      case DownloadStatus.failed:
        icon = Icons.error;
        color = Colors.red;
      case DownloadStatus.paused:
        icon = Icons.pause_circle;
        color = Colors.orange;
      case DownloadStatus.cancelled:
        icon = Icons.cancel;
        color = Colors.grey;
      case DownloadStatus.pending:
        icon = Icons.schedule;
        color = Colors.grey;
    }

    return Icon(icon, color: color);
  }

  Widget _buildProgressBar(DownloadTask task) {
    return LinearProgressIndicator(
      value: task.progress,
      backgroundColor: Colors.grey[300],
      valueColor: AlwaysStoppedAnimation<Color>(
        _getStatusColor(task.status),
      ),
    );
  }

  Widget _buildTaskActions(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.pause),
          onPressed: () => _pauseTask(task),
          tooltip: '暂停',
        );
      case DownloadStatus.paused:
        return IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () => _resumeTask(task),
          tooltip: '继续',
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _retryTask(task),
          tooltip: '重试',
        );
      case DownloadStatus.cancelled:
      case DownloadStatus.pending:
      case DownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteTask(task),
          tooltip: '删除',
        );
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.cancelled:
      case DownloadStatus.pending:
        return Colors.grey;
    }
  }

  String _statusLabel(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.downloading => '下载中',
      DownloadStatus.completed => '已完成',
      DownloadStatus.failed => '失败',
      DownloadStatus.paused => '已暂停',
      _ => '等待中',
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _pauseTask(DownloadTask task) async {
    await _manager.pauseDownload(task.id);
  }

  Future<void> _resumeTask(DownloadTask task) async {
    await _manager.resumeDownload(task.id);
  }

  Future<void> _retryTask(DownloadTask task) async {
    await _manager.startDownload(task.id);
  }

  Future<void> _deleteTask(DownloadTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除下载'),
        content: Text('确定要删除「${task.displayName}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _manager.deleteTask(task.id);
    }
  }

  Future<void> _clearCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除已完成'),
        content: const Text('确定要移除所有已完成的任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _manager.clearCompleted();
    }
  }

  void _showAddDownloadDialog() {
    final urlController = TextEditingController();
    final titleController = TextEditingController();

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('新建下载'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: '地址',
                  hintText: 'https://example.com/video.m3u8',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final url = urlController.text.trim();
                if (url.isEmpty || title.isEmpty) return;
                final task = await _manager.createTask(
                  title: title,
                  url: url,
                  // 保存路径由应用层按下载根目录拼，UI 不自己拼 ——
                  // 旧实现写的是 `/downloads/<标题>`，在 Windows 上会落到
                  // **当前盘根目录**下，越出应用的数据目录。
                  // 手动新建没有「集」的概念，第二参数传 `null`。
                  savePath: _assembly.downloadSavePathFor(title, null),
                );
                await _manager.startDownload(task.id);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('下载'),
            ),
          ],
        ),
      ),
    );
  }
}
