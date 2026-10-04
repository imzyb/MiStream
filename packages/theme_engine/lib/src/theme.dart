/// 主题定义、内置四套主题与对比度断言矩阵。
library;

import 'package:meta/meta.dart';

import 'package:theme_engine/src/contrast.dart';
import 'package:theme_engine/src/motion.dart';
import 'package:theme_engine/src/scale.dart';

@immutable
class AppTheme {
  const AppTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.tokens,
    this.scale = DesignScale.standard,
    this.typography = DesignTypography.standard,
    this.motion = DesignMotion.standard,
  });

  final String id;
  final String name;
  final bool isDark;
  final DesignTokens tokens;

  /// 间距、圆角、投影。
  final DesignScale scale;

  /// 字体族、字号阶梯、字号缩放。
  final DesignTypography typography;

  /// 动效时长与曲线。
  ///
  /// 内置四套主题都用规范默认值——动效不属于「配色」，没有明暗之分。它留在
  /// [AppTheme] 里是为了让主题包能覆盖，以及让 app 层有一个统一的取用点。
  final DesignMotion motion;

  /// 浅色。
  ///
  /// 明度阶梯：页面 `#F8FAFC` → 卡片纯白 → 次级面板（输入框）`#F1F5F9`。
  static const light = AppTheme(
    id: 'light',
    name: '浅色',
    isDark: false,
    tokens: DesignTokens(
      primary: 0xFF4F46E5,
      onPrimary: 0xFFFFFFFF,
      primaryText: 0xFF4338CA,
      background: 0xFFF8FAFC,
      surface: 0xFFFFFFFF,
      surfaceVariant: 0xFFF1F5F9,
      onSurface: 0xFF0F172A,
      onSurfaceMuted: 0xFF475569,
      outline: 0xFFE2E8F0,
      outlineStrong: 0xFF64748B,
    ),
  );

  /// 深色。
  ///
  /// 明度阶梯与浅色同向递进：页面 `#0F172A` → 卡片 `#1E293B` → 次级面板
  /// `#2C3849`（slate-700 略压暗，为了让次级文字在上面的 4.5:1 留出余量）。
  ///
  /// 主色走「亮填充 + 深墨」：深底上若用暗主色配白字，「白字对它 4.5:1」与
  /// 「它对底色 3:1」两个约束的可用亮度区间只剩 0.165~0.183，几乎无解；换成
  /// 亮填充配深墨两个都宽松（5.98 / 4.90）。这也是 M3 深色主题的常规做法。
  static const dark = AppTheme(
    id: 'dark',
    name: '深色',
    isDark: true,
    tokens: DesignTokens(
      primary: 0xFF818CF8,
      onPrimary: 0xFF0F172A,
      primaryText: 0xFFA5B4FC,
      background: 0xFF0F172A,
      surface: 0xFF1E293B,
      surfaceVariant: 0xFF2C3849,
      onSurface: 0xFFE2E8F0,
      onSurfaceMuted: 0xFF94A3B8,
      outline: 0xFF334155,
      outlineStrong: 0xFF7C8DA6,
    ),
  );

  /// OLED 纯黑。
  ///
  /// 底色是 `#000000` 而不是深灰：自发光屏上纯黑像素不发光，既省电也没有
  /// 灰底漏光。代价是页面与卡片之间几乎没有明度差，容器边界只能靠
  /// `outlineStrong` 撑住，所以这一档的 [DesignTokens.outlineStrong] 不能降。
  static const oled = AppTheme(
    id: 'oled',
    name: 'OLED 纯黑',
    isDark: true,
    tokens: DesignTokens(
      primary: 0xFF818CF8,
      onPrimary: 0xFF000000,
      primaryText: 0xFFA5B4FC,
      background: 0xFF000000,
      surface: 0xFF0A0A0A,
      surfaceVariant: 0xFF141414,
      onSurface: 0xFFE2E8F0,
      onSurfaceMuted: 0xFF94A3B8,
      outline: 0xFF1F1F1F,
      outlineStrong: 0xFF64748B,
    ),
  );

  /// 跟随系统。
  ///
  /// 这不是一套独立配色，而是 [AppThemeChoice.system] 在系统为浅色时的解析
  /// 结果（深色时解析到 [dark]）。它留在 `builtIns` 里是为了让
  /// docs/09-UI规范.md §9「内置四套」的清点能对上；业务代码不要直接取它，
  /// 一律走 `resolveTheme`。
  static const system = AppTheme(
    id: 'system',
    name: '跟随系统',
    isDark: false,
    tokens: DesignTokens(
      primary: 0xFF4F46E5,
      onPrimary: 0xFFFFFFFF,
      primaryText: 0xFF4338CA,
      background: 0xFFF8FAFC,
      surface: 0xFFFFFFFF,
      surfaceVariant: 0xFFF1F5F9,
      onSurface: 0xFF0F172A,
      onSurfaceMuted: 0xFF475569,
      outline: 0xFFE2E8F0,
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
    required this.onPrimary,
    required this.primaryText,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.outline,
    required this.outlineStrong,
  });

  /// 主色**填充**：按钮、选中态的底色。
  ///
  /// 只作背景，不作文字色——深底与浅底对它的明度要求相反（浅底要它够暗，
  /// 白字才压得住；深底要它够亮，才能从底色里浮出来），一个值必然有一边不
  /// 达标。文字请用 [primaryText]，压在它上面请用 [onPrimary]。
  final int primary;

  /// 压在 [primary] 上的前景（填充按钮的文字与图标）。
  final int onPrimary;

  /// 主色**文字**：链接、强调文本、强调图标。
  ///
  /// 与 [primary] 同色相但明度分开，理由见 [primary]。
  final int primaryText;

  /// 页面底色。
  final int background;

  /// 卡片、面板底色。
  final int surface;

  /// 次级面板、输入框底色。
  final int surfaceVariant;

  /// 主文字。
  final int onSurface;

  /// 次要文字、说明。
  final int onSurfaceMuted;

  /// 分隔线、装饰性描边。
  ///
  /// **不**受 WCAG 1.4.11 约束——它只画装饰性分隔，丢掉它用户仍能认出界面
  /// 元素。刻意做得很淡（浅色 1.18、深色 1.72）。需要「看得见的边界」请用
  /// [outlineStrong]。
  final int outline;

  /// UI 组件的必需边界：输入框、按钮轮廓、选中态描边。
  ///
  /// WCAG 1.4.11 对「识别组件所必需的视觉信息」要求 3:1，所以这个令牌对三个
  /// 底色都要达标，由 [contrastRules] 断言。
  final int outlineStrong;

  Map<String, int> toMap() => {
    'primary': primary,
    'onPrimary': onPrimary,
    'primaryText': primaryText,
    'background': background,
    'surface': surface,
    'surfaceVariant': surfaceVariant,
    'onSurface': onSurface,
    'onSurfaceMuted': onSurfaceMuted,
    'outline': outline,
    'outlineStrong': outlineStrong,
  };
}

