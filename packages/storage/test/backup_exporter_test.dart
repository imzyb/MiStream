import 'dart:io';

import 'package:drift/drift.dart';
import 'package:storage/src/backup/backup_exporter.dart';
import 'package:storage/src/database/database.dart';
import 'package:test/test.dart';

/// 临时目录 + 内存/文件库的公共基建。
class Fixture {
  Fixture(this.tmp, this.db, this.backupFile);

  final Directory tmp;
  final AppDatabase db;
  final File backupFile;

  static Future<Fixture> create() async {
    final tmp = Directory.systemTemp.createTempSync('exporter_test');
    final db = AppDatabase.open('${tmp.path}\\data.db');
    final backupFile = File('${tmp.path}\\backup.mistream-backup');
    return Fixture(tmp, db, backupFile);
  }

  Future<void> dispose() async {
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // 临时目录最终由系统回收，删除失败可忽略。
    }
  }

  /// 写入一批固定数据：设置、搜索历史、配置源。
  Future<void> seed() async {
    await db
        .into(db.settings)
        .insert(
          SettingsCompanion.insert(
            key: 'theme',
            valueJson: '"dark"',
            updatedAt: DateTime.utc(2026),
          ),
        );
    await db
        .into(db.searchHistories)
        .insert(
          SearchHistoriesCompanion.insert(
            keyword: '海贼王',
            lastAt: DateTime.utc(2026, 1, 2),
          ),
        );
    await db
        .into(db.configSources)
        .insert(
          ConfigSourcesCompanion.insert(
            name: '我的源',
            url: const Value('https://example.com/tvbox.json'),
            rawHash: 'deadbeef',
            format: 'plain',
            createdAt: DateTime.utc(2026, 1, 3),
            updatedAt: DateTime.utc(2026, 1, 3),
          ),
        );
  }
}

