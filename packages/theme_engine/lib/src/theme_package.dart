/// 主题包加载：JSON 令牌覆盖 + 对比度兜底。
library;

import 'package:meta/meta.dart';

import 'theme.dart';

/// 主题包里 `color.*` 键名到 [DesignTokens] 字段的映射。
///
/// 键名取自 docs/09-UI规范.md §2.1。不在这个表里的 `color.*` 键会被告警并
/// 忽略；不是 `color.` 开头的（半径、间距、字体……）直接静默忽略——本包目前
/// 只管颜色，那些令牌尚未落地，逐个告警只会淹掉真正有用的那条。
const _colorTokenKeys = <String, String>{
  'color.primary': 'primary',
  'color.onPrimary': 'onPrimary',
  'color.primaryText': 'primaryText',
  'color.background': 'background',
  'color.surface': 'surface',
  'color.surfaceVariant': 'surfaceVariant',
  'color.onSurface': 'onSurface',
  'color.onSurfaceMuted': 'onSurfaceMuted',
  'color.outline': 'outline',
  'color.outlineStrong': 'outlineStrong',
};

/// 一份已解析的主题包。
///
/// 只保留**成功解析且本包认识**的令牌；其余的一律不带，由 [applyTo] 从基准
/// 主题补齐。这样主题包永远不可能把某个令牌留空。
@immutable
class ThemePackage {
  const ThemePackage({required this.tokens, this.id, this.isDark});

  /// 解析出的颜色令牌（键是 [DesignTokens] 的字段名）。
  final Map<String, int> tokens;

  /// 主题包 id，缺失时为 `null`。
  final String? id;

  /// 主题包声明的明暗；缺失或非法时为 `null`。
  final bool? isDark;

  /// 空包：没有任何可覆盖的令牌。
  static const empty = ThemePackage(tokens: {});

  /// 从插件清单解析主题包。
  ///
  /// 形状见 docs/06-插件系统.md §9：`{ id, type, version, theme: {
  /// brightness, tokens: { "color.primary": "#5B3FD6", ... } } }`。
  ///
  /// 任何一层形状不对都只记告警、返回能拿到的部分——主题包是用户数据，解
  /// 析失败不该抛异常把整条加载链路打断。
  factory ThemePackage.fromJson(
    Object? json, {
    void Function(String message)? onWarn,
  }) {
    void warn(String m) => onWarn?.call(m);

    if (json is! Map) {
      warn('主题包根节点不是对象，整个包已忽略');
      return empty;
    }
    final root = json;

    final theme = root['theme'];
    if (theme is! Map) {
      warn('主题包缺少 theme 对象，整个包已忽略');
      return empty;
    }

    final rawTokens = theme['tokens'];
    if (rawTokens is! Map) {
      warn('主题包缺少 theme.tokens 对象，无令牌可覆盖');
      return ThemePackage(
        tokens: const {},
        id: root['id'] is String ? root['id'] as String : null,
        isDark: _parseBrightness(theme['brightness'], warn),
      );
    }

    final tokens = <String, int>{};
    for (final entry in rawTokens.entries) {
      final key = entry.key;
      if (key is! String) {
        warn('令牌键不是字符串（$key），已忽略');
        continue;
      }
      final field = _colorTokenKeys[key];
      if (field == null) {
        if (key.startsWith('color.')) {
          warn('未知的颜色令牌 $key，已忽略');
        }
        continue;
      }
      final value = _parseColor(entry.value);
      if (value == null) {
        warn('令牌 $key 的值不是合法颜色（${entry.value}），已忽略');
        continue;
      }
      tokens[field] = value;
    }

    return ThemePackage(
      tokens: tokens,
      id: root['id'] is String ? root['id'] as String : null,
      isDark: _parseBrightness(theme['brightness'], warn),
    );
  }

  /// 覆盖到 [base] 上：包里有就用包里的，没有就取 [base] 的。
  AppTheme applyTo(AppTheme base) {
    final merged = Map<String, int>.from(base.tokens.toMap())..addAll(tokens);
    return AppTheme(
      id: id ?? base.id,
      name: base.name,
      // 声明的明暗优先：包作者说这是深色，就按深色合成，别拿 base 的。
      isDark: isDark ?? base.isDark,
      tokens: DesignTokens(
        primary: merged['primary']!,
        onPrimary: merged['onPrimary']!,
        primaryText: merged['primaryText']!,
        background: merged['background']!,
        surface: merged['surface']!,
        surfaceVariant: merged['surfaceVariant']!,
        onSurface: merged['onSurface']!,
        onSurfaceMuted: merged['onSurfaceMuted']!,
        outline: merged['outline']!,
        outlineStrong: merged['outlineStrong']!,
      ),
    );
  }
}

/// 主题包加载结果。
@immutable
class ThemeLoadResult {
  const ThemeLoadResult({
    required this.theme,
    required this.fellBack,
    required this.warnings,
  });

  /// 最终生效的主题。不达标时是传入的基准主题。
  final AppTheme theme;

  /// 是否因为对比度不达标而回退到了基准主题。
  final bool fellBack;

  /// 解析过程中的告警（未知键、非法值、对比度不达标）。
  final List<String> warnings;
}

/// 加载主题包：解析 → 叠加 → 对比度校验 → 不达标回退。
///
/// docs/09-UI规范.md §9：主题永远不能让 App 白屏或不可读。所以这里最后一定
/// 跑 [checkContrast]（与内置主题同一份断言），不达标就整个退回 [base]，
/// 并把具体哪对不达标写进 [ThemeLoadResult.warnings]——用户要改主题包，得先
/// 知道是哪个令牌。
ThemeLoadResult loadThemePackage(
  Object? json, {
  required AppTheme base,
  void Function(String message)? onWarn,
}) {
  final warnings = <String>[];
  void warn(String m) {
    warnings.add(m);
    onWarn?.call(m);
  }

  final pkg = ThemePackage.fromJson(json, onWarn: warn);
  final merged = pkg.applyTo(base);
  final fails = checkContrast(merged.tokens);
  if (fails.isEmpty) {
    return ThemeLoadResult(theme: merged, fellBack: false, warnings: warnings);
  }

  warn('主题包对比度不达标，已回退到内置主题：${fails.join('、')}');
  return ThemeLoadResult(theme: base, fellBack: true, warnings: warnings);
}

bool? _parseBrightness(Object? value, void Function(String) warn) {
  if (value == null) return null;
  if (value == 'dark') return true;
  if (value == 'light') return false;
  warn('theme.brightness 非法（$value），按基准主题处理');
  return null;
}

/// 解析颜色：`#RGB` / `#RRGGBB` / `#AARRGGBB`，或直接的 ARGB 整数。
int? _parseColor(Object? value) {
  if (value is int) return value;
  if (value is! String) return null;

  final s = value.trim();
  if (!s.startsWith('#')) return null;
  final hex = s.substring(1);
  final n = int.tryParse(hex, radix: 16);
  if (n == null) return null;

  return switch (hex.length) {
    3 =>
      0xFF000000 |
          _expand3((n >> 8) & 0xF) << 16 |
          _expand3((n >> 4) & 0xF) << 8 |
          _expand3(n & 0xF),
    6 => 0xFF000000 | n,
    8 => n,
    _ => null,
  };
}

int _expand3(int nibble) => nibble | (nibble << 4);
