/// 主题定义、内置四套主题与对比度断言矩阵。
library;

import 'package:meta/meta.dart';

import 'contrast.dart';

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
  ContrastRule('primary/background', t.primary, t.background, 3.0),
  ContrastRule('primary/surface', t.primary, t.surface, 3.0),
  ContrastRule('primary/surfaceVariant', t.primary, t.surfaceVariant, 3.0),
  ContrastRule('outlineStrong/background', t.outlineStrong, t.background, 3.0),
  ContrastRule('outlineStrong/surface', t.outlineStrong, t.surface, 3.0),
  ContrastRule(
    'outlineStrong/surfaceVariant',
    t.outlineStrong,
    t.surfaceVariant,
    3.0,
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