void main() {
  group('BackupExporter.exportTo / inspect', () {
    test('导出生成合法 zip：含 manifest 与 data，manifest 元数据正确', () async {
      final fx = await Fixture.create();
      addTearDown(fx.dispose);
      await fx.seed();

      final exporter = BackupExporter(fx.db);
      await exporter.exportTo(fx.backupFile.path);

      expect(fx.backupFile.existsSync(), isTrue);
      expect(fx.backupFile.lengthSync(), greaterThan(0));

      final manifest = await exporter.inspect(fx.backupFile.path);
      expect(manifest.formatVersion, kBackupFormatVersion);
      expect(manifest.schemaVersion, kCurrentSchemaVersion);
      expect(manifest.sanitized, isFalse);
      expect(manifest.tables, BackupExporter.exportTables);
    });

    test('sanitize=true 时 config_source.url 被清空，其余数据不变', () async {
      final fx = await Fixture.create();
      addTearDown(fx.dispose);
      await fx.seed();

      final exporter = BackupExporter(fx.db);
      await exporter.exportTo(fx.backupFile.path, sanitize: true);

      final manifest = await exporter.inspect(fx.backupFile.path);
      expect(manifest.sanitized, isTrue);
    });
  });

  group('BackupExporter.import', () {
    test('空库导入恢复全部数据（keepLocal 默认）', () async {
      final src = await Fixture.create();
      addTearDown(src.dispose);
      await src.seed();
      final exporter = BackupExporter(src.db);
      await exporter.exportTo(src.backupFile.path);

      final dst = await Fixture.create();
      addTearDown(dst.dispose);

      final count = await BackupExporter(dst.db).import(src.backupFile.path);
      expect(count, 3);

      final setting = await dst.db.select(dst.db.settings).get();
      expect(setting, hasLength(1));
      expect(setting.single.key, 'theme');
      expect(setting.single.valueJson, '"dark"');

      final history = await dst.db.select(dst.db.searchHistories).get();
      expect(history, hasLength(1));
      expect(history.single.keyword, '海贼王');

      final sources = await dst.db.select(dst.db.configSources).get();
      expect(sources, hasLength(1));
      expect(sources.single.url, 'https://example.com/tvbox.json');
    });

    test('keepLocal：本地已有同 key 时保留本地，不覆盖', () async {
      final src = await Fixture.create();
      addTearDown(src.dispose);
      await src.seed();
      final exporter = BackupExporter(src.db);
      await exporter.exportTo(src.backupFile.path);

      final dst = await Fixture.create();
      addTearDown(dst.dispose);
      await dst.db
          .into(dst.db.settings)
          .insert(
            SettingsCompanion.insert(
              key: 'theme',
              valueJson: '"light"',
              updatedAt: DateTime.utc(2030),
            ),
          );

      await BackupExporter(dst.db).import(src.backupFile.path);

      final setting = await dst.db.select(dst.db.settings).get();
      expect(setting.single.valueJson, '"light"');
    });

    test('overwrite：本地已有同 key 时以导入数据覆盖', () async {
      final src = await Fixture.create();
      addTearDown(src.dispose);
      await src.seed();
      final exporter = BackupExporter(src.db);
      await exporter.exportTo(src.backupFile.path);

      final dst = await Fixture.create();
      addTearDown(dst.dispose);
      await dst.db
          .into(dst.db.settings)
          .insert(
            SettingsCompanion.insert(
              key: 'theme',
              valueJson: '"light"',
              updatedAt: DateTime.utc(2030),
            ),
          );

      await BackupExporter(dst.db).import(
        src.backupFile.path,
        conflict: ImportConflictStrategy.overwrite,
      );

      final setting = await dst.db.select(dst.db.settings).get();
      expect(setting.single.valueJson, '"dark"');
    });

    test('keepNewer：本地时间戳更新则保留本地，导入更新则覆盖', () async {
      final src = await Fixture.create();
      addTearDown(src.dispose);
      await src.seed();
      final exporter = BackupExporter(src.db);
      await exporter.exportTo(src.backupFile.path);

      // 本地 updated_at 比备份新 → 保留本地
      final older = await Fixture.create();
      addTearDown(older.dispose);
      await older.db
          .into(older.db.settings)
          .insert(
            SettingsCompanion.insert(
              key: 'theme',
              valueJson: '"local-newer"',
              updatedAt: DateTime.utc(2030),
            ),
          );
      await BackupExporter(older.db).import(
        src.backupFile.path,
        conflict: ImportConflictStrategy.keepNewer,
      );
      var setting = await older.db.select(older.db.settings).get();
      expect(setting.single.valueJson, '"local-newer"');

      // 本地 updated_at 比备份旧 → 被导入覆盖
      final stale = await Fixture.create();
      addTearDown(stale.dispose);
      await stale.db
          .into(stale.db.settings)
          .insert(
            SettingsCompanion.insert(
              key: 'theme',
              valueJson: '"local-old"',
              updatedAt: DateTime.utc(2020),
            ),
          );
      await BackupExporter(stale.db).import(
        src.backupFile.path,
        conflict: ImportConflictStrategy.keepNewer,
      );
      setting = await stale.db.select(stale.db.settings).get();
      expect(setting.single.valueJson, '"dark"');
    });

    test('导入时外键临时关闭：favorite 引用不存在的 site 也能写入', () async {
      final src = await Fixture.create();
      addTearDown(src.dispose);
      await src.db.customStatement('PRAGMA foreign_keys = OFF');
      await src.db
          .into(src.db.favorites)
          .insert(
            FavoritesCompanion.insert(
              siteId: 999,
              vodId: 'vod-1',
              vodName: '测试',
              createdAt: DateTime.utc(2026),
            ),
          );
      await src.db.customStatement('PRAGMA foreign_keys = ON');
      final exporter = BackupExporter(src.db);
      await exporter.exportTo(src.backupFile.path);

      final dst = await Fixture.create();
      addTearDown(dst.dispose);
      await BackupExporter(dst.db).import(src.backupFile.path);

      final favs = await dst.db.select(dst.db.favorites).get();
      expect(favs, hasLength(1));
      expect(favs.single.vodName, '测试');
    });
  });
}
