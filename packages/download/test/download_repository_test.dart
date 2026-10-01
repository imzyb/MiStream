import 'package:download/download.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

/// 两个实现跑**同一套**契约。
///
/// 只测内存实现是不够的：`InMemoryDownloadRepository` 是本模块自己写的，
/// 它绿只能说明「我按我以为的语义写了第二遍」。真库那份要面对列的可空性、
/// 单位换算（秒 ↔ 毫秒）、外键级联这些只有 drift 才有的东西 —— 两边跑同一套
/// 用例，才能保证「测试里绿的」和「真机上跑的」是同一套语义。
void main() {
  group('InMemoryDownloadRepository', () {
    runRepositoryContract(InMemoryDownloadRepository.new);
  });

  group('DriftDownloadRepository', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    runRepositoryContract(() => DriftDownloadRepository(db));

    test('删除任务会级联删掉它的分片记录', () async {
      final repo = DriftDownloadRepository(db);
      final id = await repo.insertTask(_task());
      await repo.markSegmentDone(taskId: id, seq: 0, url: 'u0', bytes: 10);
      await repo.markSegmentDone(taskId: id, seq: 1, url: 'u1', bytes: 20);

      await repo.deleteTask(id);

      final rows = await db.select(db.downloadSegments).get();
      expect(rows, isEmpty, reason: 'download_segment 的外键该带 ON DELETE CASCADE');
    });

    test('未知状态字符串读回时降级为已暂停', () async {
      final repo = DriftDownloadRepository(db);
      final id = await repo.insertTask(_task());
      // 模拟旧版本写下的、当前枚举里已不存在的状态值。
      await db.customStatement(
        "UPDATE download SET status = 'seeding' WHERE id = $id",
      );

      final task = (await repo.listTasks()).single;
      expect(task.status, DownloadStatus.paused);
    });

    test('秒与毫秒的换算往返不丢精度', () async {
      final repo = DriftDownloadRepository(db);
      const seconds = 1735689600; // 2025-01-01T00:00:00Z
      await repo.insertTask(_task(createdAt: seconds, updatedAt: seconds));

      final task = (await repo.listTasks()).single;
      expect(task.createdAt, seconds);
      expect(task.updatedAt, seconds);
    });

    test('未知总大小（-1）落库后仍读回 -1', () async {
      final repo = DriftDownloadRepository(db);
      await repo.insertTask(_task(totalBytes: -1, totalSegments: -1));

      final task = (await repo.listTasks()).single;
      expect(task.totalBytes, -1);
      expect(task.totalSegments, -1);
    });
  });
}

