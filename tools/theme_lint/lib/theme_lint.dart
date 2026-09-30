/// 主题包校验器：把「装进去才发现不达标」提前到作者本地。
///
/// docs/06-插件系统.md §9 要求主题包「加载后强制跑一次对比度校验，不达标即
/// 拒绝该主题」，并提到主题作者可用 `mistream theme lint` 提前发现。本包就是
/// 那个命令的实现——**用的是与运行时完全同一份断言**（`theme_engine` 的
/// `contrastRules` / `validateTheme`），不另写一套规则。两套规则迟早会分叉，
/// 分叉的结果是 lint 说没问题、装上却被拒。
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:theme_engine/theme_engine.dart';

/// 问题级别。
enum LintSeverity {
  /// 装上去会被拒，或根本装不上。
  error,

  /// 能装，但多半不是你想要的。
  warning,

  /// 只是提示，不影响加载。
  info,
}

/// 一条校验结果。
@immutable
class LintIssue {
  const LintIssue(this.severity, this.message, {this.hint});

  final LintSeverity severity;

  /// 发生了什么。
  final String message;

  /// 能怎么改。规范 §10 的文案三段式：发生了什么 + 可能原因 + 你能做什么。
  final String? hint;

  @override
  String toString() => '$message${hint == null ? '' : ' — $hint'}';
}

/// 一次校验的完整结果。
@immutable
class LintReport {
  const LintReport({
    required this.issues,
    this.theme,
    this.ratios = const {},
  });

  final List<LintIssue> issues;

  /// 校验通过时的生效主题；有 error 时为 `null`。
  final AppTheme? theme;

  /// 每对前景/背景的实测比值（键是 `onSurface/surface` 这种名字）。
  ///
  /// 达标与否之外还给出余量：刚过线的组合下次动一个色值就会掉下去。
  final Map<String, double> ratios;

  /// 是否存在 error 级问题。
  bool get hasError => issues.any((i) => i.severity == LintSeverity.error);

  /// 按级别过滤。
  Iterable<LintIssue> where(LintSeverity severity) =>
      issues.where((i) => i.severity == severity);
}

/// 主题包校验器。
class ThemeLinter {
  const ThemeLinter();

  /// 校验一段主题包 JSON 文本。
  ///
  /// [base] 是叠加用的基准主题；不给时按包声明的 `brightness` 推断（缺省深色，
  /// 与规范 §237「深色（默认）」一致）。
  LintReport lint(String jsonText, {AppTheme? base}) {
    final issues = <LintIssue>[];

    Object? json;
    try {
      json = jsonDecode(jsonText);
    } on FormatException catch (e) {
      return LintReport(
        issues: [
          LintIssue(
            LintSeverity.error,
            '不是合法 JSON：${e.message}',
            hint: '用带 JSON 校验的编辑器打开，常见原因是多写了逗号或用了单引号',
          ),
        ],
      );
    }

    if (json is! Map) {
      return LintReport(
        issues: [
          LintIssue(
            LintSeverity.error,
            '清单根节点是 ${_typeName(json)}，应该是对象',
          ),
        ],
      );
    }

    _lintManifest(json, issues);

    // 解析告警直接转成 warning —— 未知键、非法值都在这里被说出来。
    final pkg = ThemePackage.fromJson(
      json,
      onWarn: (m) => issues.add(LintIssue(LintSeverity.warning, m)),
    );

    final effectiveBase = base ?? _pickBase(pkg.isDark);
    final merged = pkg.applyTo(effectiveBase);

    _lintSelfConsistency(json, merged, issues);
    _lintCompleteness(pkg, effectiveBase, issues);

    final ratios = <String, double>{};
    for (final rule in contrastRules(merged.tokens)) {
      ratios[rule.name] = ContrastChecker.ratio(rule.fg, rule.bg);
    }

    for (final fail in checkContrast(merged.tokens)) {
      // fail 形如 `onSurface/surface 3.82 < 4.5`，取回名字给出可操作的提示。
      final name = fail.split(' ').first;
      final parts = name.split('/');
      issues.add(
        LintIssue(
          LintSeverity.error,
          '对比度不达标：$fail',
          hint:
              '改「${parts.first}」或「${parts.last}」其中一个即可'
              '（前者是前景，后者是背景）',
        ),
      );
    }

    for (final problem in validateTheme(merged)) {
      issues.add(
        LintIssue(
          LintSeverity.warning,
          problem,
          hint:
              '不会导致主题被拒，主题仍会加载；'
              '越界值会被夹进安全区间，不会按你写的原样生效',
        ),
      );
    }

    final hasError = issues.any((i) => i.severity == LintSeverity.error);
    return LintReport(
      issues: issues,
      theme: hasError ? null : merged,
      ratios: ratios,
    );
  }

