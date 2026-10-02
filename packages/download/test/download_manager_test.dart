import 'dart:async';

import 'package:download/download.dart';
import 'package:test/test.dart';

/// 让微任务队列跑干净。
///
/// 管理器的落库是 `unawaited` 发出的（不能为了写库把 UI 卡住），所以断言
/// 「库里是什么」之前要先让那些 Future 结算完。
Future<void> settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late InMemoryDownloadRepository repository;
  late _GateRunner runner;

  setUp(() {
    repository = InMemoryDownloadRepository();
    runner = _GateRunner();
  });

  DownloadManager managerWith({int maxConcurrent = 3}) {
    final manager = DownloadManager(
      repository: repository,
      runner: runner,
      maxConcurrent: maxConcurrent,
      // 关掉进度落库节流，让断言与调用一一对应。
      progressPersistInterval: Duration.zero,
    );
    addTearDown(manager.dispose);
    return manager;
  }

  Future<DownloadTask> addTask(
    DownloadManager manager, {
    String title = 'T',
    String url = 'http://a.com/v.mp4',
    String savePath = '/tmp/t',
    int priority = 0,
  }) => manager.createTask(
    title: title,
    url: url,
    savePath: savePath,
    priority: priority,
  );

  group('建任务', () {
    test('createTask 落库并带回数据库分配的 id', () async {
      final manager = managerWith();
      final task = await addTask(manager, title: '甲');

      expect(task.id, greaterThan(0));
      expect(task.status, DownloadStatus.pending);

      final stored = await repository.listTasks();
      expect(stored.single.id, task.id);
      expect(stored.single.title, '甲');
      expect(manager.tasks, hasLength(1));
    });

    test('同一秒内连建 5 个任务全都存在', () async {
      // 回归：旧实现用「当前毫秒的十六进制」当 id，同一毫秒内建的任务互相
      // 覆盖 —— 实测建 5 个只活下来 2 个，UI 上表现为「点了新建下载，列表里
      // 没出现」。这条用例钉住那个行为。
      final manager = managerWith();
      for (var i = 0; i < 5; i++) {
        await addTask(manager, title: '任务$i');
      }

      expect(manager.tasks, hasLength(5));
      expect(await repository.listTasks(), hasLength(5));
      expect(runner.started, isEmpty, reason: 'createTask 不该自动开始下载');
    });

    test('请求头与优先级一并落库', () async {
      final manager = managerWith();
      await manager.createTask(
        title: 'T',
        url: 'http://a.com/v.mp4',
        savePath: '/tmp/t',
        headers: const {'Referer': 'https://a.com/'},
        priority: 9,
      );

      final stored = (await repository.listTasks()).single;
      expect(stored.headers['Referer'], 'https://a.com/');
      expect(stored.priority, 9);
    });

    test('来源信息（影片 / 集）跟着落库', () async {
      final manager = managerWith();
      await manager.createTask(
        title: '庆余年',
        url: 'http://a.com/v.m3u8',
        savePath: '/tmp/庆余年/第 03 集',
        siteId: 9,
        vodId: '99887',
        episodeName: '第 03 集',
      );

      final stored = (await repository.listTasks()).single;
      expect(stored.siteId, 9);
      expect(stored.vodId, '99887');
      expect(stored.episodeName, '第 03 集');
      expect(stored.displayName, '庆余年 · 第 03 集');
    });
  });

  group('队列', () {
    test('同时最多跑 maxConcurrent 个', () async {
      final manager = managerWith(maxConcurrent: 2);
      for (var i = 0; i < 5; i++) {
        final task = await addTask(manager, title: 'T$i');
        await manager.startDownload(task.id);
      }

      expect(runner.started, hasLength(2));
      expect(manager.activeTasks, hasLength(2));
      expect(manager.pendingTasks, hasLength(3));
      expect(runner.concurrentPeak, 2);
    });

    test('一个跑完后立刻补上下一个', () async {
      final manager = managerWith(maxConcurrent: 2);
      final ids = <int>[];
      for (var i = 0; i < 3; i++) {
        final task = await addTask(manager, title: 'T$i');
        ids.add(task.id);
        await manager.startDownload(task.id);
      }

      runner.release(ids[0]);
      await settle();

      expect(runner.started, hasLength(3));
      expect(runner.concurrentPeak, 2);
    });

    test('按优先级降序出队，同级按创建顺序', () async {
      final manager = managerWith(maxConcurrent: 1);
      final low = await addTask(manager, title: '低', priority: 0);
      final high = await addTask(manager, title: '高', priority: 5);
      final mid = await addTask(manager, title: '中', priority: 1);

      await manager.startDownload(low.id);
      await manager.startDownload(high.id);
      await manager.startDownload(mid.id);

      expect(runner.started, [high.id]);

      runner.release(high.id);
      await settle();
      expect(runner.started, [high.id, mid.id]);

      runner.release(mid.id);
      await settle();
      expect(runner.started, [high.id, mid.id, low.id]);
    });

    test('pendingTasks 按调度顺序返回，tasks 仍按创建顺序', () async {
      final manager = managerWith(maxConcurrent: 1);
      final running = await addTask(manager, title: '跑着的', priority: 5);
      final waitingLow = await addTask(manager, title: '先建但优先级低');
      final waitingHigh = await addTask(manager, title: '后建但优先级高', priority: 3);

      await manager.startDownload(running.id);
      await manager.startDownload(waitingLow.id);
      await manager.startDownload(waitingHigh.id);

      expect(manager.activeTasks.map((t) => t.id), [running.id]);
      expect(
        manager.pendingTasks.map((t) => t.id),
        [waitingHigh.id, waitingLow.id],
        reason: '「等待中」要按调度顺序，不是按创建顺序',
      );
      expect(
        manager.tasks.map((t) => t.id),
        [running.id, waitingLow.id, waitingHigh.id],
        reason: '列表顺序仍按创建时间',
      );
    });
  });

  group('状态迁移与落库', () {
    test('开始 → 完成，每一步都落库', () async {
      final manager = managerWith();
      final task = await addTask(manager);

      await manager.startDownload(task.id);
      expect(
        (await repository.listTasks()).single.status,
        DownloadStatus.downloading,
      );

      runner.release(task.id);
      await settle();

      final stored = (await repository.listTasks()).single;
      expect(stored.status, DownloadStatus.completed);
      expect(stored.progress, 1);
      expect(manager.completedTasks, hasLength(1));
    });

    test('失败时记下错误，重试成功后错误被清掉', () async {
      final manager = managerWith();
      final task = await addTask(manager);
      runner.result = const DownloadResult(success: false, error: '连接超时');

      await manager.startDownload(task.id);
      runner.release(task.id);
      await settle();

      expect((await repository.listTasks()).single.error, '连接超时');
      expect(manager.failedTasks, hasLength(1));

      runner.result = const DownloadResult(
        success: true,
        totalBytes: 100,
        downloadedBytes: 100,
      );
      await manager.startDownload(task.id);
      runner.release(task.id);
      await settle();

      final stored = (await repository.listTasks()).single;
      expect(stored.status, DownloadStatus.completed);
      expect(stored.error, isNull, reason: 'clearError 该把上一次的错误清掉');
    });

    test('暂停后落库为 paused，继续后回到下载中', () async {
      final manager = managerWith();
      final task = await addTask(manager);

      await manager.startDownload(task.id);
      await manager.pauseDownload(task.id);
      await settle();

      expect(
        (await repository.listTasks()).single.status,
        DownloadStatus.paused,
      );

      // 暂停中的任务即使执行器后来返回成功，也不该被写成已完成。
      runner.release(task.id);
      await settle();
      expect(
        (await repository.listTasks()).single.status,
        DownloadStatus.paused,
      );

      await manager.resumeDownload(task.id);
      expect(runner.started.where((id) => id == task.id), hasLength(2));
      runner.release(task.id);
      await settle();
      expect(
        (await repository.listTasks()).single.status,
        DownloadStatus.completed,
      );
    });

    test('进度回调写入内存但受节流约束（节流关闭时每步都落库）', () async {
      final manager = managerWith();
      final task = await addTask(manager);
      runner.emitsProgress = true;

      await manager.startDownload(task.id);
      runner.release(task.id);
      await settle();

      // 执行器发了两次进度（40%、80%），最终完成覆盖为 100%。
      expect((await repository.listTasks()).single.progress, 1);
    });

    test('暂停后残余的进度回调不写进任务', () async {
      // 暂停只是把取消令牌置位，执行器还在收尾 —— 它随后发的进度属于「上一轮」。
      // 让它落进去，UI 上会看到暂停的任务进度条还在往前爬。
      final manager = managerWith();
      final task = await addTask(manager);
      runner.emitsProgress = true;

      await manager.startDownload(task.id);
      await manager.pauseDownload(task.id);
      runner.release(task.id);
      await settle();

      expect(manager.taskById(task.id)!.status, DownloadStatus.paused);
      expect(
        manager.taskById(task.id)!.progress,
        0,
        reason: '暂停后不该再被进度回调改写',
      );
      expect((await repository.listTasks()).single.downloadedBytes, 0);
    });

    test('取消会清掉分片记录与进度', () async {
      final manager = managerWith();
      final task = await addTask(manager, url: 'http://a.com/v.m3u8');
      await repository.markSegmentDone(
        taskId: task.id,
        seq: 0,
        url: 'u0',
        bytes: 10,
      );

      await manager.startDownload(task.id);
      await manager.cancelDownload(task.id);
      // 执行器还在等门闩，放行让它收尾，避免留下悬空的 Future。
      runner.release(task.id);
      await settle();

      final stored = (await repository.listTasks()).single;
      expect(stored.status, DownloadStatus.cancelled);
      expect(stored.downloadedSegments, 0);
      expect(await repository.doneSegmentSeqs(task.id), isEmpty);
    });

    test('deleteTask 连记录一起删', () async {
      final manager = managerWith();
      final keep = await addTask(manager, title: '留着');
      final drop = await addTask(manager, title: '删掉');

      await manager.deleteTask(drop.id);

      expect(manager.tasks.map((t) => t.id), [keep.id]);
      expect((await repository.listTasks()).map((t) => t.id), [keep.id]);
    });

    test('clearCompleted 只清掉已完成的任务', () async {
      // 回归：这条用例原来是**假通过**。它建两个任务（都还是 pending），对
      // `manager.tasks.firstWhere(...).copyWith(...)` 的结果**不赋值**（改了
      // 一个临时对象），再断言 `clearCompleted` 后剩 1 个 —— 能过只是因为 id
      // 碰撞让第二个任务覆盖了第一个。现在改成真的跑完一个任务，再断言只少
      // 那一个，而且**库里也少了**。
      final manager = managerWith();
      final done = await addTask(manager, title: '已完成');
      await manager.startDownload(done.id);
      runner.release(done.id);
      await settle();
      expect(manager.completedTasks, hasLength(1));

      await addTask(manager, title: '等待中甲');
      await addTask(manager, title: '等待中乙');

      await manager.clearCompleted();
      await settle();

      expect(manager.tasks, hasLength(2));
      expect(manager.tasks.map((t) => t.id), isNot(contains(done.id)));
      final stored = await repository.listTasks();
      expect(stored, hasLength(2));
      expect(stored.map((t) => t.id), isNot(contains(done.id)));
    });

    test('对不存在的 id 操作不抛异常', () async {
      final manager = managerWith();
      await manager.startDownload(999);
      await manager.pauseDownload(999);
      await manager.resumeDownload(999);
      await manager.cancelDownload(999);
      await manager.deleteTask(999);
      expect(manager.tasks, isEmpty);
    });
  });

  group('崩溃恢复', () {
    test('restore 把 downloading 降级为 paused，并写回库', () async {
      await repository.insertTask(_task(status: DownloadStatus.downloading));
      await repository.insertTask(_task(status: DownloadStatus.paused));
      await repository.insertTask(
        _task(status: DownloadStatus.completed, title: '早先完成的'),
      );

      final manager = managerWith();
      await manager.restore();

      expect(manager.tasks, hasLength(3));
      expect(
        manager.tasks.where((t) => t.status == DownloadStatus.downloading),
        isEmpty,
        reason: '重启后不该有任何任务自称「下载中」',
      );
      expect(manager.pausedTasks, hasLength(2));
      expect(manager.completedTasks, hasLength(1));

      final stored = await repository.listTasks();
      expect(
        stored.any((t) => t.status == DownloadStatus.downloading),
        isFalse,
        reason: '降级结果也要落库，否则下次启动又看到「下载中」',
      );
      expect(runner.started, isEmpty, reason: 'restore 只读状态，不触发调度');
    });

    test('restore 不自动开始等待中的任务', () async {
      // 恢复只负责把状态读回来。「一启动就自己下起来」是另一件事：用户上次建了
      // 任务没点开始，重启后不该变成「已开始」。
      await repository.insertTask(
        _task(status: DownloadStatus.pending, title: '等待中'),
      );

      final manager = managerWith();
      await manager.restore();

      expect(manager.pendingTasks, hasLength(1));
      expect(runner.started, isEmpty, reason: 'restore 不触发调度');
    });

    test('restore 后点继续能接着下（HLS 会带上已完成分片）', () async {
      final id = await repository.insertTask(
        _task(status: DownloadStatus.downloading, url: 'http://a.com/v.m3u8'),
      );
      await repository.markSegmentDone(
        taskId: id,
        seq: 0,
        url: 'u0',
        bytes: 10,
      );

      final manager = managerWith();
      await manager.restore();
      expect(manager.taskById(id)!.status, DownloadStatus.paused);

      await manager.resumeDownload(id);
      await settle();
      expect(runner.skipSegmentsSeen.single, {0});
      runner.release(id);
      await settle();
    });
  });

  group('HLS 续传接线', () {
    test('分片完成后立刻落库，下一轮续传据此跳过', () async {
      final manager = managerWith();
      final task = await addTask(manager, url: 'http://a.com/v.m3u8');

      // 第一次：下了 0 号分片就失败。
      runner.segmentsToReport = [(0, 'http://a.com/0.ts', 100)];
      runner.result = const DownloadResult(success: false, error: '断网');
      await manager.startDownload(task.id);
      runner.release(task.id);
      await settle();

      expect(await repository.doneSegmentSeqs(task.id), {0});

      // 第二次：执行器应收到「0 号已完成」。
      runner.segmentsToReport = [(1, 'http://a.com/1.ts', 200)];
      runner.result = const DownloadResult(
        success: true,
        totalSegments: 2,
        downloadedSegments: 2,
      );
      await manager.startDownload(task.id);
      runner.release(task.id);
      await settle();

      expect(runner.skipSegmentsSeen, [
        <int>{},
        {0},
      ], reason: '首轮没有可跳过的分片，续传那轮才带上 0 号');
      expect(await repository.doneSegmentSeqs(task.id), {0, 1});
      expect(
        (await repository.listTasks()).single.status,
        DownloadStatus.completed,
      );
    });

    test('直链任务不去查分片表', () async {
      final manager = managerWith();
      final task = await addTask(manager, url: 'http://a.com/v.mp4');

      await manager.startDownload(task.id);
      runner.release(task.id);
      await settle();

      expect(runner.skipSegmentsSeen.single, isEmpty);
    });
  });

  group('监听', () {
    test('addListener 在增删任务时被调用', () async {
      final manager = managerWith();
      var calls = 0;
      void listener() => calls++;
      manager.addListener(listener);

      final task = await addTask(manager);
      expect(calls, greaterThan(0));

      final before = calls;
      await manager.deleteTask(task.id);
      expect(calls, greaterThan(before));

      manager.removeListener(listener);
      final after = calls;
      await addTask(manager, title: '再建一个');
      expect(calls, after, reason: '移除后不该再收到通知');
    });

    test('addTaskListener 收到单个任务的变化', () async {
      final manager = managerWith();
      final seen = <DownloadStatus>[];
      manager.addTaskListener((task) => seen.add(task.status));

      final task = await addTask(manager);
      await manager.startDownload(task.id);
      runner.release(task.id);
      await settle();

      expect(seen, contains(DownloadStatus.pending));
      expect(seen, contains(DownloadStatus.downloading));
      expect(seen, contains(DownloadStatus.completed));
    });
  });

  group('删除文件的安全边界', () {
    test('配置了下载根目录时，根目录之外的路径不会被删', () async {
      // 旧实现对 `task.savePath` 直接递归删除，而调用方传的是硬编码的
      // `/downloads/<标题>` —— Windows 上会落到「当前盘根目录下的 downloads」。
      final errors = <Object>[];
      final manager = DownloadManager(
        repository: repository,
        runner: runner,
        downloadRoot: '/tmp/mistream-downloads',
        onPersistError: errors.add,
      );
      final task = await addTask(manager, savePath: '/elsewhere/重要文件');

      await manager.deleteTask(task.id);

      expect(errors, hasLength(1));
      expect('${errors.single}', contains('拒绝删除'));
      expect(manager.tasks, isEmpty, reason: '记录仍然该删掉');
    });
  });
}

