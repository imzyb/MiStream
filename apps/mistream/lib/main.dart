/// MiStream 桌面客户端的进程入口。
///
/// 这里是**唯一**建库的地方：解析路径 → 打开库 → 装配 → 读引导状态 → 起 UI。
/// 早先 main / app / 引导页 / 详情页各自 `AppDatabase.inMemory()`，
/// 五个互不相干的空库，写进去的东西下一帧就没了。
library;

import 'package:flutter/widgets.dart';
import 'package:mistream/app/app.dart';
import 'package:mistream/application/app_assembly.dart';
import 'package:mistream/application/app_paths.dart';
import 'package:storage/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase.open(await resolveDatabasePath());
  final assembly = AppAssembly(database, Repositories(database));

  runApp(
    MiStreamApp(
      assembly: assembly,
      onboardingDone: await assembly.configInstaller.isOnboardingDone(),
    ),
  );
}
