/// 主题包加载：JSON 令牌覆盖 + 对比度兜底。
library;

import 'package:meta/meta.dart';

import 'motion.dart';
import 'scale.dart';
import 'theme.dart';

/// 主题包里 `color.*` 键名到 [DesignTokens] 字段的映射。
///
/// 键名取自 docs/09-UI规范.md §2.1。
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

/// 数值令牌（尺度）到 [DesignScale] 字段的映射，键名取自规范 §2.2。
///
/// `radius.card` 是 06-插件系统.md §9 的示例里出现的写法，规范 §2.2 里并没有
/// 这个名字。示例是主题作者最先照抄的东西，所以认它、映射到 `radius.md`。
const _scaleNumberKeys = <String, String>{
  'spacing.unit': 'unit',
  'radius.sm': 'radiusSm',
  'radius.md': 'radiusMd',
  'radius.card': 'radiusMd',
  'radius.lg': 'radiusLg',
  'radius.full': 'radiusFull',
  'elevation.card': 'elevationCard',
  'elevation.dialog': 'elevationDialog',
  'elevation.overlay': 'elevationOverlay',
};

/// 数值令牌（字体）到 [DesignTypography] 字段的映射，键名取自规范 §2.3。
const _fontNumberKeys = <String, String>{'font.scale': 'scale'};

/// 动效时长令牌到 [DesignMotion] 字段的映射，键名取自规范 §2.4。
///
/// 单位是毫秒。与尺度、字体分开存，不塞进 [ThemePackage.numbers]：那边按字段
/// 名做键，`overlay` 这种名字将来很容易和尺度令牌撞上，而撞了不会报错，只会
/// 静默覆盖。
const _motionDurationKeys = <String, String>{
  'motion.hover': 'hover',
  'motion.pageTransition': 'pageTransition',
  'motion.overlay': 'overlay',
  'motion.playerControls': 'playerControls',
};

/// 动效曲线令牌：`motion.<场景>.curve`，值是 [MotionCurve] 的枚举名。
const _motionCurveKeys = <String, String>{
  'motion.hover.curve': 'hover',
  'motion.pageTransition.curve': 'pageTransition',
  'motion.overlay.curve': 'overlay',
  'motion.playerControls.curve': 'playerControls',
};

/// 一份已解析的主题包。
///
/// 只保留**成功解析且本包认识**的令牌；其余一律不带，由 [applyTo] 从基准主题
/// 补齐。这样主题包永远不可能把某个令牌留空。
@immutable
class ThemePackage {
  const ThemePackage({
    this.tokens = const {},
    this.numbers = const {},
    this.strings = const {},
    this.motionDurations = const {},
    this.motionCurves = const {},
    this.id,
    this.isDark,
  });

  /// 颜色令牌（键是 [DesignTokens] 的字段名）。
  final Map<String, int> tokens;

  /// 数值令牌（键是 [DesignScale] / [DesignTypography] 的字段名）。
  final Map<String, double> numbers;

  /// 字符串令牌（目前只有 `font.family`）。
  final Map<String, String> strings;

  /// 动效时长，毫秒（键是 [DesignMotion] 的字段名）。
  final Map<String, double> motionDurations;

  /// 动效曲线（键是 [DesignMotion] 的字段名）。
  final Map<String, MotionCurve> motionCurves;

  /// 主题包 id，缺失时为 `null`。
  final String? id;

  /// 主题包声明的明暗；缺失或非法时为 `null`。
  final bool? isDark;

  /// 空包：没有任何可覆盖的令牌。
  static const empty = ThemePackage();

  /// 从插件清单解析主题包。
  ///
  /// 形状见 docs/06-插件系统.md §9：`{ id, type, version, theme: {
  /// brightness, tokens: { "color.primary": "#5B3FD6", ... } } }`。
  ///
  /// 任何一层形状不对都只记告警、返回能拿到的部分——主题包是用户数据，解析
  /// 失败不该抛异常把整条加载链路打断。
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
    final id = root['id'] is String ? root['id'] as String : null;

    final theme = root['theme'];
    if (theme is! Map) {
      warn('主题包缺少 theme 对象，整个包已忽略');
      return empty;
    }
    final isDark = _parseBrightness(theme['brightness'], warn);

    final rawTokens = theme['tokens'];
    if (rawTokens is! Map) {
      warn('主题包缺少 theme.tokens 对象，无令牌可覆盖');
      return ThemePackage(id: id, isDark: isDark);
    }

    final tokens = <String, int>{};
    final numbers = <String, double>{};
    final strings = <String, String>{};
    final motionDurations = <String, double>{};
    final motionCurves = <String, MotionCurve>{};

    for (final entry in rawTokens.entries) {
      final key = entry.key;
      if (key is! String) {
        warn('令牌键不是字符串（$key），已忽略');
        continue;
      }

      // 已支持的名字空间（`color.*` / `motion.*`）里出现陌生键值得提醒作者，
      // 那多半是拼错了；尚未落地的名字空间静默跳过，逐个告警只会淹掉真正
      // 有用的那条。
      final colorField = _colorTokenKeys[key];
      if (colorField != null) {
        final value = _parseColor(entry.value);
        if (value == null) {
          warn('令牌 $key 的值不是合法颜色（${entry.value}），已忽略');
        } else {
          tokens[colorField] = value;
        }
        continue;
      }
      if (key.startsWith('color.')) {
        warn('未知的颜色令牌 $key，已忽略');
        continue;
      }

      final scaleField = _scaleNumberKeys[key];
      final fontField = _fontNumberKeys[key];
      if (scaleField != null || fontField != null) {
        final value = _parseNumber(entry.value);
        if (value == null) {
          warn('令牌 $key 的值不是合法数字（${entry.value}），已忽略');
        } else if (scaleField != null) {
          numbers[scaleField] = value;
        } else {
          numbers[fontField!] = value;
        }
        continue;
      }

      if (key == 'font.family') {
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty) {
          strings['family'] = value.trim();
        } else {
          warn('令牌 font.family 的值不是非空字符串（$value），已忽略');
        }
        continue;
      }