/// 可控制并发与完成时机的假执行器。
///
/// 队列顺序、并发上限、状态迁移这些是管理器真正要保证的语义，一条都不该依赖
/// 真实网络 —— 这也是把执行器抽出来的原因。
class _GateRunner implements DownloadTaskRunner {
  final List<int> started = [];
  final List<Set<int>> skipSegmentsSeen = [];
  final Map<int, Completer<void>> _gates = {};

  /// 每个任务返回的结果。
  DownloadResult result = const DownloadResult(success: true);

  /// 每个任务在返回前要上报的分片 `(seq, url, bytes)`。
  List<(int, String, int)> segmentsToReport = const [];

  /// 是否在返回前发两次进度回调。
  bool emitsProgress = false;

  int _active = 0;

  /// 观察到的最大并发数。
  int concurrentPeak = 0;

  @override
  Future<DownloadResult> run(
    DownloadTask task, {
    void Function(DownloadProgress progress)? onProgress,
    HlsSegmentDone? onSegmentDone,
    Set<int> skipSegments = const {},
    CancelToken? cancelToken,
  }) async {
    started.add(task.id);
    skipSegmentsSeen.add(skipSegments);
    _active++;
    if (_active > concurrentPeak) concurrentPeak = _active;

    try {
      await _gates.putIfAbsent(task.id, Completer<void>.new).future;

      for (final (seq, url, bytes) in segmentsToReport) {
        onSegmentDone?.call(seq, url, bytes);
      }
      if (emitsProgress) {
        onProgress?.call(
          DownloadProgress(
            taskId: '${task.id}',
            status: DownloadProgressStatus.downloading,
            progress: 0.4,
            downloadedBytes: 40,
            totalBytes: 100,
          ),
        );
        onProgress?.call(
          DownloadProgress(
            taskId: '${task.id}',
            status: DownloadProgressStatus.downloading,
            progress: 0.8,
            downloadedBytes: 80,
            totalBytes: 100,
          ),
        );
      }
      if (cancelToken?.isCancelled == true) {
        return const DownloadResult(success: false, error: '已取消');
      }
      return result;
    } finally {
      _active--;
    }
  }

  /// 放行某个任务。
  ///
  /// 幂等：同一个任务可能被跑两次（暂停后继续、失败后重试），第二次调用不该
  /// 因为 Completer 已经完成而抛异常。
  void release(int taskId) {
    final gate = _gates[taskId];
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  void dispose() {}
}

DownloadTask _task({
  String title = '预置任务',
  String url = 'http://a.com/v.mp4',
  DownloadStatus status = DownloadStatus.pending,
  int createdAt = 1000,
}) => DownloadTask(
  id: 0,
  title: title,
  url: url,
  savePath: '/tmp/$title',
  status: status,
  createdAt: createdAt,
  updatedAt: createdAt,
);
