import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import 'package:storage/src/database/database.dart';

/// 备份文件格式版本。改动导出格式（增减字段/表）必须 +1，导入端据此判断兼容。
const int kBackupFormatVersion = 1;

/// 备份文件名后缀。
const String kBackupExtension = '.mistream-backup';

/// 备份包内 manifest 条目名。
const String kManifestEntry = 'manifest.json';

/// 备份包内数据条目名。
const String kDataEntry = 'data.json';

/// 备份的元数据（`manifest.json` 内容）。
class BackupManifest {
  /// 构造一个清单对象。
  const BackupManifest({
    required this.formatVersion,
    required this.exportedAt,
    required this.schemaVersion,
    required this.tables,
    required this.sanitized,
  });

  /// 从 JSON 反序列化。
  factory BackupManifest.fromJson(Map<String, Object?> json) => BackupManifest(
    formatVersion: (json['format_version']! as num).toInt(),
    exportedAt: DateTime.parse(json['exported_at']! as String),
    schemaVersion: (json['schema_version']! as num).toInt(),
    tables: (json['tables']! as List<Object?>).cast<String>(),
    sanitized: json['sanitized'] as bool? ?? false,
  );

  /// 备份格式版本号。
  final int formatVersion;

  /// 导出时间（UTC）。
  final DateTime exportedAt;

  /// 导出时的数据库 schema 版本。
  final int schemaVersion;

  /// 参与导出的表名，顺序即 `data.json` 键序。
  final List<String> tables;

  /// 是否已脱敏（清空了 `config_source.url`）。
  final bool sanitized;

  /// 序列化为 JSON。
  Map<String, Object?> toJson() => {
    'format_version': formatVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'schema_version': schemaVersion,
    'tables': tables,
    'sanitized': sanitized,
  };
}

/// 导入时目标行已存在时的冲突处理策略。
enum ImportConflictStrategy {
  /// 保留本地（跳过导入行）。
  keepLocal,

  /// 覆盖本地（以导入行替换）。
  overwrite,

  /// 保留较新：按各表的「最近活动」时间戳列比较，导入行更新则覆盖，否则保留本地。
  keepNewer,
}

/// 本地数据库 ↔ `.mistream-backup`（zip）导出/导入。
///
/// 内容范围见 `docs/07-数据库设计.md` §5：导出 `favorite` / `history` /
/// `setting` / `search_history` / `config_source`（可脱敏 URL）/ `plugin` 清单 /
/// `download` 元数据；不含 `site_cache`、`app_event`、`download_segment` 等可重建或
/// 体积过大的数据。
class BackupExporter {
  /// 以 [db] 为基础创建导入导出工具。
  BackupExporter(this.db);

  /// 底层数据库引用。
  final AppDatabase db;

  /// 参与导出的表（顺序即 `data.json` 中的键顺序）。
  static const List<String> exportTables = <String>[
    'favorite',
    'history',
    'setting',
    'search_history',
    'config_source',
    'plugin',
    'download',
  ];

  /// 导出全部相关表到 [file]。
  ///
  /// [sanitize] 为 true 时清空 `config_source.url`（脱敏只留名称），见 docs §5。
  Future<void> exportTo(String file, {bool sanitize = false}) async {
    final data = <String, List<Map<String, Object?>>>{};
    for (final table in exportTables) {
      data[table] = await _readRows(table);
    }

    if (sanitize) {
      data['config_source'] = data['config_source']!
          .map((r) => Map<String, Object?>.of(r)..['url'] = null)
          .toList();
    }

    final manifest = BackupManifest(
      formatVersion: kBackupFormatVersion,
      exportedAt: DateTime.now(),
      schemaVersion: kCurrentSchemaVersion,
      tables: exportTables,
      sanitized: sanitize,
    );

    final archive = Archive()
      ..addFile(_textEntry(kManifestEntry, jsonEncode(manifest.toJson())))
      ..addFile(_textEntry(kDataEntry, jsonEncode(data)));

    final bytes = ZipEncoder().encode(archive);
    final out = File(file);
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
  }

  /// 读取 [file] 的 manifest（不落库），供导入前预览/校验。
  Future<BackupManifest> inspect(String file) async {
    final archive = _open(file);
    final entry = archive.findFile(kManifestEntry);
    if (entry == null) {
      throw const FormatException('备份包缺少 manifest.json');
    }
    return BackupManifest.fromJson(
      jsonDecode(_textOf(entry)) as Map<String, Object?>,
    );
  }

