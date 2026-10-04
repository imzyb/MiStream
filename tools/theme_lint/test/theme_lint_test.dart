import 'dart:convert';

import 'package:test/test.dart';
import 'package:theme_engine/theme_engine.dart';
import 'package:theme_lint/theme_lint.dart';

/// 把一套令牌转成清单里的 `#RRGGBB` 写法。
Map<String, Object?> _hexTokens(DesignTokens t) => {
  for (final e in t.toMap().entries)
    'color.${e.key}':
        '#${(e.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
};

/// 一份合法的最小主题包。
///
/// 默认只改 `color.outline`——它是**装饰性**令牌，不在对比度断言矩阵里，所以
/// 无论叠到浅色还是深色基准上都不会顺带制造对比度错误。用例想验的是清单结构，
/// 不该被配色的连带影响搅进来。
String _valid({
  Map<String, Object?>? tokens,
  String id = 'com.example.midnight',
  String type = 'theme',
  String? version = '1.0.0',
  String? brightness = 'light',
}) => jsonEncode({
  'id': id,
  'type': type,
  'version': ?version,
  'theme': {
    'brightness': ?brightness,
    'tokens': tokens ?? const {'color.outline': '#CBD5E1'},
  },
});

List<String> _messages(LintReport r) => r.issues.map((i) => i.message).toList();

/// 提示文案是独立字段（规范 §10 的三段式：发生了什么 + 你能做什么），
/// 断言「作者能看到怎么改」时必须连它一起看。
List<String> _hints(LintReport r) => r.issues.map((i) => i.hint ?? '').toList();

