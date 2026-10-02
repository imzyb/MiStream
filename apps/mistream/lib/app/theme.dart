/// 把 `theme_engine` 的设计令牌翻译成 Flutter 的 [ThemeData]。
library;

import 'package:flutter/material.dart';
import 'package:theme_engine/theme_engine.dart';

/// 令牌在 widget 树里的取用口。
///
/// [ColorScheme] / [TextTheme] 的槽位是固定的，装不下 `theme_engine` 的全部
/// 令牌，没地方放的那些挂在这里：
///
/// - `primaryText`：主色**文字**，与 `primary`（填充色）明度是刻意分开的。
///   **别用 `colorScheme.primary` 当文字色**。
/// - `outline`：装饰性分隔线。`ColorScheme.outline` 被 M3 拿去画输入框与按钮
///   轮廓了，那里必须放达 3:1 的 `outlineStrong`；真正「淡到几乎看不见」的
///   装饰线只能从这里取。
/// - `scale` / `typography`：间距、圆角、投影、字体。
/// - `motion`：动效时长与曲线。**别写裸 `Duration(milliseconds: 180)`**——
///   规范 §2.4 给了四档场景，硬编码的结果是它们各写各的（本项目实际发生过：
///   播放器控制栏写对了 180ms，卡片悬停却写成 180 而规范要 120）。
///   用 [DesignMotion.effectiveHover] 这类取值器，它们已经把「减少动效」算进去。
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.primaryText,
    required this.outline,
    required this.scale,
    required this.typography,
    required this.motion,
  });

  /// 取当前主题的令牌。
  ///
  /// 取不到时回落到规范默认值，而不是返回 null 让调用方到处判空——主题扩展
  /// 一定装着，缺了说明是装配漏了，那也不该让 UI 崩。
  ///
  /// 写成工厂构造而不是静态方法：调用点 `AppTokens.of(context)` 一模一样，
  /// 但静态方法会被 `prefer_constructors_over_static_methods` 判为告警。
  /// 工厂得排在字段之前，否则 `sort_constructors_first` 又会报警。
  factory AppTokens.of(BuildContext context) {
    final ext = Theme.of(context).extension<AppTokens>();
    if (ext != null) return ext;
    final scheme = Theme.of(context).colorScheme;
    return AppTokens(
      primaryText: scheme.primary,
      outline: scheme.outlineVariant,
      scale: DesignScale.standard,
      typography: DesignTypography.standard,
      motion: DesignMotion.standard,
    );
  }

  /// 主色文字：链接、强调文本、强调图标。
  final Color primaryText;

  /// 装饰性分隔线（对应 `DesignTokens.outline`）。
  final Color outline;

  /// 间距、圆角、投影。
  final DesignScale scale;

  /// 字体族、字号阶梯、字号缩放。
  final DesignTypography typography;

  /// 动效时长与曲线。
  final DesignMotion motion;

  @override
  AppTokens copyWith({
    Color? primaryText,
    Color? outline,
    DesignScale? scale,
    DesignTypography? typography,
    DesignMotion? motion,
  }) => AppTokens(
    primaryText: primaryText ?? this.primaryText,
    outline: outline ?? this.outline,
    scale: scale ?? this.scale,
    typography: typography ?? this.typography,
    motion: motion ?? this.motion,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      // 尺度、字体与动效不插值：动画中间态出现「圆角 10.3」或「时长 150ms」
      // 没有意义，字号连续变化还会让文字在切换主题时抖动。到点直接切。
      scale: t < 0.5 ? scale : other.scale,
      typography: t < 0.5 ? typography : other.typography,
      motion: t < 0.5 ? motion : other.motion,
    );
  }
}

/// 把 [MotionCurve] 映射成 Flutter 的 [Curve]。
///
/// 映射放在 app 层而不是 `theme_engine`：那边是纯 Dart 包，引了 Flutter 就
/// 只能跑 `flutter test`，而本环境 `flutter_tester` 起不来（widget 测试跑
/// 不了），等于把唯一能自动验证 UI 面的地方关掉。
Curve curveOf(MotionCurve curve) => switch (curve) {
  MotionCurve.easeOut => Curves.easeOut,
  MotionCurve.easeInOutCubic => Curves.easeInOutCubic,
  MotionCurve.easeOutCubic => Curves.easeOutCubic,
  MotionCurve.easeInOut => Curves.easeInOut,
};