  /// 导入 [file] 到当前库，按 [conflict] 合并。返回参与导入的行数。
  ///
  /// 导入期间临时关闭外键：`favorite`/`history`/`download` 引用的 `site` 不在
  /// 备份内，允许先恢复再等配置重同步重建。
  Future<int> import(
    String file, {
    ImportConflictStrategy conflict = ImportConflictStrategy.keepLocal,
  }) async {
    final archive = _open(file);
    final entry = archive.findFile(kDataEntry);
    if (entry == null) {
      throw const FormatException('备份包缺少 data.json');
    }
    final data = (jsonDecode(_textOf(entry)) as Map<String, Object?>).map(
      (k, v) => MapEntry(
        k,
        (v! as List<Object?>).cast<Map<String, Object?>>(),
      ),
    );

    var imported = 0;
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction(() async {
        for (final table in exportTables) {
          final rows = data[table] ?? const <Map<String, Object?>>[];
          imported += await _writeRows(table, rows, conflict);
        }
      });
    } finally {
      await db.customStatement('PRAGMA foreign_keys = ON');
    }
    return imported;
  }

  // ---- 导出：按表读成 JSON 友好的 map ----

  Future<List<Map<String, Object?>>> _readRows(String table) async {
    final rows = await db.customSelect('SELECT * FROM $table').get();
    return rows.map((r) => r.data).toList();
  }

  // ---- 导入：按表写回，遵守冲突策略 ----

  Future<int> _writeRows(
    String table,
    List<Map<String, Object?>> rows,
    ImportConflictStrategy conflict,
  ) async {
    if (rows.isEmpty) {
      return 0;
    }
    var count = 0;
    for (final row in rows) {
      final cols = row.keys;
      final sql = _insertSql(table, cols, conflict);
      final variables = cols.map((c) => _variable(row[c])).toList();
      await db.customInsert(sql, variables: variables);
      count++;
    }
    return count;
  }

  String _insertSql(
    String table,
    Iterable<String> cols,
    ImportConflictStrategy conflict,
  ) {
    final colList = cols.join(', ');
    final placeholders = cols.map((_) => '?').join(', ');
    final insert = 'INSERT INTO $table ($colList) VALUES ($placeholders)';

    switch (conflict) {
      case ImportConflictStrategy.keepLocal:
        return '$insert ON CONFLICT DO NOTHING';
      case ImportConflictStrategy.overwrite:
        final updates = cols.map((c) => '$c = excluded.$c').join(', ');
        return '$insert ON CONFLICT DO UPDATE SET $updates';
      case ImportConflictStrategy.keepNewer:
        // 覆盖式，但仅当导入行时间戳比本地新才生效（SQLite 无表名动态，须逐行执行）。
        final updates = cols.map((c) => '$c = excluded.$c').join(', ');
        final ts = _updatedAtColumn(table);
        return ts == null
            ? '$insert ON CONFLICT DO UPDATE SET $updates'
            : '$insert ON CONFLICT DO UPDATE SET $updates '
                  'WHERE excluded.$ts > $table.$ts';
    }
  }

  /// 各表用于「保留较新」比较的时间戳列；无则按覆盖处理。
  String? _updatedAtColumn(String table) => switch (table) {
    'favorite' => 'created_at',
    'history' => 'played_at',
    'setting' => 'updated_at',
    'search_history' => 'last_at',
    'config_source' => 'updated_at',
    'plugin' => 'updated_at',
    'download' => 'updated_at',
    _ => null,
  };

  static Variable _variable(Object? value) {
    switch (value) {
      case null:
        return const Variable<Object>(null);
      case final int i:
        return Variable.withInt(i);
      case final double d:
        return Variable.withReal(d);
      case final bool b:
        return Variable.withInt(b ? 1 : 0);
      case final String s:
        return Variable.withString(s);
      case final List<int> bytes:
        return Variable.withBlob(Uint8List.fromList(bytes));
      default:
        return Variable.withString(value.toString());
    }
  }

  // ---- zip 工具 ----

  static Archive _open(String file) =>
      ZipDecoder().decodeBytes(File(file).readAsBytesSync());

  static ArchiveFile _textEntry(String name, String content) =>
      ArchiveFile(name, utf8.encode(content).length, utf8.encode(content));

  static String _textOf(ArchiveFile entry) => utf8.decode(entry.content);
}
