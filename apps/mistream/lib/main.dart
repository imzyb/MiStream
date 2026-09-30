/// MiStream 桌面客户端的进程入口。
///
/// 这里是**唯一**建库的地方：解析路径 → 打开库 → 装配 → 读引导状态 → 读外观
/// 选择与动效偏好 → 起 UI。
/// 早先 main / app / 引导页 / 详情页各自 `AppDatabase.inMemory()`，
/// 五个互不相干的空库，写进去的东西下一帧就没了。
library;

import 'package:flutter/widgets.dart';
import 'package:mistream/app/app.dart';
import 'package:mistream/app/motion_controller.dart';
import 'package:mistream/app/router.dart';
import 'package:mistream/app/theme_controller.dart';
import 'package:mistream/application/app_assembly.dart';
import 'package:mistream/application/app_paths.dart';
import 'package:storage/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase.open(await resolveDatabasePath());
  final assembly = AppAssembly(database, Repositories(database));
  final settings = assembly.repositories.settings;

  // 供路由器使用的全局装配
  setGlobalRouterAssembly(assembly);

  // EPG 模板来自配置的 `lives[]`，而配置原文不入库 —— 单独存了一份，启动时
  // 恢复进拉取器，否则重启后节目单永远是空的。
  await assembly.restoreLiveEpgTemplates();

  runApp(
    MiStreamApp(
      assembly: assembly,
      onboardingDone: await assembly.configInstaller.isOnboardingDone(),
      // 外观选择在这里读出、交给树根持有：切换它要重建整棵树的主题，
      // 不能由设置页自己 setState（那样得重启才生效）。
      themeController: await ThemeController.load(settings),
      // 「减少动效」同理：它改的是树根注入的 MediaQuery。
      motionController: await MotionController.load(settings),
    ),
  );
}
