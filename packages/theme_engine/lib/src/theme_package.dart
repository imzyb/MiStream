/// 主题包加载：JSON 令牌覆盖 + 对比度兜底。
library;

import 'package:meta/meta.dart';

import 'package:theme_engine/src/motion.dart';
import 'package:theme_engine/src/scale.dart';
import 'package:theme_engine/src/theme.dart';

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
/// 只保留**成功解析、本包认识、且安全**的令牌；其余一律不带，由 [applyTo] 从
/// 基准主题补齐。这样主题包永远不可能把某个令牌留空。
///
/// 「安全」有两条硬约束，都在解析阶段就守住，因为下游的校验依赖它们：
/// - **颜色一律不透明**：对比度计算忽略 alpha，放行半透明会让「不达标就回退」
///   静默失效（详见 `_parseColor`）
/// - **尺度令牌夹进安全区间**：`spacing.unit = -5` 会让 `SizedBox` 断言失败、
///   `1e300` 会把布局撑爆（详见 `_clampScaleToken`）
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
        final parsed = _parseColor(entry.value);
        if (parsed.color == null) {
          warn('令牌 $key ${parsed.failure}，已忽略');
        } else {
          tokens[colorField] = parsed.color!;
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
          numbers[scaleField] = _clampScaleToken(key, scaleField, value, warn);
        } else {
          // font.scale 不在这里夹：DesignTypography.effectiveScale 会夹进
          // 规范区间，validateTypography 负责告警。
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
            '令牌 $key 不是已知曲线（$value），已忽略。 '
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

  /// 覆盖到 [base] 上：包里有就用包里的，没有就取 [base] 的。
  ///
  /// 尺度结果会再过一遍 [clampScale]：包里的值在 [fromJson] 阶段已经夹过一次，
  /// 这里是**对 [base] 的兜底** —— 万一传入的基准主题自身越界，也不会把畸形值
  /// 带进渲染。夹住是兜底，告警仍由解析阶段照发，作者得知道自己写的值没生效。
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
      scale: clampScale(
        s.copyWith(
          unit: numbers['unit'],
          radiusSm: numbers['radiusSm'],
          radiusMd: numbers['radiusMd'],
          radiusLg: numbers['radiusLg'],
          radiusFull: numbers['radiusFull'],
          elevationCard: numbers['elevationCard'],
          elevationDialog: numbers['elevationDialog'],
          elevationOverlay: numbers['elevationOverlay'],
        ),
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

/// 加载主题包：解析 → 叠加 → 不透明性与对比度校验 → 不达标回退。
///
/// docs/09-UI规范.md §9：主题永远不能让 App 白屏或不可读。所以这里最后一定
/// 跑 [checkContrast]（与内置主题同一份断言），不达标就整个退回 [base]，
/// 并把具体哪对不达标写进 [ThemeLoadResult.warnings]——用户要改主题包，得先
/// 知道是哪个令牌。
///
/// [findTranslucentTokens] 与 [checkContrast] 是**同一道闸门**的两半，缺一不可：
/// 对比度计算忽略 alpha，只看对比度的话「全透明前景 + 全透明背景」会以 21:1
/// 满分通过，而渲染出来什么都看不见。不透明性守住了，对比度的结论才等于渲染
/// 结果。这道检查也覆盖 [base] 本身 —— 即使传入的基准主题畸形，也不会漏过去。
///
/// 尺度/字体的问题（[validateTheme]）**不触发回退**：圆角顺序反了、字号阶梯
/// 乱了不会让界面不可读，夹住或按基准值用即可。回退整包反而是更差的选择——
/// 用户明明只想改一个圆角。（越界值由 [clampScale] 兜底，不会真的生效。）
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

  final fails = <String>[
    ...findTranslucentTokens(merged.tokens),
    ...checkContrast(merged.tokens),
  ];
  if (fails.isEmpty) {
    // 明暗声明与配色矛盾时**只告警、不回退**：配色本身是合规的（对比度过了），
    // 不可读的只有系统 UI 那部分。回退整包反而会让用户失去想要的配色。
    for (final problem in <String>[
      ...checkBrightnessConsistency(
        declaredDark: pkg.isDark,
        t: merged.tokens,
      ),
      ...validateTheme(merged),
    ]) {
      warn('主题包的非致命问题（主题仍会加载）：$problem');
    }
    return ThemeLoadResult(theme: merged, fellBack: false, warnings: warnings);
  }

  warn('主题包对比度/不透明度不达标，已回退到内置主题：${fails.join('、')}');
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

/// 把尺度令牌夹进安全区间，**并在真的夹住时告警**。
///
/// ⚠️ 为什么在**解析阶段**就夹，而不是等到合成时：
/// `loadThemePackage` 与 `tools/theme_lint` 共用 `fromJson → applyTo →
/// validateTheme` 这一条链路，两者之间有一致性测试。夹在解析阶段，两边拿到的
/// `ThemePackage.numbers` 就是同一份安全值、收到的告警也同一批，**一致性由构造
/// 保证**；夹在合成阶段则要靠两处各自记得做同一件事。
///
/// 告警必须基于**作者写的原始值**：夹住之后再校验，`-5` 已经变成 `1`，
/// 错误就查不出来了 —— 那正是「静默改值」，比报错更难排查。
///
/// 区间见 [kMaxSpacingUnit] / [kMaxRadius] / [kMaxElevation]。
double _clampScaleToken(
  String key,
  String field,
  double value,
  void Function(String) warn,
) {
  final (lower, upper) = switch (field) {
    'unit' => (1.0, kMaxSpacingUnit),
    'elevationCard' || 'elevationDialog' || 'elevationOverlay' => (
      0.0,
      kMaxElevation,
    ),
    _ => (0.0, kMaxRadius),
  };

  if (value >= lower && value <= upper) return value;

  final clamped = value.clamp(lower, upper);
  warn(
    value < lower
        ? '令牌 $key = $value 低于下限 $lower，已按 $clamped 使用'
        : '令牌 $key = $value 超过上限 $upper，已按 $clamped 使用',
  );
  return clamped;
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
///
/// 返回 `(颜色, 失败原因)`，成功时原因为 `null`、颜色非 `null`。让解析函数
/// 带回原因而不是自己告警，是为了让调用方**只发一条**告警 —— 否则「不合法」
/// 与「带透明度」会各报一次，同一行输入刷两条。
///
/// ⚠️ **带透明度的值一律拒掉，不静默改成不透明。**
/// 理由：设计令牌的契约是实色。`ContrastChecker.luminance` 忽略 alpha，
/// 若放行 `#00000000`（全透明黑）做背景，对比度会算成「不透明黑」的 21:1、
/// 判为完全达标，而实际渲染什么都看不见 —— 校验结论与渲染结果对不上，
/// 「不达标就回退」这道防线整个失效。
///
/// 拒绝而非强改 alpha：改写会静默把作者写的值换掉（`#80FF0000` 变成
/// `#FFFF0000`），比「明确拒绝并告警」更难排查。
({int? color, String? failure}) _parseColor(Object? value) {
  int? argb;
  if (value is int) {
    argb = value & 0xFFFFFFFF;
  } else if (value is String) {
    final s = value.trim();
    if (!s.startsWith('#')) return (color: null, failure: '的值不是合法颜色（$value）');
    final hex = s.substring(1);
    final n = int.tryParse(hex, radix: 16);
    if (n == null) return (color: null, failure: '的值不是合法颜色（$value）');

    argb = switch (hex.length) {
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
  if (argb == null) return (color: null, failure: '的值不是合法颜色（$value）');

  final alpha = (argb >> 24) & 0xFF;
  if (alpha != 0xFF) {
    final hex = alpha.toRadixString(16).padLeft(2, '0');
    return (
      color: null,
      failure: '带透明度（alpha=0x$hex），设计令牌要求不透明',
    );
  }
  return (color: argb, failure: null);
}

int _expand3(int nibble) => nibble | (nibble << 4);
