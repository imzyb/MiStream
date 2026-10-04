/// 应用根 widget：装配主题、路由与全局 overlay。
library;

import 'package:flutter/material.dart';
import 'package:mistream/app/motion_controller.dart';
import 'package:mistream/app/router.dart';
import 'package:mistream/app/theme.dart';
import 'package:mistream/app/theme_controller.dart';
import 'package:mistream/application/app_assembly.dart';
import 'package:theme_engine/theme_engine.dart';

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
  /// [themeController] 持有当前外观；改它会立刻重建整棵树的主题，所以它在
  /// `main` 里建好一路传进来，而不是让某个页面自己持有一份。
  /// [motionController] 同理，它管的是「减少动效」。
  const MiStreamApp({
    required this.assembly,
    required this.onboardingDone,
    required this.themeController,
    required this.motionController,
    super.key,
  });

  /// 应用级装配。
  final AppAssembly assembly;

  /// 是否已完成首次引导。
  final bool onboardingDone;

  /// 外观选择。
  final ThemeController themeController;

  /// 「减少动效」开关。
  final MotionController motionController;

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
      child: ThemeScope(
        notifier: widget.themeController,
        child: MotionScope(
          notifier: widget.motionController,
          child: OnboardingScope(
            done: _onboardingDone,
            // 外观一变就重建 MaterialApp：这就是「切换即时生效，无需重启」。
            // 监听放在树根而不是让设置页自己 setState——主题属于整棵树。
            child: ValueListenableBuilder<AppThemeChoice>(
              valueListenable: widget.themeController,
              builder: (context, choice, _) =>
                  // 「减少动效」也要重建 MaterialApp：它改的是 `builder` 里注入的
                  // MediaQuery，而 `builder` 只在 MaterialApp 重建时才重跑。
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.motionController,
                    builder: (context, _, _) => MaterialApp.router(
                      title: 'MiStream',
                      debugShowCheckedModeBanner: false,
                      themeMode: toThemeMode(choice),
                      // 明暗各解析一次：选 light 时两套都是浅色，选 oled 时两套
                      // 都是 OLED，MaterialApp 那边不必再 branch。
                      theme: buildThemeData(
                        resolveTheme(choice, platformIsDark: false),
                      ),
                      darkTheme: buildThemeData(
                        resolveTheme(choice, platformIsDark: true),
                      ),
                      builder: _applyAppearance,
                      routerConfig: _router.router,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 把主题里与「平台缩放」有关的令牌落到 `MediaQuery` 上：字号缩放与减少动效。
///
/// 两件事写在一个函数里、只组一次 `MediaQuery`：各写一个的话，后套上的那个
/// 会以「外层的 data」为底，把前一个塞进去的字段冲掉。
///
/// 已知代价：`TextScaler.linear` 会丢掉**非线性**的系统缩放曲线（Android 14+
/// 按字号分段的那个）。桌面端用的是线性缩放，不受影响。
Widget _applyAppearance(BuildContext context, Widget? child) {
  final child0 = child ?? const SizedBox.shrink();
  final data = MediaQuery.of(context);

  // 「减少动效」= 用户开关 **或** 系统无障碍设置。走 `disableAnimations` 而不是
  // 逐个 widget 判断：这是 Flutter 自己的无障碍通道，`AnimationController` 看到
  // 它会直接跳到终态，连我们没主动接线的框架动画（页面切换、SnackBar）也一并
  // 归零。令牌那边（`DesignMotion.effectiveXxx`）是给显式取时长的组件用的，
  // 两条路殊途同归。
  final reduceMotion =
      MotionScope.read(context).value || data.disableAnimations;
  final ourScale = AppTokens.of(context).typography.effectiveScale;

  if (!reduceMotion && ourScale == 1) return child0;

  var next = data;
  if (reduceMotion) {
    next = next.copyWith(disableAnimations: true);
  }
  if (ourScale != 1) {
    // 拿正文档做探针：非线性缩放曲线本来就是围绕正文字号定义的。
    final probe = DesignTypography.standard.body.size;
    final systemFactor = data.textScaler.scale(probe) / probe;
    next = next.copyWith(
      textScaler: TextScaler.linear(systemFactor * ourScale),
    );
  }
  return MediaQuery(data: next, child: child0);
}
