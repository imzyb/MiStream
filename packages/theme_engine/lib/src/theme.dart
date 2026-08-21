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
  });

  final int primary;
  final int background;
  final int surface;
  final int onBackground;
  final int onSurface;
  final int outline;

  Map<String, int> toMap() => {
    'primary': primary,
    'background': background,
    'surface': surface,
    'onBackground': onBackground,
    'onSurface': onSurface,
    'outline': outline,
  };
}
