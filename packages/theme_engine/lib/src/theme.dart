/// 主题定义与内置四套主题。
library;

import 'package:meta/meta.dart';

@immutable
class AppTheme {
  const AppTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.tokens,
  });

  final String id;
  final String name;
  final bool isDark;
  final DesignTokens tokens;

  static const light = AppTheme(
    id: 'light',
    name: '浅色',
    isDark: false,
    tokens: DesignTokens(
      primary: 0xFF4F46E5,
      background: 0xFFF8FAFC,
      surface: 0xFFFFFFFF,
      onBackground: 0xFF0F172A,
      onSurface: 0xFF1E293B,
      outline: 0xFFE2E8F0,
      // slate-500：对 background 4.53 / surface 4.76
      outlineStrong: 0xFF64748B,
    ),
  );

  static const dark = AppTheme(
    id: 'dark',
    name: '深色',
    isDark: true,
    tokens: DesignTokens(
      primary: 0xFF818CF8,
      background: 0xFF0F172A,
      surface: 0xFF1E293B,
      onBackground: 0xFFF1F5F9,
      onSurface: 0xFFE2E8F0,
      outline: 0xFF334155,
      // 深底上要抬一档：slate-500 对 surface 只有 3.07，余量太薄。
      // 这一档对 background 5.29 / surface 4.33。
      outlineStrong: 0xFF7C8DA6,
    ),
  );

  static const oled = AppTheme(
    id: 'oled',
    name: 'OLED',
    isDark: true,
    tokens: DesignTokens(
      primary: 0xFF818CF8,
      background: 0xFF000000,
      surface: 0xFF0A0A0A,
      onBackground: 0xFFF1F5F9,
      onSurface: 0xFFE2E8F0,
      outline: 0xFF1F1F1F,
      // slate-500：纯黑底上足够（对 background 4.41 / surface 4.16）
      outlineStrong: 0xFF64748B,
    ),
  );

  static const system = AppTheme(
    id: 'system',
    name: '跟随系统',
    isDark: false,
    tokens: DesignTokens(
      primary: 0xFF4F46E5,
      background: 0xFFF8FAFC,
      surface: 0xFFFFFFFF,
      onBackground: 0xFF0F172A,
      onSurface: 0xFF1E293B,
      outline: 0xFFE2E8F0,
      // 与 light 同值
      outlineStrong: 0xFF64748B,
    ),
  );

  static const builtIns = [light, dark, oled, system];
  static const builtInsMap = {
    'light': light,
    'dark': dark,
    'oled': oled,
    'system': system,
  };
}

@immutable
class DesignTokens {
  const DesignTokens({
    required this.primary,
    required this.background,
    required this.surface,
    required this.onBackground,
    required this.onSurface,
    required this.outline,
    required this.outlineStrong,
  });

  /// 强调色。同时作前景（链接、按钮文字）与背景（填充按钮）。
  ///
  /// 因身兼两职，它必须**同时**对 `background` 与 `surface` 达 4.5:1。
  final int primary;

  /// 页面底色。
  final int background;

  /// 卡片/面板底色。
  final int surface;

  /// 页面上的正文前景。
  final int onBackground;

  /// 卡片/面板上的正文前景。
  final int onSurface;

  /// 分隔线、装饰性描边。
  ///
  /// **不**受 WCAG 1.4.11 约束——它只画装饰性分隔，丢掉它用户仍能认出界面
  /// 元素。刻意做得很淡（浅色 1.18、深色 1.72）。需要「看得见的边界」请用
  /// [outlineStrong]。
  final int outline;

  /// UI 组件的必需边界：输入框、按钮轮廓、选中态描边。
  ///
  /// WCAG 1.4.11 对「识别组件所必需的视觉信息」要求 3:1，所以这个令牌对
  /// `background` 与 `surface` 都要达标，由 `theme_test.dart` 断言。
  final int outlineStrong;

  Map<String, int> toMap() => {
    'primary': primary,
    'background': background,
    'surface': surface,
    'onBackground': onBackground,
    'onSurface': onSurface,
    'outline': outline,
    'outlineStrong': outlineStrong,
  };
}