/// 两个实现都必须满足的行为。
void runRepositoryContract(DownloadRepository Function() create) {
  late DownloadRepository repo;

  setUp(() => repo = create());

  test('insertTask 返回自增 id，且能原样读回', () async {
    final id = await repo.insertTask(_task(title: '甲'));
    expect(id, greaterThan(0));

    final task = (await repo.listTasks()).single;
    expect(task.id, id);
    expect(task.title, '甲');
    expect(task.status, DownloadStatus.pending);
  });

  test('连续 insertTask 的 id 互不相同', () async {
    // 回归：旧实现用「当前毫秒的十六进制」当 id，同一毫秒内建的任务会互相
    // 覆盖 —— 实测建 5 个只活下来 2 个，UI 上表现为「点了新建下载，列表里
    // 没出现」。这条用例就是钉住那个行为。
    final ids = <int>[];
    for (var i = 0; i < 5; i++) {
      ids.add(await repo.insertTask(_task(title: '任务$i')));
    }

    expect(ids.toSet(), hasLength(5));
    expect(await repo.listTasks(), hasLength(5));
  });

  test('upsertTask 覆盖已有行而不是新增', () async {
    final id = await repo.insertTask(_task(title: '旧'));
    await repo.upsertTask(
      (await repo.listTasks()).single.copyWith(
        title: '新',
        status: DownloadStatus.downloading,
        downloadedBytes: 512,
      ),
    );

    final task = (await repo.listTasks()).single;
    expect(task.id, id);
    expect(task.title, '新');
    expect(task.status, DownloadStatus.downloading);
    expect(task.downloadedBytes, 512);
  });

  test('upsertTask 能写入此前不存在的任务', () async {
    await repo.upsertTask(_task(id: 7, title: '直接写入'));

    final task = (await repo.listTasks()).single;
    expect(task.id, 7);
    expect(task.title, '直接写入');
  });

  test('listTasks 按创建时间升序，同时刻按 id 升序', () async {
    // 插入顺序与时间顺序相反，确保不是「碰巧按插入序」。
    await repo.insertTask(_task(title: '晚', createdAt: 200, updatedAt: 200));
    await repo.insertTask(_task(title: '早', createdAt: 100, updatedAt: 100));
    await repo.insertTask(_task(title: '同刻甲', createdAt: 300, updatedAt: 300));
    await repo.insertTask(_task(title: '同刻乙', createdAt: 300, updatedAt: 300));

    final titles = [for (final t in await repo.listTasks()) t.title];
    expect(titles, ['早', '晚', '同刻甲', '同刻乙']);
  });

  test('listTasks 同时刻按 id 升序，与写入顺序无关', () async {
    // 为什么必须**乱序写入**才能测到「id 兜底键」：`insertTask` 分配的自增 id
    // 天然等于写入顺序，而内存 Map 的遍历序与 SQLite 的行序恰好也都是 id 序 ——
    // 于是即使实现里少了 `a.id.compareTo(b.id)` 这个兜底键，稳定排序也会把
    // 结果排对，用例照样绿。只有用 `upsertTask` 显式指定 id 并乱序写入，才能
    // 让「自然顺序」与「id 顺序」不一致。
    await repo.upsertTask(
      _task(id: 5, title: '五', createdAt: 300, updatedAt: 300),
    );
    await repo.upsertTask(
      _task(id: 3, title: '三', createdAt: 300, updatedAt: 300),
    );
    await repo.upsertTask(
      _task(id: 4, title: '四', createdAt: 300, updatedAt: 300),
    );

    final ids = [for (final t in await repo.listTasks()) t.id];
    expect(ids, [3, 4, 5]);
  });

  test('deleteTask 只删指定任务', () async {
    final keep = await repo.insertTask(_task(title: '留着'));
    final drop = await repo.insertTask(_task(title: '删掉'));

    await repo.deleteTask(drop);

    final remaining = await repo.listTasks();
    expect(remaining.map((t) => t.id), [keep]);
  });

  test('clearCompleted 只清掉已完成的任务', () async {
    // 回归：这条用例原来是**假通过** —— 它建两个任务、都还是 pending，然后
    // 对 `manager.tasks.firstWhere(...).copyWith(...)` 的结果**不赋值**（改了
    // 一个临时对象），再断言 `clearCompleted` 后剩 1 个。之所以能过，是因为
    // id 碰撞让第二个任务把第一个覆盖了，列表里本来就只剩 1 个。
    // 现在改成：真的把某个任务写成 completed，再断言只少那一个。
    final done = await repo.insertTask(
      _task(title: '已完成', status: DownloadStatus.completed),
    );
    await repo.insertTask(_task(title: '等待中甲'));
    await repo.insertTask(_task(title: '等待中乙'));

    await repo.clearCompleted();

    final remaining = await repo.listTasks();
    expect(remaining.map((t) => t.id), isNot(contains(done)));
    expect(remaining, hasLength(2));
  });

  test('markSegmentDone 幂等，重复标记不会变成两条', () async {
    final id = await repo.insertTask(_task());
    await repo.markSegmentDone(taskId: id, seq: 3, url: 'a.ts', bytes: 100);
    await repo.markSegmentDone(taskId: id, seq: 3, url: 'a.ts', bytes: 100);

    expect(await repo.doneSegmentSeqs(id), {3});
  });

  test('doneSegmentSeqs 按任务隔离', () async {
    final a = await repo.insertTask(_task(title: 'A'));
    final b = await repo.insertTask(_task(title: 'B'));
    await repo.markSegmentDone(taskId: a, seq: 0, url: 'a0', bytes: 1);
    await repo.markSegmentDone(taskId: b, seq: 5, url: 'b5', bytes: 2);

    expect(await repo.doneSegmentSeqs(a), {0});
    expect(await repo.doneSegmentSeqs(b), {5});
  });

  test('clearSegments 只清掉指定任务的分片', () async {
    final a = await repo.insertTask(_task(title: 'A'));
    final b = await repo.insertTask(_task(title: 'B'));
    await repo.markSegmentDone(taskId: a, seq: 0, url: 'a0', bytes: 1);
    await repo.markSegmentDone(taskId: b, seq: 0, url: 'b0', bytes: 1);

    await repo.clearSegments(a);

    expect(await repo.doneSegmentSeqs(a), isEmpty);
    expect(await repo.doneSegmentSeqs(b), {0});
  });

  test('没有分片记录的任务返回空集合', () async {
    final id = await repo.insertTask(_task());
    expect(await repo.doneSegmentSeqs(id), isEmpty);
  });

  test('请求头与优先级能落库并读回', () async {
    final id = await repo.insertTask(
      _task(
        headers: const {'Referer': 'https://example.com/', 'User-Agent': 'X/1'},
        priority: 5,
      ),
    );
    expect(id, greaterThan(0));

    final task = (await repo.listTasks()).single;
    expect(task.headers['Referer'], 'https://example.com/');
    expect(task.headers['User-Agent'], 'X/1');
    expect(task.priority, 5);
  });
}

DownloadTask _task({
  int id = 0,
  String title = '示例',
  String url = 'https://example.com/a.m3u8',
  String savePath = '/tmp/a',
  DownloadStatus status = DownloadStatus.pending,
  int createdAt = 1000,
  int updatedAt = 1000,
  int totalBytes = -1,
  int totalSegments = -1,
  int downloadedBytes = 0,
  int priority = 0,
  Map<String, String> headers = const {},
}) {
  return DownloadTask(
    id: id,
    title: title,
    url: url,
    savePath: savePath,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    totalBytes: totalBytes,
    totalSegments: totalSegments,
    downloadedBytes: downloadedBytes,
    priority: priority,
    headers: headers,
  );
}
