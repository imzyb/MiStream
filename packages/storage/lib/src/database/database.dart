import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:storage/src/database/tables.dart';
import 'package:storage/src/database/type_converters.dart' show utcMillis;

part 'database.g.dart';

/// 当前 schema 版本。独立于 `appVersion` 演进，每次改表必须 +1 并写迁移。
///
/// `docs/07-数据库设计.md` §4
const int kCurrentSchemaVersion = 1;

/// MiStream 本地数据库。
///
/// 主进程独占写；WAL + `foreign_keys=ON` + `busy_timeout=5000`（见
/// `docs/07-数据库设计.md` §1）。迁移前自动备份、失败回滚并拒绝启动。
@DriftDatabase(
  tables: [
    ConfigSources,
    Sites,
    Histories,
    Favorites,
    Downloads,
    DownloadSegments,
    Plugins,
    PluginSettings,
    PluginStorages,
    LiveGroups,
    LiveChannels,
    ParseRules,
    SiteCaches,
    Settings,
    SearchHistories,
    AppEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// 用给定的 [QueryExecutor] 构造数据库。
  AppDatabase(super.e);

  /// 打开位于 [filePath] 的数据库文件（目录不存在会自动创建）。
  AppDatabase.open(String filePath) : super(_openConnection(filePath));

  /// 内存库，测试用。
  AppDatabase.inMemory() : super(NativeDatabase.memory(setup: _configure));

  /// 应用 PRAGMA：WAL、外键、busy_timeout。
  static void _configure(Database db) {
    db
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA foreign_keys = ON')
      ..execute('PRAGMA busy_timeout = 5000');
  }

  static QueryExecutor _openConnection(String filePath) {
    final dir = p.dirname(filePath);
    Directory(dir).createSync(recursive: true);
    return NativeDatabase.createInBackground(
      File(filePath),
      setup: _configure,
    );
  }

  @override
  int get schemaVersion => kCurrentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // M2c 落地：逐版本迁移 + 迁移前备份 + 失败回滚。
    },
  );
}
