import 'package:drift_dev/api/migrations_native.dart';
import 'package:storage/src/database/database.dart';
import 'package:storage/src/database/schema_versions.dart/schema.dart';
import 'package:test/test.dart';

void main() {
  // drift 官方迁移测试工具：用 schema 快照建出指定版本的空库，
  // 再让真实 AppDatabase 通过 onCreate/onUpgrade 走到目标版本，
  // 最后逐项对比运行时 schema 与快照，防「改了表却忘写迁移」。
  //
  // docs/07-数据库设计.md §4：CI 必须验证 v(N-1)→v(N) 与 v1→v(N)。
  // 当前 schema v3：
  //   - v1 → v2 增加 search_history.source 列
  //   - v2 → v3 增加 config_source.spider / spider_md5 列
  //   - 每条迁移路径都必须用 migrateAndValidate 验证。
  group('schema 迁移验证', () {
    final verifier = SchemaVerifier(GeneratedHelper());

    test('对外发布的 kCurrentSchemaVersion 与数据库实际 schemaVersion 一致', () async {
      final db = AppDatabase.inMemory();
      expect(db.schemaVersion, kCurrentSchemaVersion);
      expect(
        db.schemaVersion,
        3,
        reason:
            'drift schema dump 工具只能解析 schemaVersion 的字面量值。 '
            'getter 必须写成数字字面量，请保持与 kCurrentSchemaVersion 同步',
      );
      await db.close();
    });

    test('v3 空库用 AppDatabase 打开后，运行时 schema 与 v3 快照一致', () async {
      final start = await verifier.startAt(3);

      final db = AppDatabase(start);
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.validateDatabaseSchema();
      await db.close();
      await start.close();
    });

    test('v3 → v3（最新）路径可用 migrateAndValidate 验证', () async {
      final start = await verifier.startAt(3);

      final db = AppDatabase(start);
      await verifier.migrateAndValidate(db, kCurrentSchemaVersion);
      await db.close();
      await start.close();
    });

    test('v2 → v3 迁移路径验证（spider 列）', () async {
      final start = await verifier.startAt(2);

      final db = AppDatabase(start);
      await verifier.migrateAndValidate(db, kCurrentSchemaVersion);
      await db.close();
      await start.close();
    });

    test('v1 → v3 迁移路径验证', () async {
      final start = await verifier.startAt(1);

      final db = AppDatabase(start);
      await verifier.migrateAndValidate(db, kCurrentSchemaVersion);
      await db.close();
      await start.close();
    });
  });
}
