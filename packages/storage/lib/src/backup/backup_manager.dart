import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// 数据库迁移前的文件级备份。
///
/// 职责对齐 `docs/07-数据库设计.md` §4：迁移前自动把旧库快照到
/// `data/backup/mistream-v{old}-{ts}.db`，只保留最近 3 份。
///
/// 用 `VACUUM INTO` 生成快照而非直接 `File.copy`：
/// 即使源库处于 WAL 模式（可能残留未 checkpoint 的 `-wal` 文件），
/// `VACUUM INTO` 也会在打开时完成一次原子 checkpoint，产出完整一致的
/// 单文件快照，避免拷走一个由 `-wal` 支撑而残缺的主文件。
class BackupManager {
  /// 用 [dir] 作为备份文件存放目录。
  BackupManager(this.dir);

  /// 备份文件所在目录，不存在时自动创建。
  final Directory dir;

  /// 备份 [dbPath]（迁移前的旧库），返回写入的备份文件路径。
  ///
  /// [oldVersion] 是迁移前的 schema 版本，写进文件名便于识别。
  /// 完成后清理超出 [maxKeep] 的旧备份。
  File backup({
    required String dbPath,
    required int oldVersion,
    int maxKeep = 3,
  }) {
    dir.createSync(recursive: true);

    final backupPath = p.join(
      dir.path,
      'mistream-v$oldVersion-${_timestamp()}.db',
    );
    _vacuumInto(dbPath, backupPath);

    _trimOldBackups(maxKeep);
    return File(backupPath);
  }

  /// 当前保留的备份文件，按修改时间升序（最旧在前）。
  List<File> backups() {
    if (!dir.existsSync()) return const [];
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => p.extension(f.path) == '.db')
            .toList()
          ..sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
          );
    return files;
  }

  void _trimOldBackups(int maxKeep) {
    if (maxKeep < 1) return;
    final all = backups();
    final overflow = all.length - maxKeep;
    for (final f in all.take(overflow < 0 ? 0 : overflow)) {
      f.deleteSync();
    }
  }

  static void _vacuumInto(String src, String dst) {
    final db = sqlite3.open(src);
    try {
      db.execute('VACUUM INTO ?', [dst]);
    } finally {
      db.close();
    }
  }

  /// 生成文件名时间戳（微秒 + 自增序号），保证同进程内严格唯一。
  static String _timestamp() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final serial = _serial++;
    return '$micros-$serial';
  }

  static int _serial = 0;
}
