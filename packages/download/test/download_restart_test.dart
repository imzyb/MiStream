import 'dart:async';
import 'dart:io';

import 'package:download/download.dart';
import 'package:path/path.dart' as p;
import 'package:storage/storage.dart';
import 'package:test/test.dart';

/// 等到 [condition] 成立，或超时返回。
///
/// ⚠️ **不能用「让渡几次微任务」来等文件库**：`AppDatabase.open` 走的是
/// `NativeDatabase.createInBackground`（一个 isolate），一次读写要走真实的
/// 跨 isolate 往返，耗时随机器负载波动。固定次数的 `Future.delayed(Duration.zero)`
/// 在负载高时不够用 —— 表现出来就是「同一条用例时红时绿」，而且反向验证里
/// 会把一堆**无关的** mutation 也带红，让人误判覆盖情况。
///
/// 判据要写成「等到某个可观测的状态出现」，而不是「等 N 次」。
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// 「强制杀进程后重启，任务状态正确恢复」这条出口标准的等价复现。
///
/// 真的去杀一个进程在这里做不到，但那条标准要保证的其实是**三件可测的事**：
/// 1. 状态真的落到了**文件库**上（不是内存库、也不是某个进程内的缓存）；
/// 2. 换一个数据库连接就能读到它（等价于新进程重新打开库）；
/// 3. 上次残留的「下载中」在恢复时被降级为「已暂停」，而且**降级结果也持久**，
///    否则第二次启动又会看到一堆假的「下载中」。
///
/// 所以这里用**文件库**而不是 `AppDatabase.inMemory()`：内存库在连接关闭时
/// 就没了，「重启后还在」这件事它根本证明不了。
void main() {
  late Directory dir;
  late String dbPath;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mistream_dl_restart_');
    dbPath = p.join(dir.path, 'mistream.db');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('文件库里写下的任务，换一个连接仍然读得到', () async {
    final first = AppDatabase.open(dbPath);
    final id = await DriftDownloadRepository(first).insertTask(
      _task(status: DownloadStatus.downloading),
    );
    await first.close();

    final second = AppDatabase.open(dbPath);
    try {
      final rows = await DriftDownloadRepository(second).listTasks();
      expect(rows, hasLength(1));
      expect(rows.single.id, id);
      expect(rows.single.title, '上一轮没下完的');
      // 库里存的就是原样写进去的状态 —— 降级是**恢复**这一步的职责，不是
      // 落库这一步的。分开之后，「谁把 downloading 改掉的」才有唯一答案。
      expect(rows.single.status, DownloadStatus.downloading);
    } finally {
      await second.close();
    }
  });

  test('重启后恢复：残留的「下载中」降级为「已暂停」且持久', () async {
    // 第一次「进程」：任务下到一半，进程没了。
    final first = AppDatabase.open(dbPath);
    final id = await DriftDownloadRepository(first).insertTask(
      _task(status: DownloadStatus.downloading),
    );
    await first.close();

    // 第二次「进程」：新连接 → 新管理器 → 恢复。
    final second = AppDatabase.open(dbPath);
    final manager = DownloadManager(
      repository: DriftDownloadRepository(second),
      runner: _NeverRuns(),
    );
    try {
      await manager.restore();

      expect(manager.tasks, hasLength(1));
      expect(
        manager.taskById(id)!.status,
        DownloadStatus.paused,
        reason: '崩溃后没有任务真的在下，必须降级',
      );
      expect(
        manager.taskById(id)!.isResumable,
        isTrue,
        reason: '降级成 paused 才能点「继续」续上；降成 pending 会被队列立刻重跑',
      );

      // 降级结果写回了库。
      final stored = await DriftDownloadRepository(second).listTasks();
      expect(stored.single.status, DownloadStatus.paused);
    } finally {
      manager.dispose();
      await second.close();
    }

    // 第三次「进程」：确认降级是持久的，而不是只改了内存。
    final third = AppDatabase.open(dbPath);
    try {
      final rows = await DriftDownloadRepository(third).listTasks();
      expect(rows.single.status, DownloadStatus.paused);
      expect(rows.single.id, id);
    } finally {
      await third.close();
    }
  });

  test('已完成的任务重启后仍是已完成，不会被降级', () async {
    final first = AppDatabase.open(dbPath);
    final repository = DriftDownloadRepository(first);
    final done = await repository.insertTask(
      _task(title: '已下完的', status: DownloadStatus.completed),
    );
    await repository.markSegmentDone(
      taskId: done,
      seq: 0,
      url: 'u0',
      bytes: 10,
    );
    await repository.markSegmentDone(
      taskId: done,
      seq: 1,
      url: 'u1',
      bytes: 20,
    );
    await first.close();

    final second = AppDatabase.open(dbPath);
    final manager = DownloadManager(
      repository: DriftDownloadRepository(second),
      runner: _NeverRuns(),
    );
    try {
      await manager.restore();

      expect(manager.completedTasks, hasLength(1));
      // 分片记录也活着 —— 它是「这集下全了没有」的唯一凭据。
      expect(await DriftDownloadRepository(second).doneSegmentSeqs(done), {
        0,
        1,
      });
    } finally {
      manager.dispose();
      await second.close();
    }
  });

  test('分片记录跨重启保留，续传时据此跳过', () async {
    final first = AppDatabase.open(dbPath);
    final repository = DriftDownloadRepository(first);
    final id = await repository.insertTask(
      _task(url: 'https://a.com/v.m3u8', status: DownloadStatus.downloading),
    );
    await repository.markSegmentDone(taskId: id, seq: 0, url: 'u0', bytes: 10);
    await repository.markSegmentDone(taskId: id, seq: 3, url: 'u3', bytes: 40);
    await first.close();

    final second = AppDatabase.open(dbPath);
    final runner = _NeverRuns();
    final manager = DownloadManager(
      repository: DriftDownloadRepository(second),
      runner: runner,
    );
    try {
      await manager.restore();
      await manager.resumeDownload(id);
      // 库是文件库（后台 isolate），不能靠固定次数的微任务让渡来等它。
      await waitFor(() => runner.skipSegmentsSeen.isNotEmpty);

      expect(
        runner.skipSegmentsSeen.single,
        {0, 3},
        reason: '重启后续传要跳过上次已经下好的那两片',
      );
    } finally {
      manager.dispose();
      await second.close();
    }
  });
}

DownloadTask _task({
  String title = '上一轮没下完的',
  String url = 'https://a.com/v.mp4',
  DownloadStatus status = DownloadStatus.pending,
}) => DownloadTask(
  id: 0,
  title: title,
  url: url,
  savePath: '/tmp/$title',
  status: status,
  createdAt: 1000,
  updatedAt: 1000,
);

/// 不会真的跑起来的执行器：这些用例只关心状态与记录，不关心下载本身。
class _NeverRuns implements DownloadTaskRunner {
  final List<Set<int>> skipSegmentsSeen = [];

  @override
  Future<DownloadResult> run(
    DownloadTask task, {
    void Function(DownloadProgress progress)? onProgress,
    HlsSegmentDone? onSegmentDone,
    Set<int> skipSegments = const {},
    CancelToken? cancelToken,
  }) async {
    skipSegmentsSeen.add(skipSegments);
    // 永远不返回：把任务钉在「下载中」，方便断言启动时的状态。
    return Completer<DownloadResult>().future;
  }

  @override
  void dispose() {}
}