  void _lintManifest(Map<Object?, Object?> root, List<LintIssue> issues) {
    final id = root['id'];
    if (id is! String || id.trim().isEmpty) {
      issues.add(
        const LintIssue(
          LintSeverity.error,
          '缺少 id（或不是非空字符串）',
          hint: '用反向域名，如 com.example.midnight',
        ),
      );
    }

    final type = root['type'];
    if (type != 'theme') {
      issues.add(
        LintIssue(
          LintSeverity.error,
          'type 是 $type，主题包必须是 "theme"',
          hint: 'type 决定加载器怎么读这个包，写错会当成别的插件类型',
        ),
      );
    }

    final version = root['version'];
    if (version is! String || version.trim().isEmpty) {
      issues.add(
        const LintIssue(
          LintSeverity.warning,
          '缺少 version',
          hint: '语义化版本，如 1.0.0',
        ),
      );
    }

    final theme = root['theme'];
    if (theme is! Map) {
      issues.add(
        const LintIssue(
          LintSeverity.error,
          '缺少 theme 对象',
          hint: '颜色令牌放在 theme.tokens 下',
        ),
      );
      return;
    }

    final tokens = theme['tokens'];
    if (tokens is! Map) {
      issues.add(
        const LintIssue(
          LintSeverity.error,
          '缺少 theme.tokens 对象',
          hint: '没有令牌可覆盖，这个包装上去什么也不会变',
        ),
      );
    } else if (tokens.isEmpty) {
      issues.add(
        const LintIssue(
          LintSeverity.warning,
          'theme.tokens 是空的',
          hint: '装上去不会有任何视觉变化',
        ),
      );
    }
  }

  /// 声明与令牌自洽。
  ///
  /// 最省事的写错方式是把 `brightness` 抄成反的：颜色全按浅色配，却声明
  /// `dark`，于是叠加到深色基准上，两套值互相打架。这里只看底色亮度与声明
  /// 是否同向——真正的对比度由断言负责。
  void _lintSelfConsistency(
    Map<Object?, Object?> root,
    AppTheme merged,
    List<LintIssue> issues,
  ) {
    final theme = root['theme'];
    if (theme is! Map) return;
    final declared = theme['brightness'];
    if (declared != 'dark' && declared != 'light') return;

    // 判据抽在 theme_engine 里，运行时（loadThemePackage）用的是同一份 ——
    // 只写在这里的话，不经 lint 直接装包的用户永远看不到这条提示。
    for (final problem in checkBrightnessConsistency(
      declared == 'dark',
      merged.tokens,
    )) {
      issues.add(
        LintIssue(
          LintSeverity.warning,
          problem,
          hint:
              '多半是 brightness 抄反了；它决定这个包叠到哪套内置主题上，'
              '也决定系统 UI（状态栏、滚动条）按明还是按暗画',
        ),
      );
    }
  }

  /// 没覆盖的令牌会取基准主题的值——说清楚，否则作者会以为自己的包是完整配色。
  void _lintCompleteness(
    ThemePackage pkg,
    AppTheme base,
    List<LintIssue> issues,
  ) {
    final missing = base.tokens
        .toMap()
        .keys
        .where((k) => !pkg.tokens.containsKey(k))
        .toList();
    if (missing.isEmpty) return;

    issues.add(
      LintIssue(
        LintSeverity.info,
        '${missing.length} 个颜色令牌未覆盖，将取内置「${base.name}」的值：'
        '${missing.join('、')}',
        hint: '只改想改的那几个是推荐做法，但要知道其余不是你的包提供的',
      ),
    );
  }

  static AppTheme _pickBase(bool? isDark) => switch (isDark) {
    true => AppTheme.dark,
    false => AppTheme.light,
    // 没声明就按规范默认的深色，与运行时一致。
    null => AppTheme.dark,
  };
}

String _typeName(Object? v) => switch (v) {
  null => 'null',
  List() => '数组',
  num() => '数字',
  bool() => '布尔',
  String() => '字符串',
  _ => v.runtimeType.toString(),
};
