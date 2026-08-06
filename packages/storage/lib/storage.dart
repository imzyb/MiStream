/// 本地存储：drift 数据库、迁移、DAO、备份。
///
/// 见 `docs/07-数据库设计.md` 与 [ADR-008](../../docs/adr/008-数据持久化用-drift.md)。
///
/// 生成代码由 build_runner 产出（`melos run generate`），不提交仓库。
library;

export 'package:drift/drift.dart'
    show
        // 常用表/列类型与查询基类，供调用方组合查询。
        // 不导出一整包，避免命名冲突。
        Expression,
        Table;

export 'src/backup/backup_exporter.dart'
    show
        BackupExporter,
        BackupManifest,
        ImportConflictStrategy,
        kBackupExtension,
        kBackupFormatVersion;
export 'src/backup/backup_manager.dart' show BackupManager;
export 'src/dao/settings_dao.dart';
export 'src/dao/site_cache_dao.dart';
export 'src/database/database.dart' show AppDatabase, kCurrentSchemaVersion;
export 'src/database/tables.dart';
export 'src/database/type_converters.dart' show utcMillis;
