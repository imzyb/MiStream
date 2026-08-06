import 'dart:io';

import 'package:storage/src/database/database.dart';

import 'package:test/test.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.inMemory();
    });

    tearDown(() async {
      await db.close();
    });

    test('建库成功，schema 版本正确', () async {
      expect(db.schemaVersion, kCurrentSchemaVersion);
      await db.customSelect('SELECT 1').getSingle();
    });

    test('PRAGMA 生效：foreign_keys、WAL、busy_timeout', () async {
      final fk = await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle()
          .then((r) => r.data.values.first);
      expect(fk, 1);

      final jm = await db
          .customSelect('PRAGMA journal_mode')
          .getSingle()
          .then((r) => r.data.values.first);
      // 内存库恒为 memory；文件库才是 WAL（见下方文件库测试）。
      expect(jm, 'memory');

      final bt = await db
          .customSelect('PRAGMA busy_timeout')
          .getSingle()
          .then((r) => r.data.values.first);
      expect(bt, 5000);
    });

    test('全部表已创建', () async {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get()
          .then((rows) => rows.map((r) => r.data.values.first).toSet());
      const expected = {
        'config_source',
        'site',
        'history',
        'favorite',
        'download',
        'download_segment',
        'plugin',
        'plugin_setting',
        'plugin_storage',
        'live_group',
        'live_channel',
        'parse_rule',
        'site_cache',
        'setting',
        'search_history',
        'app_event',
      };
      expect(
        tables.containsAll(expected),
        isTrue,
        reason: '缺失表: ${expected.difference(tables)}',
      );
    });

    test('关键索引已创建', () async {
      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name LIKE 'ux_%' OR type='index' AND name LIKE 'ix_%'",
          )
          .get()
          .then((rows) => rows.map((r) => r.data.values.first).toSet());
      for (final expected in {
        'ux_config_source_url',
        'ux_site_scope_key',
        'ux_history_item',
        'ux_favorite_item',
        'ix_site_enabled',
        'ix_history_recent',
        'ix_download_status',
        'ix_plugin_storage_owner',
        'ix_live_channel_group',
        'ix_live_channel_name',
        'ix_site_cache_expiry',
        'ix_app_event_ts',
        'ix_app_event_scope',
      }) {
        expect(
          indexes.contains(expected),
          isTrue,
          reason: '缺索引 $expected，现有: $indexes',
        );
      }
    });

    test('文件库启用 WAL 且建库成功', () async {
      final dir = await Directory.systemTemp.createTemp('mistream_db_test_');
      final dbPath = '${dir.path}${Platform.pathSeparator}mistream.db';
      final fileDb = AppDatabase.open(dbPath);
      try {
        expect(fileDb.schemaVersion, kCurrentSchemaVersion);
        await fileDb.customSelect('SELECT 1').getSingle();
        final jm = await fileDb
            .customSelect('PRAGMA journal_mode')
            .getSingle()
            .then((r) => r.data.values.first);
        expect(jm, 'wal');
      } finally {
        await fileDb.close();
        await dir.delete(recursive: true);
      }
    });

    test('site 表的 CHECK 约束强制 config_id 与 plugin_id 恰有一个非空', () async {
      const insertSite =
          'INSERT INTO site '
          '(config_id, plugin_id, site_key, name, type_code, runtime, api, '
          'created_at, updated_at) VALUES ';
      await db.customStatement(
        'INSERT INTO config_source '
        '(name, raw_hash, format, created_at, updated_at) '
        "VALUES ('c', 'h', 'plain', 1, 1)",
      );
      // 合法：仅 config_id 非空。
      await db.customStatement(
        "$insertSite(1, NULL, 'k2', 'n', 0, 'js', 'a', 1, 1)",
      );
      // 非法：config_id 与 plugin_id 都非空。
      await expectLater(
        db.customStatement(
          "$insertSite(1, 'p', 'k3', 'n', 0, 'js', 'a', 1, 1)",
        ),
        throwsA(isA<Object>()),
      );
      // 非法：config_id 与 plugin_id 都为空。
      await expectLater(
        db.customStatement(
          "$insertSite(NULL, NULL, 'k4', 'n', 0, 'js', 'a', 1, 1)",
        ),
        throwsA(isA<Object>()),
      );
    });
  });
}
