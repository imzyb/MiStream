import 'package:download/download.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadTask', () {
    test('fromJson 读回全部字段', () {
      final json = {
        'id': 42,
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
        'priority': 3,
        'headers': {'Referer': 'https://example.com/'},
      };
      final task = DownloadTask.fromJson(json);
      expect(task.id, 42);
      expect(task.title, 'Test Video');
      expect(task.url, 'http://example.com/video.m3u8');
      expect(task.savePath, '/downloads/video');
      expect(task.status, DownloadStatus.downloading);
      expect(task.progress, 0.5);
      expect(task.downloadedBytes, 1024);
      expect(task.totalBytes, 2048);
      expect(task.downloadedSegments, 5);
      expect(task.totalSegments, 10);
      expect(task.priority, 3);
      expect(task.headers['Referer'], 'https://example.com/');
    });

    test('fromJson 缺 id 时落到 0（表示尚未落库）', () {
      final task = DownloadTask.fromJson({'title': 'x'});
      expect(task.id, 0);
      expect(task.status, DownloadStatus.pending);
      expect(task.totalBytes, -1);
    });

    test('toJson 往返', () {
      const task = DownloadTask(
        id: 7,
        title: 'Test Video',
        url: 'http://example.com/video.m3u8',
        savePath: '/downloads/video',
        status: DownloadStatus.downloading,
        progress: 0.5,
        createdAt: 1000000,
        updatedAt: 1000100,
        headers: {'Referer': 'r'},
        priority: 2,
      );
      final restored = DownloadTask.fromJson(task.toJson());
      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.status, task.status);
      expect(restored.progress, task.progress);
      expect(restored.headers, task.headers);
      expect(restored.priority, task.priority);
    });

    test('copyWith 返回新实例，原对象不变', () {
      const task = DownloadTask(
        id: 1,
        title: 'Test',
        url: 'http://a.com',
        savePath: '/path',
        createdAt: 0,
        updatedAt: 0,
      );
      final updated = task.copyWith(title: 'Updated', progress: 0.5);
      expect(updated.title, 'Updated');
      expect(updated.progress, 0.5);
      expect(task.title, 'Test');
    });

    test('copyWith(error: null) 清不掉错误，必须显式 clearError', () {
      // 这条钉的是一个很容易踩的坑：`error` 用 `??` 兜底之后，
      // `copyWith(error: null)` 表达不了「把错误清掉」，于是重试成功的任务会
      // 一直挂着上一次的错误信息。
      const failed = DownloadTask(
        id: 1,
        title: 'T',
        url: 'http://a.com',
        savePath: '/p',
        createdAt: 0,
        updatedAt: 0,
        error: 'boom',
      );
      expect(failed.copyWith(status: DownloadStatus.pending).error, 'boom');
      expect(
        failed.copyWith(status: DownloadStatus.pending, clearError: true).error,
        isNull,
      );
    });

    test('isResumable：暂停与失败可续，完成与取消不可续', () {
      DownloadTask withStatus(DownloadStatus status) => DownloadTask(
        id: 1,
        title: 'T',
        url: 'http://a.com',
        savePath: '/p',
        createdAt: 0,
        updatedAt: 0,
        status: status,
      );
      expect(withStatus(DownloadStatus.paused).isResumable, isTrue);
      // 失败也算可续：直链靠 Range、HLS 靠 download_segment 跳过已完成分片。
      expect(withStatus(DownloadStatus.failed).isResumable, isTrue);
      expect(withStatus(DownloadStatus.completed).isResumable, isFalse);
      expect(withStatus(DownloadStatus.cancelled).isResumable, isFalse);
      expect(withStatus(DownloadStatus.downloading).isResumable, isFalse);
    });

    test('isCompleted / isFailed / isPending', () {
      DownloadTask withStatus(DownloadStatus status) => DownloadTask(
        id: 1,
        title: 'T',
        url: 'http://a.com',
        savePath: '/p',
        createdAt: 0,
        updatedAt: 0,
        status: status,
      );
      expect(withStatus(DownloadStatus.completed).isCompleted, isTrue);
      expect(withStatus(DownloadStatus.failed).isFailed, isTrue);
      expect(withStatus(DownloadStatus.pending).isPending, isTrue);
      expect(withStatus(DownloadStatus.completed).isFailed, isFalse);
    });

    test('isHls 只看 m3u8 子串，大小写与查询串都不影响', () {
      DownloadTask withUrl(String url) => DownloadTask(
        id: 1,
        title: 'T',
        url: url,
        savePath: '/p',
        createdAt: 0,
        updatedAt: 0,
      );
      expect(withUrl('https://a.com/x.m3u8').isHls, isTrue);
      expect(withUrl('https://a.com/x.M3U8?token=abc').isHls, isTrue);
      expect(withUrl('https://a.com/x.mp4').isHls, isFalse);
      expect(withUrl('https://a.com/x.m3u8').mediaType, 'hls');
      expect(withUrl('https://a.com/x.mp4').mediaType, 'direct');
    });

    test('相等性只按 id', () {
      const t1 = DownloadTask(
        id: 1,
        title: 'A',
        url: 'http://a.com',
        savePath: '/a',
        createdAt: 0,
        updatedAt: 0,
      );
      const t2 = DownloadTask(
        id: 1,
        title: 'B',
        url: 'http://b.com',
        savePath: '/b',
        createdAt: 0,
        updatedAt: 0,
      );
      const t3 = DownloadTask(
        id: 2,
        title: 'A',
        url: 'http://a.com',
        savePath: '/a',
        createdAt: 0,
        updatedAt: 0,
      );
      expect(t1, equals(t2));
      expect(t1 == t3, isFalse);
    });
  });

  group('请求头编解码', () {
    test('空表编码为 null', () {
      expect(encodeHeaders(const {}), isNull);
    });

    test('往返保持键值', () {
      const headers = {'Referer': 'https://a.com/', 'User-Agent': 'X/1'};
      expect(decodeHeaders(encodeHeaders(headers)), headers);
    });

    test('坏值返回空表而不抛异常', () {
      expect(decodeHeaders('{不是 json'), isEmpty);
      expect(decodeHeaders('[1,2,3]'), isEmpty);
      expect(decodeHeaders(''), isEmpty);
      expect(decodeHeaders(null), isEmpty);
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

    test('isDownloading / isCompleted / isFailed', () {
      expect(
        const DownloadProgress(
          taskId: 't1',
          status: DownloadProgressStatus.downloading,
        ).isDownloading,
        isTrue,
      );
      expect(
        const DownloadProgress(
          taskId: 't1',
          status: DownloadProgressStatus.completed,
        ).isCompleted,
        isTrue,
      );
      expect(
        const DownloadProgress(
          taskId: 't1',
          status: DownloadProgressStatus.failed,
        ).isFailed,
        isTrue,
      );
    });
  });

  group('CancelToken', () {
    test('初始未取消，cancel 后为已取消', () {
      final token = CancelToken();
      expect(token.isCancelled, isFalse);
      token.cancel();
      expect(token.isCancelled, isTrue);
    });
  });

  group('Semaphore', () {
    test('名额够时 acquire 立即返回', () async {
      final semaphore = Semaphore(2);
      await semaphore.acquire();
      await semaphore.acquire();
      // 两次都拿到名额，没有阻塞。
      expect(true, isTrue);
    });

    test('超出上限的 acquire 会等到 release 才放行', () async {
      // 原用例只写了「acquire 不抛异常」和「release 后还能 acquire」，两句都
      // 没有断言 —— 把 `acquire` 改成永远立即返回也能过。这里断言真正的语义。
      final semaphore = Semaphore(1);
      await semaphore.acquire();

      var secondAcquired = false;
      final pending = semaphore.acquire().then((_) => secondAcquired = true);

      await Future<void>.delayed(Duration.zero);
      expect(secondAcquired, isFalse, reason: '名额已满，第二个 acquire 该在等');

      semaphore.release();
      await pending;
      expect(secondAcquired, isTrue);
    });

    test('release 按先来后到唤醒等待者', () async {
      final semaphore = Semaphore(1);
      await semaphore.acquire();

      final order = <String>[];
      final first = semaphore.acquire().then((_) => order.add('first'));
      final second = semaphore.acquire().then((_) => order.add('second'));

      semaphore.release();
      await first;
      semaphore.release();
      await second;

      expect(order, ['first', 'second']);
    });
  });
}
