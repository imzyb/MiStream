import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:storage/src/backup/backup_manager.dart';
import 'package:storage/src/database/database.dart';
import 'package:test/test.dart';

/// 造一个指定 user_version 且含一行数据的旧库文件，模拟「升级前的真实库」。
File createLegacyDb(Directory dir, {required int version}) {
  final path = '${dir.path}\\legacy.db';
  final db = sqlite3.open(path);
  try {
    db
      ..execute('PRAGMA user_version = $version')
      ..execute(
        'CREATE TABLE plugin (plugin_id TEXT PRIMARY KEY, '
        'name TEXT NOT NULL, version TEXT NOT NULL, '
        'install_path TEXT NOT NULL, manifest_json TEXT NOT NULL, '
        'integrity_hash TEXT NOT NULL, enabled INTEGER NOT NULL '
        'DEFAULT 1, installed_at INTEGER NOT NULL, updated_at INTEGER NOT '
        'NULL)',
      )
      ..execute(
        'INSERT INTO plugin (plugin_id, name, version, install_path, '
        'manifest_json, integrity_hash, installed_at, updated_at) VALUES '
        "('demo', 'Demo', '1.0.0', '/x', '{}', 'abc', 1, 1)",
      );
  } finally {
    db.close();
  }
  return File(path);
}

void main() {
  group('BackupManager', () {
    test('备份生成 mistream-v{old}-{ts}.db 快照且数据完整', () {
      final tmp = Directory.systemTemp.createTempSync('backup_test');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final src = createLegacyDb(tmp, version: 1);

      final manager = BackupManager(Directory('${tmp.path}\\backup'));
      final backup = manager.backup(dbPath: src.path, oldVersion: 1);

      expect(backup.existsSync(), isTrue);
      expect(backup.path, contains('mistream-v1-'));
      expect(manager.backups(), hasLength(1));

      final check = sqlite3.open(backup.path);
      try {
        expect(
          check.select('PRAGMA user_version').single.columnAt(0),
          1,
        );
        expect(check.select('SELECT name FROM plugin').single['name'], 'Demo');
      } finally {
        check.close();
      }
    });

    test('只保留最近 3 份，超出即清理最旧', () {
      final tmp = Directory.systemTemp.createTempSync('backup_trim');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final src = createLegacyDb(tmp, version: 1);
      final manager = BackupManager(Directory('${tmp.path}\\backup'));

      for (var i = 0; i < 5; i++) {
        manager.backup(dbPath: src.path, oldVersion: 1);
      }

      expect(manager.backups(), hasLength(3));
    });

    test('backups() 对空目录返回空列表', () {
      final tmp = Directory.systemTemp.createTempSync('backup_empty');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final manager = BackupManager(Directory('${tmp.path}\\nope'));

      expect(manager.backups(), isEmpty);
    });
  });

  group('AppDatabase 迁移备份', () {
    test('打开落后版本库时先备份旧库，再尝试迁移', () async {
      final tmp = Directory.systemTemp.createTempSync('migrate_backup');
      addTearDown(() {
        // Windows 下后台 isolate 释放文件句柄是异步的，close 后立刻删除
        // 可能仍被占用；临时目录由系统回收，删除失败可安全忽略。
        try {
          tmp.deleteSync(recursive: true);
        } on FileSystemException {
          // 删除失败可忽略，临时目录最终会被系统清理。
        }
      });

      // 用当前 schema 建一个真实库文件，再把 user_version 改回 0，
      // 模拟「结构未知的旧库」。AppDatabase.open 应因 version 落后
      // 先触发备份。
      final fresh = AppDatabase.open('${tmp.path}\\stale.db');
      await fresh.customStatement('PRAGMA foreign_keys = OFF');
      await fresh.close();

      final legacy = File('${tmp.path}\\stale.db');
      final raw = sqlite3.open(legacy.path);
      try {
        raw.execute('PRAGMA user_version = 0');
      } finally {
        raw.close();
      }

      final backupDir = Directory('${tmp.path}\\backup');
      final stale = AppDatabase.open(
        legacy.path,
        backups: BackupManager(backupDir),
      );
      await stale.close();

      expect(BackupManager(backupDir).backups(), isNotEmpty);
    });

    test('已是最新版本时不产生备份文件', () async {
      final tmp = Directory.systemTemp.createTempSync('no_backup');
      addTearDown(() {
        try {
          tmp.deleteSync(recursive: true);
        } on FileSystemException {
          // 删除失败可忽略，临时目录最终会被系统清理。
        }
      });
      final db = AppDatabase.open('${tmp.path}\\fresh.db');
      await db.customStatement('PRAGMA foreign_keys = OFF');
      expect(db.schemaVersion, kCurrentSchemaVersion);
      await db.close();

      expect(
        BackupManager(Directory('${tmp.path}\\backup')).backups(),
        isEmpty,
      );
    });

    test('迁移失败抛异常且备份仍在，库文件未被半迁移污染', () async {
      final tmp = Directory.systemTemp.createTempSync('migrate_fail');
      addTearDown(() {
        AppDatabase.debugFailMigrations = false;
        try {
          tmp.deleteSync(recursive: true);
        } on FileSystemException {
          // 删除失败可忽略，临时目录最终会被系统清理。
        }
      });

      // 造一个 v1 库：先建最新库，再把 user_version 改回 1。
      final fresh = AppDatabase.open('${tmp.path}\\stale.db');
      await fresh.customStatement('PRAGMA foreign_keys = OFF');
      await fresh.close();
      final raw = sqlite3.open('${tmp.path}\\stale.db');
      try {
        raw.execute('PRAGMA user_version = 1');
      } finally {
        raw.close();
      }

      final backupDir = Directory('${tmp.path}\\backup');
      AppDatabase.debugFailMigrations = true;

      // 迁移失败：drift 在事务内回滚。drift 惰性打开连接，需触发一次查询
      // 才会真正执行迁移；打开失败后连接进入错误态。
      final db = AppDatabase.open(
        '${tmp.path}\\stale.db',
        backups: BackupManager(backupDir),
      );
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
      await db.close();

      // 失败前已备份旧库，可直接用备份恢复。
      final backups = BackupManager(backupDir).backups();
      expect(backups, isNotEmpty);

      // 库文件仍是可打开的 v1 库（未被半迁移破坏）。
      final reopened = sqlite3.open('${tmp.path}\\stale.db');
      try {
        final version = reopened
            .select('PRAGMA user_version')
            .single
            .columnAt(0);
        expect(version, lessThan(kCurrentSchemaVersion));
      } finally {
        reopened.close();
      }
    });
  });
}
