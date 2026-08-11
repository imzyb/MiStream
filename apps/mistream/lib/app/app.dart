/// 应用根 widget：装配主题、路由与全局 overlay。
library;

import 'package:flutter/material.dart';
import 'package:mistream/app/router.dart';
import 'package:mistream/application/app_assembly.dart';

/// 把组合根下发给整棵 widget 树。
///
/// 取代了早先的可变全局 `globalAssembly`——全局变量让 widget 测试必须先
/// 布置隐式状态，也掩盖了「谁依赖了什么」。
class AppScope extends InheritedWidget {
  /// 以 [assembly] 包裹 [child]。
  const AppScope({
    required this.assembly,
    required super.child,
    super.key,
  });

  /// 应用层装配。
  final AppAssembly assembly;

  /// 取最近的 [AppScope]。找不到即是装配漏了，直接断言失败而不是静默降级。
  ///
  /// 用 `getInheritedWidgetOfExactType` 而非 `dependOnInheritedWidgetOfExactType`：
  /// 装配在应用生命周期内不会变，调用方多在事件回调里取用（build 之外注册
  /// 依赖会被框架警告），无需订阅变更。
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
  /// [onboardingDone] 决定首帧落在引导页还是首页，由 `main.dart` 在建库后读出。
  const MiStreamApp({
    required this.assembly,
    required this.onboardingDone,
    super.key,
  });

  /// 应用层装配。
  final AppAssembly assembly;

  /// 是否已完成首次引导。
  final bool onboardingDone;

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
          theme: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFF0D0F14),
          ),
          routerConfig: _router.router,
        ),
      ),
    );
  }
}