      final durationField = _motionDurationKeys[key];
      if (durationField != null) {
        final value = _parseNumber(entry.value);
        if (value == null) {
          warn('令牌 $key 的值不是合法数字（${entry.value}），已忽略');
        } else {
          motionDurations[durationField] = value;
        }
        continue;
      }

      final curveField = _motionCurveKeys[key];
      if (curveField != null) {
        final value = entry.value;
        final curve = value is String ? MotionCurve.fromName(value) : null;
        if (curve == null) {
          warn(
            '令牌 $key 不是已知曲线（$value），已忽略。'
            '可用：${MotionCurve.values.map((c) => c.name).join('、')}',
          );
        } else {
          motionCurves[curveField] = curve;
        }
        continue;
      }
      if (key.startsWith('motion.')) {
        // 「减少动效」不在这里：它属于无障碍选项，由 app 层合成，主题包说了
        // 不算。所以 `motion.reduceMotion` 会落到这条分支被拒掉。
        warn('未知的动效令牌 $key，已忽略');
        continue;
      }
    }

    return ThemePackage(
      tokens: tokens,
      numbers: numbers,
      strings: strings,
      motionDurations: motionDurations,
      motionCurves: motionCurves,
      id: id,
      isDark: isDark,
    );
  }

  /// 覆盖到 [base] 上：包里有就用包里的，没有就取 [base] 的。
  AppTheme applyTo(AppTheme base) {
    final merged = Map<String, int>.from(base.tokens.toMap())..addAll(tokens);
    final s = base.scale;
    final t = base.typography;

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
      scale: s.copyWith(
        unit: numbers['unit'],
        radiusSm: numbers['radiusSm'],
        radiusMd: numbers['radiusMd'],
        radiusLg: numbers['radiusLg'],
        radiusFull: numbers['radiusFull'],
        elevationCard: numbers['elevationCard'],
        elevationDialog: numbers['elevationDialog'],
        elevationOverlay: numbers['elevationOverlay'],
      ),
      typography: t.copyWith(
        family: strings['family'],
        scale: numbers['scale'],
      ),
      motion: _mergeMotion(base.motion),
    );
  }

  /// 把动效覆盖叠到 [base] 上：包里有就用包里的，没有就取 [base] 的。
  ///
  /// 刻意不动 [DesignMotion.reduceMotion]——那是无障碍选项，由 app 层根据用户
  /// 偏好与系统设置合成。主题包在 `fromJson` 阶段就已经把 `motion.reduceMotion`
  /// 当未知键拒掉了。
  DesignMotion _mergeMotion(DesignMotion base) {
    MotionSpec merge(String field, MotionSpec spec) => spec.copyWith(
      duration: _msToDuration(motionDurations[field]),
      curve: motionCurves[field],
    );

    return base.copyWith(
      hover: merge('hover', base.hover),
      pageTransition: merge('pageTransition', base.pageTransition),
      overlay: merge('overlay', base.overlay),
      playerControls: merge('playerControls', base.playerControls),
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

  /// 解析过程中的告警（未知键、非法值、对比度不达标、尺度/字体问题）。
  final List<String> warnings;
}

/// 加载主题包：解析 → 叠加 → 对比度校验 → 不达标回退。
///
/// docs/09-UI规范.md §9：主题永远不能让 App 白屏或不可读。所以这里最后一定
/// 跑 [checkContrast]（与内置主题同一份断言），不达标就整个退回 [base]，
/// 并把具体哪对不达标写进 [ThemeLoadResult.warnings]——用户要改主题包，得先
/// 知道是哪个令牌。
///
/// 尺度/字体的问题（[validateTheme]）**不触发回退**：圆角顺序反了、字号阶梯
/// 乱了不会让界面不可读，夹住或按基准值用即可。回退整包反而是更差的选择——
/// 用户明明只想改一个圆角。
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
    for (final problem in validateTheme(merged)) {
      warn('主题包的尺度/字体/动效令牌有问题（不致命，仍按包里的值使用）：$problem');
    }
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

double? _parseNumber(Object? value) {
  if (value is num) {
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
  if (value is String) {
    final d = double.tryParse(value.trim());
    return (d != null && d.isFinite) ? d : null;
  }
  return null;
}

/// 毫秒 → [Duration]；`null` 表示「包里没写，用基准值」。
///
/// 上界不是为了好看：`(1e30 * 1000).round()` 会抛 `UnsupportedError`，而输入
/// 来自主题包这种用户数据。超过一小时的值一定会在 [validateMotion] 里被报
/// 「超过上限」，所以这里只需保证不崩，不必保证精确。
Duration? _msToDuration(double? ms) {
  if (ms == null) return null;

  const cap = Duration.microsecondsPerHour;
  final microseconds = ms * Duration.microsecondsPerMillisecond;
  if (microseconds >= cap) return const Duration(hours: 1);
  if (microseconds <= -cap) return const Duration(hours: -1);
  return Duration(microseconds: microseconds.round());
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
