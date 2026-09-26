/// 把 `theme_engine` 的设计令牌翻译成 Flutter 的 [ThemeData]。
library;

import 'package:flutter/material.dart';
import 'package:theme_engine/theme_engine.dart';

/// `theme_engine` 里有、M3 [ColorScheme] 里没有的令牌。
///
/// [ColorScheme] 的槽位是固定的，`primaryText`（主色文字，与 `primary`
/// 填充色明度分开）没有对应位置，只能挂在 ThemeExtension 上。别用
/// `colorScheme.primary` 当文字色——那是填充色，两者明度是刻意不同的。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.primaryText, required this.outline});

  /// 主色文字：链接、强调文本、强调图标。
  final Color primaryText;

  /// 装饰性分隔线（对应 `DesignTokens.outline`）。
  ///
  /// [ColorScheme.outline] 被 M3 拿去画输入框与按钮轮廓了，那里必须放达
  /// 3:1 的 `outlineStrong`；真正「淡到几乎看不见」的装饰线只能从这里取。
  final Color outline;

  /// 取当前主题的 [AppColors]。
  ///
  /// 取不到时按 [ColorScheme] 现推一套，而不是返回 null 让调用方到处判空
  /// ——主题扩展一定装着，缺了说明是装配漏了，那也不该让 UI 崩。
  static AppColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppColors>();
    if (ext != null) return ext;
    final scheme = Theme.of(context).colorScheme;
    return AppColors(
      primaryText: scheme.primary,
      outline: scheme.outlineVariant,
    );
  }

  @override
  AppColors copyWith({Color? primaryText, Color? outline}) => AppColors(
    primaryText: primaryText ?? this.primaryText,
    outline: outline ?? this.outline,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

/// 以 [theme] 的令牌构造 [ThemeData]。
///
/// 令牌没有覆盖到的角色（secondary / tertiary / error 及其容器色）交给
/// `ColorScheme.fromSeed` 从主色派生，保证组件色成套；令牌明确定义的那些一律
/// 用令牌值覆盖——派生色不知道我们对对比度的承诺。
ThemeData buildThemeData(AppTheme theme) {
  final t = theme.tokens;
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

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: <ThemeExtension<dynamic>>[
      AppColors(primaryText: Color(t.primaryText), outline: Color(t.outline)),
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
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
