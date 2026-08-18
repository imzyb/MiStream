import 'package:flutter/material.dart';
import 'package:download/download.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final DownloadManager _manager = DownloadManager();
  List<DownloadTask> _tasks = [];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _manager.addTaskListener(_onTaskUpdate);
  }

  @override
  void dispose() {
    _manager.removeTaskListener(_onTaskUpdate);
    _manager.dispose();
    super.dispose();
  }

  void _onTaskUpdate(DownloadTask task) {
    setState(() {
      _tasks = _manager.tasks;
    });
  }

  void _loadTasks() {
    setState(() {
      _tasks = _manager.tasks;
    });
  }

  List<DownloadTask> get _activeTasks =>
      _tasks.where((t) => t.status == DownloadStatus.downloading).toList();

  List<DownloadTask> get _pendingTasks =>
      _tasks.where((t) => t.status == DownloadStatus.pending).toList();

  List<DownloadTask> get _completedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> get _failedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.failed).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          if (_completedTasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearCompleted,
              tooltip: 'Clear completed',
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
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          _buildTab('Active', _activeTasks.length),
          _buildTab('Pending', _pendingTasks.length),
          _buildTab('Completed', _completedTasks.length),
          _buildTab('Failed', _failedTasks.length),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    final isSelected = _selectedTab == label.hashCode % 4;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = label.hashCode % 4;
          });
        },
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
    final tasks = _selectedTab == 0
        ? _activeTasks
        : _selectedTab == 1
        ? _pendingTasks
        : _selectedTab == 2
        ? _completedTasks
        : _failedTasks;

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTab == 2 ? Icons.check_circle : Icons.download,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTab == 2
                  ? 'No completed downloads'
                  : 'No downloads in this tab',
            ),
          ],
        ),
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
          task.title,
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
                  task.status.name.toUpperCase(),
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
        break;
      case DownloadStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case DownloadStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
      case DownloadStatus.paused:
        icon = Icons.pause_circle;
        color = Colors.orange;
        break;
      default:
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
          tooltip: 'Pause',
        );
      case DownloadStatus.paused:
        return IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () => _resumeTask(task),
          tooltip: 'Resume',
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _retryTask(task),
          tooltip: 'Retry',
        );
      default:
        return IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteTask(task),
          tooltip: 'Delete',
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
      default:
        return Colors.grey;
    }
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
        title: const Text('Delete Download'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
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
        title: const Text('Clear Completed'),
        content: const Text('Remove all completed downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
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

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Download'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/video.m3u8',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (urlController.text.isNotEmpty &&
                  titleController.text.isNotEmpty) {
                await _manager.createTask(
                  title: titleController.text,
                  url: urlController.text,
                  savePath: '/downloads/${titleController.text}',
                );
                await _manager.startDownload(_manager.tasks.last.id);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}
