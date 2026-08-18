/// 应用根 widget：装配主题、路由与全局 overlay。
library;

import 'package:flutter/material.dart';
import 'package:mistream/app/router.dart';
import 'package:mistream/application/app_assembly.dart';

/// 品牌种子色。
const _seedColor = Color(0xFF4F46E5);

/// 应用主题。
///
/// 明暗两套都从同一 [seedColor] 派生，保证组件色（卡片、导航、芯片）成套；
/// 只覆盖需要与默认 M3 拉开差异的地方，其余交给 `ColorScheme.fromSeed`
/// 的派生色。
ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme).copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
    ),
  );
}

/// 组合根下发给整个 widget 树。
///
/// 取代了早先的可变全局 `globalAssembly`——全局变量让 widget 单元测试必须先
/// 模拟状态，也模糊了"谁依赖了什么"。
class AppScope extends InheritedWidget {
  /// 以 [assembly] 驱动 [child]。
  const AppScope({
    required this.assembly,
    required super.child,
    super.key,
  });

  /// 应用级装配。
  final AppAssembly assembly;

  /// 取最近的 [AppScope]。找不到即是装配错了，直接断言失败而不是静默降级。
  ///
  /// 用 `getInheritedWidgetOfExactType` 而非 `dependOnInheritedWidgetOfExactType`：
  /// 装配在应用生命周期内不会变，调用方多在事件回调里取用（build 之外注册
  /// 依赖会被框架警告），无需监听变更。
  static AppAssembly of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, '找不到 AppScope，检查 MiStreamApp 是否在树上');
    return scope!.assembly;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => assembly != oldWidget.assembly;
}

/// 应用根 widget：装配主题、路由与全局 overlay。
class MiStreamApp extends StatefulWidget {
  /// 以已装配好的 [assembly] 构造。
  ///
  /// [onboardingDone] 决定首次落在引导页还是首页，由 `main.dart` 在建库后读出。
  /// [themeMode] 决定应用主题模式（system/light/dark）。
  const MiStreamApp({
    required this.assembly,
    required this.onboardingDone,
    required this.themeMode,
    super.key,
  });

  /// 应用级装配。
  final AppAssembly assembly;

  /// 是否已完成首次引导。
  final bool onboardingDone;

  /// 主题模式。
  final ThemeMode themeMode;

  @override
  State<MiStreamApp> createState() => _MiStreamAppState();
}

class _MiStreamAppState extends State<MiStreamApp> {
  late final ValueNotifier<bool> _onboardingDone;
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();
    _onboardingDone = ValueNotifier<bool>(widget.onboardingDone);
    _router = AppRouter(onboardingDone: _onboardingDone);
  }

  @override
  void dispose() {
    _router.dispose();
    _onboardingDone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      assembly: widget.assembly,
      child: OnboardingScope(
        done: _onboardingDone,
        child: MaterialApp.router(
          title: 'MiStream',
          debugShowCheckedModeBanner: false,
          themeMode: widget.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          routerConfig: _router.router,
        ),
      ),
    );
  }
}
