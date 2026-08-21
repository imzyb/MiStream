/// MiStream ��面客户端的进程入口。
///
/// 这里是**唯一**建库的地方：解��路径 -> 打开库 -> ���配 -> 读引导状态 -> 读主题模式 -> 起 UI。
library;

import 'package:flutter/material.dart';
import 'package:mistream/app/app.dart';
import 'package:mistream/app/router.dart';
import 'package:mistream/application/app_assembly.dart';
import 'package:mistream/application/app_paths.dart';
import 'package:storage/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase.open(await resolveDatabasePath());
  final assembly = AppAssembly(database, Repositories(database));

  // 供路由��使用的全局装配
  setGlobalRouterAssembly(assembly);

  // 读取主题模式
  final themeIndex = await assembly.repositories.settings.read(
    SettingKey<int>(
      'theme_mode',
      (json) => (json! as num).toInt(),
      (value) => value,
    ),
    0,
  );
  final themeMode = ThemeMode.values[themeIndex.clamp(0, 2)];

  runApp(
    MiStreamApp(
      assembly: assembly,
      onboardingDone: await assembly.configInstaller.isOnboardingDone(),
      themeMode: themeMode,
    ),
  );
}
