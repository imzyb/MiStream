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

/// 解析数据库文件的绝对路径。
///
/// 目录不存在时由 `AppDatabase.open` 负责创建，这里只负责拼路径。
Future<String> resolveDatabasePath() async {
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'data', kDatabaseFileName);
}
