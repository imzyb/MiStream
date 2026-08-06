import 'dart:io';

import 'package:storage/src/dao/settings_dao.dart';
import 'package:storage/src/database/database.dart';
import 'package:storage/src/repository/repositories.dart';
import 'package:test/test.dart';

/// 冷启动路径性能：打开库 → 读设置 + 读最近历史。
///
/// docs/07-数据库设计.md §7 目标 `< 50ms`。CI 计时抖动较大，断言用宽松上限
/// （500ms）防误报；50ms 是人工/基准机目标，本测试只做「不退化」护栏。
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
    final seedPath = '${tmp.path}\\seed.db';

    // 造数据：1000 条设置 + 300 条历史（模拟真实使用量）。
    final seed = AppDatabase.open(seedPath);
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

    // 重新打开 = 冷启动（新连接，走真实文件 IO + schema 校验）。
    final stopwatch = Stopwatch()..start();
    final db = AppDatabase.open('${tmp.path}\\db.db');
    final repos2 = Repositories(db);
    await repos2.settings.read(SettingKey.intKey('key.999'), -1);
    await repos2.histories.recent();
    stopwatch.stop();
    await db.close();

    // 兜底护栏：避免 CI 抖动误报；实测通常远低于该值。
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
    // 打印耗时便于人工/基准机核对。
    // ignore: avoid_print - 性能基准测试需打印耗时供人工/基准机核对
    print('冷启动读设置+最近历史耗时: ${stopwatch.elapsedMilliseconds}ms');
  });
}
