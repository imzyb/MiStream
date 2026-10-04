/// 应用数据目录与数据库路径解析。
///
/// 位置遵循 `docs/07-数据库设计.md` 开头的规定：
/// Windows `%APPDATA%/MiStream/data/`，macOS `~/Library/Application Support/MiStream/`，
/// Linux `~/.local/share/MiStream/`。这三个正是 `path_provider` 的
/// `getApplicationSupportDirectory()` 在各平台返回的目录，故直接复用，
/// 不自行拼接环境变量——后者在受限账户或重定向过的用户目录下会出错。
library;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 数据库文件名。
const kDatabaseFileName = 'mistream.db';

/// 下载根目录名（位于应用数据目录之下）。
const kDownloadsDirName = 'downloads';

/// 解析数据库文件的绝对路径。
///
/// 目录不存在时由 `AppDatabase.open` 负责创建，这里只负责拼路径。
Future<String> resolveDatabasePath() async {
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'data', kDatabaseFileName);
}

/// 解析下载根目录的绝对路径。
///
/// 放在应用数据目录之下，而不是硬编码 `/downloads/<标题>`：后者在 Windows 上
/// 会解析成「**当前盘根目录**下的 downloads」（`I:\downloads`），在 macOS/Linux
/// 上则是字面的 `/downloads`（普通用户没有写权限）。而且它越出了应用目录，
/// 取消下载时那句 `Directory(savePath).delete(recursive: true)` 就在应用的地盘
/// 之外递归删东西。
Future<String> resolveDownloadsPath() async {
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, kDownloadsDirName);
}
