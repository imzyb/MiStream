import 'dart:io';

import 'package:storage/src/dao/settings_dao.dart';
import 'package:storage/src/database/database.dart';
import 'package:storage/src/repository/repositories.dart';
import 'package:test/test.dart';

/// 冷启动路径性能：打开库 → 读设置 + 读最近历史。
///
/// ROADMAP M2 出口标准④与 docs/07-数据库设计.md §7 的目标是 `< 50ms`。
///
/// 断言用宽松上限（500ms）挡 CI 抖动，50ms 是基准机目标；耗时会打印出来供
/// 人工核对。这里只做「不退化」护栏，不做精确基准。
void main() {
  test('冷启动：读设置 + 最近历史在可接受时间内', () async {
    final tmp = Directory.systemTemp.createTempSync('perf_test');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // 临时目录由系统回收，删除失败可忽略。
      }
    });

    // 用 Platform.pathSeparator 而不是写死反斜杠：CI 要在三平台上跑，
    // 在 Linux/macOS 上 '\\' 会变成文件名的一部分，测出来的是另一个库。
    final dbPath = '${tmp.path}${Platform.pathSeparator}mistream.db';

    // 造数据：1000 条设置 + 300 条历史（模拟真实使用量）。
    final seed = AppDatabase.open(dbPath);
    await seed.customStatement('PRAGMA foreign_keys = OFF');
    final repos = Repositories(seed);
    for (var i = 0; i < 1000; i++) {
      await repos.settings.write(SettingKey.intKey('key.$i'), i);
    }
    for (var i = 0; i < 300; i++) {
      await repos.histories.upsert(
        siteId: 1,
        vodId: 'v$i',
        vodName: '剧$i',
        playedAt: DateTime.now().toUtc().subtract(Duration(minutes: 300 - i)),
      );
    }
    await seed.close();

    // 重新打开**同一个文件** = 冷启动（新连接，走真实文件 IO + schema 校验）。
    // 这里以前打开的是另一条路径下的空库，上面造的数据一条都没被读到——
    // 测出来的是「打开空库要多久」，与出口标准无关。
    final stopwatch = Stopwatch()..start();
    final db = AppDatabase.open(dbPath);
    final repos2 = Repositories(db);
    final setting = await repos2.settings.read(
      SettingKey.intKey('key.999'),
      -1,
    );
    final recent = await repos2.histories.recent();
    stopwatch.stop();
    await db.close();

    // 先确认真的读到了数据——否则这个耗时又是在量空库。
    expect(setting, 999, reason: '没读到播种的设置，说明打开的不是那个库');
    expect(recent, isNotEmpty, reason: '没读到播种的历史');

    expect(stopwatch.elapsedMilliseconds, lessThan(500));
    // ignore: avoid_print - 性能基准测试需打印耗时供人工/基准机核对
    print('冷启动读设置+最近历史耗时: ${stopwatch.elapsedMilliseconds}ms（目标 < 50ms）');
  });
}