/// 一条对比度要求：哪两个令牌之间、至少多少。
@immutable
class ContrastRule {
  const ContrastRule(this.name, this.fg, this.bg, this.min);

  /// 人类可读的名字，失败时直接进提示文案。
  final String name;

  /// 前景。
  final int fg;

  /// 背景。
  final int bg;

  /// 门槛：正文 4.5，大字与 UI 组件 3.0。
  final double min;
}

/// [t] 必须满足的全部对比度要求。
///
/// 内置主题的单测与主题包加载后的校验共用这一份定义——docs/09-UI规范.md §9
/// 要求主题包跑的是「与内置主题同一套断言」。两边各写一份的话，某次加令牌
/// 只改了一边，另一边就会静默漏检。
List<ContrastRule> contrastRules(DesignTokens t) => [
  // 正文 4.5:1
  ContrastRule('onPrimary/primary', t.onPrimary, t.primary, 4.5),
  ContrastRule('primaryText/background', t.primaryText, t.background, 4.5),
  ContrastRule('primaryText/surface', t.primaryText, t.surface, 4.5),
  ContrastRule(
    'primaryText/surfaceVariant',
    t.primaryText,
    t.surfaceVariant,
    4.5,
  ),
  ContrastRule('onSurface/background', t.onSurface, t.background, 4.5),
  ContrastRule('onSurface/surface', t.onSurface, t.surface, 4.5),
  ContrastRule('onSurface/surfaceVariant', t.onSurface, t.surfaceVariant, 4.5),
  ContrastRule(
    'onSurfaceMuted/background',
    t.onSurfaceMuted,
    t.background,
    4.5,
  ),
  ContrastRule('onSurfaceMuted/surface', t.onSurfaceMuted, t.surface, 4.5),
  ContrastRule(
    'onSurfaceMuted/surfaceVariant',
    t.onSurfaceMuted,
    t.surfaceVariant,
    4.5,
  ),
  // 大字与 UI 组件 3:1
  ContrastRule('primary/background', t.primary, t.background, 3),
  ContrastRule('primary/surface', t.primary, t.surface, 3),
  ContrastRule('primary/surfaceVariant', t.primary, t.surfaceVariant, 3),
  ContrastRule('outlineStrong/background', t.outlineStrong, t.background, 3),
  ContrastRule('outlineStrong/surface', t.outlineStrong, t.surface, 3),
  ContrastRule(
    'outlineStrong/surfaceVariant',
    t.outlineStrong,
    t.surfaceVariant,
    3,
  ),
];