void main() {
  const linter = ThemeLinter();

  group('清单结构', () {
    test('合法包通过', () {
      final report = linter.lint(_valid());
      expect(report.hasError, isFalse);
      expect(report.theme, isNotNull);
    });

    test('不是合法 JSON → error', () {
      final report = linter.lint('{ "id": "x", }');
      expect(report.hasError, isTrue);
      expect(_messages(report).single, contains('不是合法 JSON'));
    });

    test('根节点不是对象 → error', () {
      for (final bad in ['[]', '"x"', '42', 'null']) {
        expect(linter.lint(bad).hasError, isTrue, reason: '$bad 应被拒');
      }
    });

    test('id 为空 / type 写错 / 缺 version', () {
      expect(linter.lint(_valid(id: '')).hasError, isTrue, reason: '空 id 应被拒');

      final wrongType = linter.lint(_valid(type: 'spider'));
      expect(wrongType.hasError, isTrue);
      expect(_messages(wrongType).join(), contains('必须是 "theme"'));

      final noVersion = linter.lint(_valid(version: null));
      expect(noVersion.hasError, isFalse);
      expect(_messages(noVersion).join(), contains('缺少 version'));
    });

    test('缺 theme 对象 / 空 tokens', () {
      final noTheme = linter.lint(jsonEncode({'id': 'a.b', 'type': 'theme'}));
      expect(noTheme.hasError, isTrue);
      expect(_messages(noTheme).join(), contains('缺少 theme 对象'));

      final empty = linter.lint(_valid(tokens: const {}));
      expect(empty.hasError, isFalse);
      expect(_messages(empty).join(), contains('theme.tokens 是空的'));
    });
  });

  group('对比度', () {
    /// 与运行时同一份断言：白字压在白色卡片上，比值 1.0。
    test('不达标 → error，并指出改哪两个令牌', () {
      final report = linter.lint(
        _valid(tokens: const {'color.onSurface': '#FFFFFF'}),
      );
      expect(report.hasError, isTrue);
      expect(report.theme, isNull, reason: '有 error 时不该给出生效主题');

      // onSurface 同时出现在 onSurface/background 与 onSurface/surface 两对里，
      // 两条都会报，这里看全量。
      final contrast = report
          .where(LintSeverity.error)
          .where((i) => i.message.contains('对比度'))
          .toList();
      expect(contrast, isNotEmpty);
      expect(_messages(report).join(), contains('onSurface/surface'));
      expect(_hints(report).join(), contains('onSurface'));
    });

    test('达标时给出全部实测比值，供作者看余量', () {
      final report = linter.lint(_valid());
      expect(
        report.ratios,
        hasLength(contrastRules(AppTheme.light.tokens).length),
      );
      expect(report.ratios['onSurface/surface'], greaterThan(4.5));
    });
  });

  group('自洽与完整性', () {
    /// 这套包**本身**是自洽的（照抄内置深色，对比度全过），错的只是声明。
    /// 危害在派生色：`isDark` 决定 `ColorScheme.fromSeed` 走哪套亮度，声明成
    /// light 会让 secondary / tertiary / error 全部取浅色变体，压在深底上。
    /// 光靠对比度断言抓不到，必须单独查。
    test('整套深色令牌却声明 light → 告警', () {
      final report = linter.lint(
        _valid(tokens: _hexTokens(AppTheme.dark.tokens), brightness: 'light'),
      );
      expect(report.hasError, isFalse, reason: '对比度本身是过的');
      expect(_messages(report).join(), contains('声明 brightness=light'));
      expect(_hints(report).join(), contains('多半是 brightness 抄反了'));
    });

    test('声明与令牌同向时不告警', () {
      final report = linter.lint(
        _valid(tokens: _hexTokens(AppTheme.dark.tokens), brightness: 'dark'),
      );
      expect(_messages(report).join(), isNot(contains('brightness')));
    });

    test('未覆盖的令牌以 info 列出', () {
      final report = linter.lint(_valid());
      final info = report.where(LintSeverity.info).single;
      expect(info.message, contains('未覆盖'));
      expect(info.message, contains('onSurface'));
      // 覆盖了的那个不该被算成缺失
      expect(info.message, isNot(contains('outline、')));
    });

    test('全覆盖时不报缺失', () {
      final report = linter.lint(
        _valid(tokens: _hexTokens(AppTheme.light.tokens), brightness: 'light'),
      );
      expect(report.hasError, isFalse);
      expect(report.where(LintSeverity.info), isEmpty);
    });
  });

  group('尺度与字体', () {
    test('圆角顺序反了只是 warning，不阻止加载', () {
      final report = linter.lint(
        _valid(
          tokens: const {
            'color.outline': '#CBD5E1',
            'radius.md': 40,
            'radius.lg': 8,
          },
        ),
      );
      expect(report.hasError, isFalse);
      expect(_messages(report).join(), contains('圆角必须单调递增'));
    });

    test('font.scale 越界会被告警', () {
      final report = linter.lint(
        _valid(
          tokens: const {'color.outline': '#CBD5E1', 'font.scale': 3},
        ),
      );
      expect(report.hasError, isFalse);
      expect(_messages(report).join(), contains('超出规范区间'));
    });

    /// 「不会导致被拒」不等于「按默认值使用」——两者的区别要留在文案里。
    /// 注意：越界值现在会在**解析阶段**被夹住（另有一条告警说明夹成了什么），
    /// 所以这里只说「仍会加载」，不对生效值做「原样生效」的承诺。
    test('告警的提示不承诺「按默认值使用」', () {
      final report = linter.lint(
        _valid(
          tokens: const {
            'color.outline': '#CBD5E1',
            'radius.md': 40,
            'radius.lg': 8,
          },
        ),
      );
      final hint = _hints(report).firstWhere((h) => h.contains('不会导致主题被拒'));
      expect(hint, isNot(contains('默认值')));
      expect(hint, contains('夹进安全区间'));
    });

    /// 尺度越界值必须被夹住并说清夹成了什么，否则作者会反复调一个
    /// 「改了没用」的数字。夹住发生在解析阶段，所以是 warning 而非 error。
    test('尺度越界值被夹住并告警', () {
      final report = linter.lint(
        _valid(
          tokens: const {
            'color.outline': '#CBD5E1',
            'spacing.unit': -5,
            'radius.full': 1e300,
          },
        ),
      );
      expect(report.hasError, isFalse);
      final messages = _messages(report).join();
      expect(messages, contains('低于下限'));
      expect(messages, contains('超过上限'));
      expect(report.theme, isNotNull);
      expect(report.theme!.scale.unit, 1);
      expect(report.theme!.scale.radiusFull, kMaxRadius);
    });

    /// 带透明度的颜色会被解析阶段拒掉（对比度计算忽略 alpha，放行会让
    /// 「不达标就回退」静默失效）。lint 与运行时都不把它当错误 —— 令牌被丢
    /// 掉之后合成结果仍然合规。
    test('带透明度的颜色被拒并告警，但不判为错误', () {
      final report = linter.lint(
        _valid(
          tokens: const {
            'color.outline': '#CBD5E1',
            'color.background': '#00000000',
          },
        ),
      );
      expect(report.hasError, isFalse);
      expect(_messages(report).join(), contains('带透明度'));
    });
  });

  group('动效', () {
    test('时长超上限只是 warning，不阻止加载', () {
      final report = linter.lint(
        _valid(
          tokens: const {'color.outline': '#CBD5E1', 'motion.hover': 1500},
        ),
      );
      expect(report.hasError, isFalse);
      expect(_messages(report).join(), contains('超过 1000ms'));
    });

    test('负时长被告警', () {
      final report = linter.lint(
        _valid(
          tokens: const {'color.outline': '#CBD5E1', 'motion.overlay': -5},
        ),
      );
      expect(report.hasError, isFalse);
      expect(_messages(report).join(), contains('不能为负'));
    });

    test('未知曲线名被告警，且提示有哪些可用', () {
      final report = linter.lint(
        _valid(
          tokens: const {
            'color.outline': '#CBD5E1',
            'motion.hover.curve': 'bounce',
          },
        ),
      );
      expect(report.hasError, isFalse);
      expect(_messages(report).join(), contains('bounce'));
      expect(_messages(report).join(), contains('easeOutCubic'));
    });

    test('主题包设置 reduceMotion 被告警', () {
      final report = linter.lint(
        _valid(
          tokens: const {
            'color.outline': '#CBD5E1',
            'motion.reduceMotion': true,
          },
        ),
      );
      expect(report.hasError, isFalse);
      expect(_messages(report).join(), contains('motion.reduceMotion'));
    });

    test('合法的动效覆盖通过，生效值取到包里的', () {
      final report = linter.lint(
        _valid(
          tokens: const {
            'color.outline': '#CBD5E1',
            'motion.hover': 90,
            'motion.overlay.curve': 'easeInOut',
          },
        ),
      );
      expect(report.hasError, isFalse);
      expect(
        report.theme!.motion.hover.duration,
        const Duration(milliseconds: 90),
      );
      expect(report.theme!.motion.overlay.curve, MotionCurve.easeInOut);
      // 没覆盖的场景取基准值
      expect(
        report.theme!.motion.playerControls,
        DesignMotion.standard.playerControls,
      );
    });
  });

  group('基准主题', () {
    test('不指定时按 brightness 推断', () {
      expect(linter.lint(_valid(brightness: 'dark')).theme!.isDark, isTrue);
      expect(linter.lint(_valid(brightness: 'light')).theme!.isDark, isFalse);
    });

    test('不声明 brightness 时按规范默认的深色', () {
      final report = linter.lint(_valid(brightness: null));
      expect(report.theme!.isDark, isTrue);
    });

    test('显式指定 base 会覆盖推断', () {
      // 包里只覆盖了 color.outline，其余令牌从 base 取——用 background 的来源
      // 判断 base 到底生效没有。（id 是主题包自己的，不会变成 base 的。）
      final report = linter.lint(
        _valid(brightness: 'light'),
        base: AppTheme.oled,
      );
      expect(report.theme!.id, 'com.example.midnight');
      expect(report.theme!.tokens.background, AppTheme.oled.tokens.background);
      expect(
        report.theme!.tokens.background,
        isNot(AppTheme.light.tokens.background),
      );
    });
  });

  group('与运行时一致', () {
    /// lint 说通过、装上却被拒，是最难查的一类问题。这里直接拿运行时的
    /// `loadThemePackage` 对同一份文本再跑一遍，两边结论必须一致。
    test('lint 的结论与 loadThemePackage 一致', () {
      final samples = <String>[
        _valid(),
        _valid(tokens: const {'color.onSurface': '#FFFFFF'}), // 对比度挂
        _valid(tokens: const {'color.primary': 'red'}), // 非法值
        _valid(tokens: const {'color.unknown': '#123456'}), // 未知键
        _valid(tokens: _hexTokens(AppTheme.dark.tokens), brightness: 'dark'),
        // 动效问题不该把两边拉歪：lint 给 warning，运行时也不回退。
        _valid(tokens: const {'motion.hover': 1500}),
        _valid(tokens: const {'motion.hover.curve': 'bounce'}),
        _valid(tokens: const {'motion.reduceMotion': true}),
        _valid(tokens: const {'motion.hover': 1e30}),
        // 畸形但安全的输入：两边都只告警，不判错误、不回退。
        _valid(tokens: const {'color.background': '#00000000'}), // 带透明度
        _valid(tokens: const {'spacing.unit': -5}), // 尺度越界
        _valid(tokens: const {'spacing.unit': 1e300}),
      ];

      for (final text in samples) {
        final report = linter.lint(text);
        final runtime = loadThemePackage(
          jsonDecode(text),
          base: AppTheme.light,
        );
        expect(
          report.hasError,
          runtime.fellBack,
          reason: 'lint 与运行时结论不一致：$text',
        );
      }
    });
  });
}