/// 以 [theme] 的令牌构造 [ThemeData]。
///
/// 令牌没有覆盖到的角色（secondary / tertiary / error 及其容器色）交给
/// `ColorScheme.fromSeed` 从主色派生，保证组件色成套；令牌明确定义的那些一律
/// 用令牌值覆盖——派生色不知道我们对对比度的承诺。
ThemeData buildThemeData(AppTheme theme) {
  final t = theme.tokens;
  final s = theme.scale;
  final ty = theme.typography;
  final brightness = theme.isDark ? Brightness.dark : Brightness.light;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: Color(t.primary),
        brightness: brightness,
      ).copyWith(
        primary: Color(t.primary),
        onPrimary: Color(t.onPrimary),
        surface: Color(t.background),
        onSurface: Color(t.onSurface),
        onSurfaceVariant: Color(t.onSurfaceMuted),
        // 明度阶梯：页面 → 卡片 → 次级面板（输入框）
        surfaceContainerLowest: Color(t.background),
        surfaceContainerLow: Color(t.surface),
        surfaceContainer: Color(t.surfaceVariant),
        surfaceContainerHigh: Color(t.surfaceVariant),
        surfaceContainerHighest: Color(t.surfaceVariant),
        // M3 拿 outline 画输入框与按钮轮廓，那属于「识别组件所必需的视觉信息」，
        // 必须放达 3:1 的 outlineStrong；装饰性的淡线退到 outlineVariant。
        outline: Color(t.outlineStrong),
        outlineVariant: Color(t.outline),
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // 字体族按规范 §2.3 的优先级回退。主字体族留空时用平台默认，中文字形由
    // 回退链兜住——Flutter 的默认字体在 Windows 上不含中文。
    fontFamily: ty.family,
    fontFamilyFallback: ty.fallback,
  );

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: _textTheme(ty, base.textTheme),
    extensions: <ThemeExtension<dynamic>>[
      AppTokens(
        primaryText: Color(t.primaryText),
        outline: Color(t.outline),
        scale: s,
        typography: ty,
        motion: theme.motion,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: s.elevationCard,
      // 关掉 M3 的高度着色：它在卡片底色上再叠一层主色，会把令牌算好的对比度
      // 改掉，而对比度是断言过的。
      surfaceTintColor: Colors.transparent,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(s.radiusMd),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: s.elevationDialog,
      surfaceTintColor: Colors.transparent,
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(s.radiusLg),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
    ),
  );
}

/// 用户的四档外观映射到 Material 的三档 `ThemeMode`。
///
/// OLED 没有对应档位，只能强制深色再把 `darkTheme` 换成 OLED 令牌，见
/// [AppThemeChoice.forceDark]。
ThemeMode toThemeMode(AppThemeChoice choice) => switch (choice) {
  AppThemeChoice.system => ThemeMode.system,
  AppThemeChoice.light => ThemeMode.light,
  AppThemeChoice.dark || AppThemeChoice.oled => ThemeMode.dark,
};

/// 把规范的字号阶梯落到 M3 的 [TextTheme] 槽位上。
///
/// 映射（规范 §2.3 → M3 槽位）：display→headlineMedium(28)、
/// title→titleLarge(20)、subtitle→titleMedium(16)、body→bodyMedium(14)、
/// caption→bodySmall(12)。
///
/// 只覆盖这五个槽位，其余交给 M3 默认——它们是这套阶梯的派生档（如
/// `titleSmall`），跟着走反而更协调。
TextTheme _textTheme(DesignTypography ty, TextTheme base) => base.copyWith(
  headlineMedium: _apply(ty.display, base.headlineMedium),
  titleLarge: _apply(ty.title, base.titleLarge),
  titleMedium: _apply(ty.subtitle, base.titleMedium),
  bodyMedium: _apply(ty.body, base.bodyMedium),
  bodySmall: _apply(ty.caption, base.bodySmall),
);

/// 只覆盖字号与字重；字体族由 [ThemeData] 的 `fontFamily(Fallback)` 统一给，
/// 这里不动，免得把回退链抹掉。
TextStyle? _apply(TextStyleSpec spec, TextStyle? base) {
  if (base == null) return null;
  // 字重枚举是 w100..w900 的连续序列，index = 百位数 - 1。
  final index = spec.weight ~/ 100 - 1;
  final weight = (index >= 0 && index < FontWeight.values.length)
      ? FontWeight.values[index]
      : null;
  return base.copyWith(fontSize: spec.size, fontWeight: weight);
}
