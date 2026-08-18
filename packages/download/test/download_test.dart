import 'package:test/test.dart';
import 'package:download/download.dart';

void main() {
  group('DownloadTask', () {
    test('fromJson creates task correctly', () {
      final json = {
        'id': 'task1',
        'title': 'Test Video',
        'url': 'http://example.com/video.m3u8',
        'savePath': '/downloads/video',
        'status': 'downloading',
        'progress': 0.5,
        'downloadedBytes': 1024,
        'totalBytes': 2048,
        'createdAt': 1000000,
        'updatedAt': 1000100,
        'downloadedSegments': 5,
        'totalSegments': 10,
      };
      final task = DownloadTask.fromJson(json);
      expect(task.id, 'task1');
      expect(task.title, 'Test Video');
      expect(task.url, 'http://example.com/video.m3u8');
      expect(task.savePath, '/downloads/video');
      expect(task.status, DownloadStatus.downloading);
      expect(task.progress, 0.5);
      expect(task.downloadedBytes, 1024);
      expect(task.totalBytes, 2048);
      expect(task.downloadedSegments, 5);
      expect(task.totalSegments, 10);
    });

    test('toJson roundtrip', () {
      final task = DownloadTask(
        id: 'task1',
        title: 'Test Video',
        url: 'http://example.com/video.m3u8',
        savePath: '/downloads/video',
        status: DownloadStatus.downloading,
        progress: 0.5,
        createdAt: 1000000,
        updatedAt: 1000100,
      );
      final json = task.toJson();
      final restored = DownloadTask.fromJson(json);
      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.status, task.status);
      expect(restored.progress, task.progress);
    });

    test('copyWith creates new instance', () {
      final task = DownloadTask(
        id: 'task1',
        title: 'Test',
        url: 'http://a.com',
        savePath: '/path',
        createdAt: 0,
        updatedAt: 0,
      );
      final updated = task.copyWith(title: 'Updated', progress: 0.5);
      expect(updated.title, 'Updated');
      expect(updated.progress, 0.5);
      expect(task.title, 'Test'); // original unchanged
    });

    test('isResumable returns true for paused', () {
      final task = DownloadTask(
        id: 'task1',
        title: 'Test',
        url: 'http://a.com',
        savePath: '/path',
        status: DownloadStatus.paused,
        createdAt: 0,
        updatedAt: 0,
      );
      expect(task.isResumable, true);
    });

    test('isCompleted returns true for completed', () {
      final task = DownloadTask(
        id: 'task1',
        title: 'Test',
        url: 'http://a.com',
        savePath: '/path',
        status: DownloadStatus.completed,
        createdAt: 0,
        updatedAt: 0,
      );
      expect(task.isCompleted, true);
    });

    test('equality by id', () {
      final t1 = DownloadTask(
        id: 'task1',
        title: 'A',
        url: 'http://a.com',
        savePath: '/a',
        createdAt: 0,
        updatedAt: 0,
      );
      final t2 = DownloadTask(
        id: 'task1',
        title: 'B',
        url: 'http://b.com',
        savePath: '/b',
        createdAt: 0,
        updatedAt: 0,
      );
      final t3 = DownloadTask(
        id: 'task2',
        title: 'A',
        url: 'http://a.com',
        savePath: '/a',
        createdAt: 0,
        updatedAt: 0,
      );
      expect(t1, equals(t2));
      expect(t1 == t3, false);
    });
  });

  group('DownloadProgress', () {
    test('formattedSpeed formats bytes/s', () {
      const progress = DownloadProgress(
        taskId: 't1',
        status: DownloadProgressStatus.downloading,
        speed: 512,
      );
      expect(progress.formattedSpeed, '512 B/s');
    });

    test('formattedSpeed formats kb/s', () {
      const progress = DownloadProgress(
        taskId: 't1',
        status: DownloadProgressStatus.downloading,
        speed: 2048,
      );
      expect(progress.formattedSpeed, '2.0 KB/s');
    });

    test('formattedSpeed formats mb/s', () {
      const progress = DownloadProgress(
        taskId: 't1',
        status: DownloadProgressStatus.downloading,
        speed: 2097152,
      );
      expect(progress.formattedSpeed, '2.0 MB/s');
    });

    test('formattedDownloaded formats bytes', () {
      const progress = DownloadProgress(
        taskId: 't1',
        status: DownloadProgressStatus.downloading,
        downloadedBytes: 1024,
      );
      expect(progress.formattedDownloaded, '1.0 KB');
    });

    test('formattedTotal returns unknown for -1', () {
      const progress = DownloadProgress(
        taskId: 't1',
        status: DownloadProgressStatus.downloading,
        totalBytes: -1,
      );
      expect(progress.formattedTotal, '未知');
    });

    test('formattedEta returns formatted time', () {
      const progress = DownloadProgress(
        taskId: 't1',
        status: DownloadProgressStatus.downloading,
        eta: 125,
      );
      expect(progress.formattedEta, '2分5秒');
    });

    test('isDownloading returns true for downloading status', () {
      const progress = DownloadProgress(
        taskId: 't1',
        status: DownloadProgressStatus.downloading,
      );
      expect(progress.isDownloading, true);
    });
  });

  group('DownloadManager', () {
    late DownloadManager manager;

    setUp(() {
      manager = DownloadManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('createTask creates task with correct defaults', () async {
      final task = await manager.createTask(
        title: 'Test Video',
        url: 'http://example.com/video.m3u8',
        savePath: '/downloads/video',
      );
      expect(task.title, 'Test Video');
      expect(task.url, 'http://example.com/video.m3u8');
      expect(task.status, DownloadStatus.pending);
      expect(task.progress, 0.0);
    });

    test('tasks list contains created task', () async {
      await manager.createTask(
        title: 'Test',
        url: 'http://a.com',
        savePath: '/path',
      );
      expect(manager.tasks.length, 1);
    });

    test('deleteTask removes task', () async {
      final task = await manager.createTask(
        title: 'Test',
        url: 'http://a.com',
        savePath: '/path',
      );
      await manager.deleteTask(task.id);
      expect(manager.tasks.length, 0);
    });

    test('clearCompleted removes completed tasks', () async {
      final task1 = await manager.createTask(
        title: 'Test1',
        url: 'http://a.com',
        savePath: '/path1',
      );
      await manager.createTask(
        title: 'Test2',
        url: 'http://b.com',
        savePath: '/path2',
      );
      // Manually update task1 to completed
      manager.tasks
          .firstWhere((t) => t.id == task1.id)
          .copyWith(
            status: DownloadStatus.completed,
          );
      await manager.clearCompleted();
      expect(manager.tasks.length, 1);
    });

    test('task listener receives updates', () async {
      final updates = <DownloadTask>[];
      manager.addTaskListener(updates.add);
      await manager.createTask(
        title: 'Test',
        url: 'http://a.com',
        savePath: '/path',
      );
      expect(updates.length, 1);
      manager.removeTaskListener(updates.add);
    });
  });

  group('CancelToken', () {
    test('isCancelled returns false initially', () {
      final token = CancelToken();
      expect(token.isCancelled, false);
    });

    test('cancel sets isCancelled to true', () {
      final token = CancelToken();
      token.cancel();
      expect(token.isCancelled, true);
    });
  });

  group('Semaphore', () {
    test('acquire decrements count', () async {
      final semaphore = Semaphore(2);
      await semaphore.acquire();
      // Should not throw
    });

    test('release increments count', () async {
      final semaphore = Semaphore(1);
      await semaphore.acquire();
      semaphore.release();
      await semaphore.acquire(); // Should succeed
    });
  });
}