/// 跑一遍 [contrastRules]，返回不达标的条目。
///
/// 每条形如 `onSurface/surface 3.82 < 4.5`，可以直接拼进给用户的提示——
/// 主题包被拒时用户需要知道是**哪个令牌**不达标，否则无从改起。
List<String> checkContrast(DesignTokens t) {
  final fails = <String>[];
  for (final rule in contrastRules(t)) {
    final actual = ContrastChecker.ratio(rule.fg, rule.bg);
    if (actual < rule.min) {
      fails.add(
        '${rule.name} ${actual.toStringAsFixed(2)} '
        '< ${rule.min.toStringAsFixed(1)}',
      );
    }
  }
  return fails;
}

/// 找出**带透明度**的颜色令牌，返回问题清单（空 = 全部不透明）。
///
/// 为什么必须有这道检查：`ContrastChecker.luminance` 只看 RGB、**忽略 alpha**，
/// 所以「全透明黑底 + 全透明白字」算出来是 21:1，判为完全达标 —— 但渲染出来
/// 什么都看不见，等效白屏。对比度校验的结论只有在「所有令牌都不透明」时才与
/// 渲染一致，这个前提必须显式守住。
///
/// 规范 §2.1 里只有 `color.overlay`（`rgba(0,0,0,0.6)`）是刻意半透明的，而它
/// **尚未建模**。将来建模时要把这条检查对它开豁免，别把遮罩一起拒了。
List<String> findTranslucentTokens(DesignTokens t) {
  final problems = <String>[];
  for (final entry in t.toMap().entries) {
    final alpha = (entry.value >> 24) & 0xFF;
    if (alpha != 0xFF) {
      problems.add(
        '${entry.key} 带透明度（alpha=0x${alpha.toRadixString(16).padLeft(2, '0')}）',
      );
    }
  }
  return problems;
}

/// 检查「声明的明暗」与「实际背景亮度」是否自洽，返回问题清单（空 = 一致）。
///
/// [declaredDark] 为 `null` 表示主题包没声明 `brightness`，这时无从判断，直接通过。
///
/// 为什么要查：`brightness` 决定**系统 UI** 怎么画（状态栏图标、滚动条、原生
/// 控件），而配色由令牌决定。两者矛盾时，浅色状态栏图标会压在深色窗口上 ——
/// 那部分界面不可读，且**对比度断言查不出来**（断言只看令牌之间，不看系统 UI）。
///
/// 0.5 是黑白中点附近的经验分界，够用来识别「抄反了」这种量级的错误。
///
/// 抽成共用函数是因为 `loadThemePackage`（运行时）与 `tools/theme_lint` 都要用：
/// 只写在 lint 里的话，不经 lint 直接装包的用户永远看不到这条提示。
List<String> checkBrightnessConsistency({
  required bool? declaredDark,
  required DesignTokens t,
}) {
  if (declaredDark == null) return const [];
  final looksDark = ContrastChecker.luminance(t.background) < 0.5;
  if (looksDark == declaredDark) return const [];
  final declared = declaredDark ? 'dark' : 'light';
  final actual = looksDark ? '深色' : '浅色';
  return ['声明 brightness=$declared，但 color.background 实际是$actual'];
}

/// 主题的尺度、字体与动效令牌校验，返回问题清单（空 = 通过）。
///
/// 颜色走 [checkContrast]（不达标就整个拒掉主题包），其余走这里——它们的
/// 问题（圆角顺序反了、字号阶梯乱了、动效时长超过一秒）**不致命**，夹住或
/// 按基准值用即可，所以只告警不拒绝。
List<String> validateTheme(AppTheme theme) => [
  ...validateScale(theme.scale),
  ...validateTypography(theme.typography),
  ...validateMotion(theme.motion),
];
