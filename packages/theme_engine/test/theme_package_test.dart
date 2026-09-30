import 'package:test/test.dart';
import 'package:theme_engine/theme_engine.dart';

/// 一份只覆盖主色的合法主题包。
Map<String, Object?> _pkg(
  Map<String, Object?> tokens, {
  Object? brightness,
  Object? theme,
}) => {
  'id': 'com.example.midnight',
  'type': 'theme',
  'version': '1.0.0',
  'theme':
      theme ??
      {
        if (brightness != null) 'brightness': brightness,
        'tokens': tokens,
      },
};

void main() {
  group('ThemePackage.fromJson', () {
    test('覆盖已知令牌', () {
      final pkg = ThemePackage.fromJson(_pkg({'color.primary': '#5B3FD6'}));
      expect(pkg.tokens['primary'], 0xFF5B3FD6);
      expect(pkg.id, 'com.example.midnight');
    });

    test('三种颜色写法都认', () {
      int parse(String v) =>
          ThemePackage.fromJson(_pkg({'color.primary': v})).tokens['primary']!;
      expect(parse('#F00'), 0xFFFF0000);
      expect(parse('#FF0000'), 0xFFFF0000);
      // #AARRGGBB 里 alpha 必须是 FF —— 带透明度的会被拒，见下一条用例。
      expect(parse('#FFFF0000'), 0xFFFF0000);
    });

    /// ⚠️ 这条用例原先写的是 `expect(parse('#80FF0000'), 0x80FF0000)`，
    /// 等于把不安全行为**锁死**了：对比度计算只看 RGB、忽略 alpha，放行
    /// 半透明/全透明颜色会让「不达标就回退」那道防线静默失效
    /// （全透明黑底 + 全透明白字算出来 21:1，渲染出来什么都看不见）。
    test('带透明度的颜色一律拒掉（对比度计算忽略 alpha）', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({
          'color.background': '#00000000', // 全透明黑
          'color.primaryText': '#00FFFFFF', // 全透明白
          'color.surface': '#80FFFFFF', // 半透明白
        }),
        onWarn: warns.add,
      );
      expect(pkg.tokens, isEmpty, reason: '带 alpha 的颜色一个都不该进来');
      expect(warns, hasLength(3), reason: '每行输入只报一条，不重复刷');
      expect(warns.every((w) => w.contains('带透明度')), isTrue);

      // 整数写法同样受约束
      final fromInt = ThemePackage.fromJson(
        _pkg({'color.primary': 0x80FF0000}),
      );
      expect(fromInt.tokens, isEmpty);
      // 不透明整数照常采纳
      final opaque = ThemePackage.fromJson(_pkg({'color.primary': 0xFF5B3FD6}));
      expect(opaque.tokens['primary'], 0xFF5B3FD6);
    });

    test('非法颜色值忽略并告警', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({'color.primary': 'red', 'color.surface': '#12345'}),
        onWarn: warns.add,
      );
      expect(pkg.tokens, isEmpty);
      expect(warns.any((w) => w.contains('color.primary')), isTrue);
      expect(warns.any((w) => w.contains('color.surface')), isTrue);
    });

    test('整数写法按 ARGB 直接采纳', () {
      final pkg = ThemePackage.fromJson(_pkg({'color.primary': 0xFF5B3FD6}));
      expect(pkg.tokens['primary'], 0xFF5B3FD6);
    });

    test('未知 color.* 键告警，非颜色键静默忽略', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({
          'color.notAToken': '#000000',
          'radius.card': 12,
          'spacing.unit': 4,
          'font.family': 'Inter',
        }),
        onWarn: warns.add,
      );
      expect(pkg.tokens, isEmpty);
      expect(warns.single, contains('color.notAToken'));
    });

    test('根节点/theme/tokens 形状不对只告警不抛', () {
      final warns = <String>[];
      for (final bad in <Object?>[
        null,
        42,
        'x',
        [],
        {'theme': 3},
      ]) {
        final pkg = ThemePackage.fromJson(bad, onWarn: warns.add);
        expect(pkg.tokens, isEmpty);
      }
      expect(warns, isNotEmpty);

      // theme 存在但没有 tokens
      final pkg = ThemePackage.fromJson(
        _pkg({}, theme: <String, Object?>{}),
        onWarn: warns.add,
      );
      expect(pkg.tokens, isEmpty);
    });

    test('brightness 声明 dark / light / 非法', () {
      expect(
        ThemePackage.fromJson(_pkg({}, brightness: 'dark')).isDark,
        isTrue,
      );
      expect(
        ThemePackage.fromJson(_pkg({}, brightness: 'light')).isDark,
        isFalse,
      );
      final warns = <String>[];
      expect(
        ThemePackage.fromJson(
          _pkg({}, brightness: 'dim'),
          onWarn: warns.add,
        ).isDark,
        isNull,
      );
      expect(warns.single, contains('brightness'));
    });
  });

  group('ThemePackage.applyTo', () {
    test('缺失的令牌取基准主题', () {
      final merged = ThemePackage.fromJson(
        _pkg({'color.primary': '#5B3FD6'}),
      ).applyTo(AppTheme.dark);
      expect(merged.tokens.primary, 0xFF5B3FD6);
      expect(merged.tokens.onSurface, AppTheme.dark.tokens.onSurface);
    });

    test('包声明的明暗优先于基准主题', () {
      final merged = ThemePackage.fromJson(
        _pkg({'color.background': '#000000'}, brightness: 'dark'),
      ).applyTo(AppTheme.light);
      expect(merged.isDark, isTrue);
    });
  });

  group('loadThemePackage', () {
    test('达标则应用', () {
      final result = loadThemePackage(
        _pkg({'color.primary': '#5B3FD6'}, brightness: 'light'),
        base: AppTheme.light,
      );
      expect(result.fellBack, isFalse);
      expect(result.theme.tokens.primary, 0xFF5B3FD6);
      expect(result.warnings, isEmpty);
    });

    /// 规范 §9：不达标必须回退内置主题并告知是哪个令牌。这里让文字与底色同
    /// 色，比值正好 1.0，是最坏情况。
    test('对比度不达标则回退并说出是哪个令牌', () {
      final result = loadThemePackage(
        _pkg({'color.onSurface': '#FFFFFF'}, brightness: 'light'),
        base: AppTheme.light,
      );
      expect(result.fellBack, isTrue);
      expect(result.theme, AppTheme.light);
      expect(result.warnings.join(), contains('onSurface/surface'));
    });

    test('畸形包不会抛出，退化成基准主题', () {
      for (final bad in <Object?>[
        null,
        'not json',
        1,
        {'theme': 'x'},
      ]) {
        final result = loadThemePackage(bad, base: AppTheme.dark);
        expect(result.fellBack, isFalse);
        // 比令牌而不是比实例：applyTo 会合成一个新 AppTheme。
        expect(result.theme.tokens.toMap(), AppTheme.dark.tokens.toMap());
      }
    });

    test('部分覆盖：只改主色也要连带给出 onPrimary', () {
      // 只给 primary 不给 onPrimary 时，onPrimary 沿用基准主题的深色墨。
      // 基准是浅色（白墨），叠一个亮主色就会不达标——这正是要验的场景。
      final result = loadThemePackage(
        _pkg({'color.primary': '#E0E7FF'}, brightness: 'light'),
        base: AppTheme.light,
      );
      expect(result.fellBack, isTrue);
      expect(result.warnings.join(), contains('onPrimary/primary'));
    });

    /// ROADMAP M9 出口标准：**畸形主题包不导致白屏或不可读对比度**。
    ///
    /// 这条的原始缺陷是：对比度计算忽略 alpha，于是「全透明黑底 + 全透明白字」
    /// 以 21:1 满分通过，渲染出来却什么都看不见 —— 等效白屏。修法是在解析阶段
    /// 就把带 alpha 的颜色拒掉，让令牌集**恒为不透明**，对比度结论才等于渲染。
    test('全透明配色不会生效（原先是能满分通过的）', () {
      final result = loadThemePackage(
        _pkg({
          'color.background': '#00000000',
          'color.primaryText': '#00FFFFFF',
          'color.onSurface': '#00000000',
        }),
        base: AppTheme.dark,
      );

      // 三个透明令牌全被拒 → 合成结果就是基准主题，全部不透明
      expect(
        result.theme.tokens.toMap(),
        AppTheme.dark.tokens.toMap(),
        reason: '透明令牌一个都不能生效',
      );
      for (final entry in result.theme.tokens.toMap().entries) {
        expect(
          (entry.value >> 24) & 0xFF,
          0xFF,
          reason: '${entry.key} 必须不透明',
        );
      }
      expect(result.warnings.join(), contains('带透明度'));
    });

    test('基准主题本身带透明度也会被拦住', () {
      // 令牌集不透明这条不变量不能只在「主题包」这条路径上守：
      // 合成结果要再查一遍，直接构造出来的畸形 AppTheme 同样过不去。
      const translucentBase = AppTheme(
        id: 'bad-base',
        name: '畸形基准',
        isDark: true,
        tokens: DesignTokens(
          primary: 0x80818CF8,
          onPrimary: 0xFF0F172A,
          primaryText: 0xFFA5B4FC,
          background: 0xFF0F172A,
          surface: 0xFF1E293B,
          surfaceVariant: 0xFF2C3849,
          onSurface: 0xFFE2E8F0,
          onSurfaceMuted: 0xFF94A3B8,
          outline: 0xFF2A303C,
          outlineStrong: 0xFF7C8DA6,
        ),
      );

      final result = loadThemePackage(_pkg({}), base: translucentBase);

      expect(result.fellBack, isTrue);
      expect(result.theme, translucentBase);
      expect(result.warnings.join(), contains('primary 带透明度'));
    });

    test('尺度越界值被夹住，不会原样生效（否则布局崩/白屏）', () {
      final result = loadThemePackage(
        _pkg({
          'spacing.unit': 1e300,
          'radius.lg': -1,
          'elevation.overlay': 1e300,
        }),
        base: AppTheme.dark,
      );

      final s = result.theme.scale;
      expect(s.unit, kMaxSpacingUnit);
      expect(s.radiusLg, 0);
      expect(s.elevationOverlay, kMaxElevation);
      expect(s.spacing(4).isFinite, isTrue);
      // 夹住的同时必须告警，否则作者会反复调一个「改了没用」的数字。
      // 告警基于**原始值**（1e+300 / -1），不是夹住后的值。
      expect(result.warnings.join(), contains('超过上限'));
      expect(result.warnings.join(), contains('低于下限'));
      expect(result.warnings.join(), contains('1e+300'));
    });

    test('内置四套主题不受 clampScale 影响（上界留足了余量）', () {
      for (final theme in AppTheme.builtIns) {
        expect(
          clampScale(theme.scale).toMap(),
          theme.scale.toMap(),
          reason: '${theme.id} 的尺度令牌不该被夹住',
        );
        expect(validateScale(theme.scale), isEmpty, reason: theme.id);
        expect(findTranslucentTokens(theme.tokens), isEmpty, reason: theme.id);
      }
    });

    /// brightness 决定**系统 UI**（状态栏图标、滚动条）按明还是按暗画，而配色
    /// 由令牌决定。两者矛盾时系统 UI 那部分不可读 —— 且对比度断言查不出来
    /// （断言只看令牌之间）。所以它必须是一条**独立**的告警。
    test('声明 brightness 与实际底色矛盾时告警，但不回退', () {
      // outline 不在任何对比度规则里，保证这条用例只测 brightness 这一件事。
      final result = loadThemePackage(
        _pkg({'color.outline': '#334155'}, brightness: 'light'),
        base: AppTheme.dark,
      );

      expect(result.fellBack, isFalse, reason: '配色本身合规，不该回退');
      expect(result.theme.isDark, isFalse, reason: '声明优先');
      expect(result.warnings.join(), contains('brightness'));
      expect(result.warnings.join(), contains('深色'));
    });

    test('brightness 与底色一致时不告警', () {
      final result = loadThemePackage(
        _pkg({'color.outline': '#E2E8F0'}, brightness: 'light'),
        base: AppTheme.light,
      );
      expect(result.fellBack, isFalse);
      expect(result.warnings.join(), isNot(contains('brightness')));
    });

    test('没声明 brightness 时不判断（无从判断就不猜）', () {
      final result = loadThemePackage(
        _pkg({'color.outline': '#334155'}),
        base: AppTheme.dark,
      );
      expect(result.warnings.join(), isNot(contains('brightness')));
    });
  });

  group('不透明性与尺度兜底（独立单测）', () {
    test('findTranslucentTokens 按令牌名报出问题', () {
      const t = DesignTokens(
        primary: 0x80818CF8, // 半透明
        onPrimary: 0xFF0F172A,
        primaryText: 0xFFA5B4FC,
        background: 0x000F172A, // 全透明
        surface: 0xFF1E293B,
        surfaceVariant: 0xFF2C3849,
        onSurface: 0xFFE2E8F0,
        onSurfaceMuted: 0xFF94A3B8,
        outline: 0xFF2A303C,
        outlineStrong: 0xFF7C8DA6,
      );

      final problems = findTranslucentTokens(t);
      expect(problems, hasLength(2));
      expect(problems.join(), contains('primary'));
      expect(problems.join(), contains('background'));
      expect(problems.join(), contains('alpha=0x80'));
    });

    test('clampScale 幂等，且非有限值回落到规范默认', () {
      const s = DesignScale.standard;
      expect(clampScale(s).toMap(), s.toMap());
      expect(clampScale(clampScale(s)).toMap(), clampScale(s).toMap());

      final nan = clampScale(
        const DesignScale(unit: double.nan, radiusSm: double.infinity),
      );
      expect(nan.unit, s.unit);
      expect(nan.radiusSm, s.radiusSm);
    });

    test('clampScale 只守安全边界，不纠正单调性（那是告警的职责）', () {
      // 顺序反了不会崩也不会白屏，交给 validateScale 告警，不在这里改
      final inverted = clampScale(
        const DesignScale(radiusSm: 9999, radiusMd: 0, radiusLg: 0),
      );
      expect(inverted.radiusSm, 9999);
      expect(inverted.radiusMd, 0);
      expect(validateScale(inverted), isNotEmpty);
    });
  });

  group('尺度与字体令牌（规范 §2.2 / §2.3）', () {
    test('解析 spacing / radius / elevation / font', () {
      final pkg = ThemePackage.fromJson(
        _pkg({
          'spacing.unit': 8,
          'radius.md': 12,
          'radius.lg': 20,
          'elevation.card': 2,
          'font.scale': 1.25,
          'font.family': 'Inter',
        }),
      );
      expect(pkg.numbers['unit'], 8);
      expect(pkg.numbers['radiusMd'], 12);
      expect(pkg.numbers['radiusLg'], 20);
      expect(pkg.numbers['elevationCard'], 2);
      expect(pkg.numbers['scale'], 1.25);
      expect(pkg.strings['family'], 'Inter');
    });

    /// 06-插件系统.md §9 的示例里写的是 `radius.card`，规范 §2.2 里没这个名字。
    /// 示例是主题作者最先照抄的东西，必须认。
    test('radius.card 映射到 radius.md', () {
      final merged = ThemePackage.fromJson(
        _pkg({'radius.card': 12}),
      ).applyTo(AppTheme.dark);
      expect(merged.scale.radiusMd, 12);
    });

    test('数值可以写成字符串', () {
      final pkg = ThemePackage.fromJson(_pkg({'spacing.unit': '6'}));
      expect(pkg.numbers['unit'], 6);
    });

    test('非法数值告警并忽略', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({'radius.md': 'round', 'font.scale': true}),
        onWarn: warns.add,
      );
      expect(pkg.numbers, isEmpty);
      expect(warns.any((w) => w.contains('radius.md')), isTrue);
      expect(warns.any((w) => w.contains('font.scale')), isTrue);
    });

    test('font.family 非字符串或空串告警', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({'font.family': '   '}),
        onWarn: warns.add,
      );
      expect(pkg.strings, isEmpty);
      expect(warns.single, contains('font.family'));
    });

    test('未覆盖的尺度令牌取基准值', () {
      final merged = ThemePackage.fromJson(
        _pkg({'spacing.unit': 8}),
      ).applyTo(AppTheme.dark);
      expect(merged.scale.unit, 8);
      expect(merged.scale.radiusLg, AppTheme.dark.scale.radiusLg);
      expect(merged.typography.scale, AppTheme.dark.typography.scale);
    });

    /// 尺度/字体错了不会让界面不可读，所以夹住/按基准用即可，**不该整包回退**
    /// ——用户明明只想改一个圆角。
    test('尺度问题只告警，不触发回退', () {
      final result = loadThemePackage(
        _pkg({'radius.md': 40, 'radius.lg': 8}, brightness: 'dark'),
        base: AppTheme.dark,
      );
      expect(result.fellBack, isFalse);
      expect(result.warnings.join(), contains('圆角必须单调递增'));
    });

    test('font.scale 越界会被告警，生效值被夹住', () {
      final result = loadThemePackage(
        _pkg({'font.scale': 3}, brightness: 'dark'),
        base: AppTheme.dark,
      );
      expect(result.fellBack, isFalse);
      expect(result.theme.typography.effectiveScale, DesignTypography.maxScale);
      expect(result.warnings.join(), contains('超出规范区间'));
    });

    test('尚未落地的名字空间静默忽略，不刷告警', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({'assets.background': 'bg.jpg', 'i18n.locale': 'zh-CN'}),
        onWarn: warns.add,
      );
      expect(pkg.tokens, isEmpty);
      expect(pkg.numbers, isEmpty);
      expect(warns, isEmpty, reason: '未落地的名字空间不该逐个告警');
    });
  });

  group('动效令牌', () {
    test('覆盖时长与曲线', () {
      final merged = ThemePackage.fromJson(
        _pkg({'motion.hover': 90, 'motion.overlay.curve': 'easeInOut'}),
      ).applyTo(AppTheme.dark);

      expect(merged.motion.hover.duration, const Duration(milliseconds: 90));
      // 只覆盖时长时，曲线仍取基准的
      expect(merged.motion.hover.curve, MotionCurve.easeOut);
      expect(merged.motion.overlay.curve, MotionCurve.easeInOut);
      // 只覆盖曲线时，时长仍取基准的
      expect(merged.motion.overlay.duration, const Duration(milliseconds: 200));
    });

    test('没覆盖的场景取基准值', () {
      final merged = ThemePackage.fromJson(
        _pkg({'motion.hover': 90}),
      ).applyTo(AppTheme.dark);

      expect(
        merged.motion.playerControls,
        DesignMotion.standard.playerControls,
      );
    });

    test('时长可以写成字符串', () {
      final pkg = ThemePackage.fromJson(_pkg({'motion.hover': '90'}));
      expect(pkg.motionDurations['hover'], 90);
    });

    test('非法时长告警并忽略', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({'motion.hover': '120ms'}),
        onWarn: warns.add,
      );
      expect(pkg.motionDurations, isEmpty);
      expect(warns.single, contains('motion.hover'));
    });

    test('未知曲线告警并忽略，且提示有哪些可用', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({'motion.hover.curve': 'easeInOutSine'}),
        onWarn: warns.add,
      );
      expect(pkg.motionCurves, isEmpty);
      expect(warns.single, contains('easeInOutSine'));
      expect(warns.single, contains('easeOutCubic'));
    });

    /// `motion.*` 现在是我们支持的名字空间了，陌生键多半是拼错。
    test('未知 motion.* 键告警', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({'motion.page': 240, 'motion.hover.duration': 120}),
        onWarn: warns.add,
      );
      expect(pkg.motionDurations, isEmpty);
      expect(warns, hasLength(2));
      expect(warns.join(), contains('motion.page'));
    });

    /// 「减少动效」是无障碍选项，不是审美选项——主题包说了不算。
    test('主题包不能设置 reduceMotion', () {
      final warns = <String>[];
      final pkg = ThemePackage.fromJson(
        _pkg({'motion.reduceMotion': true}),
        onWarn: warns.add,
      );
      expect(warns.single, contains('motion.reduceMotion'));

      expect(pkg.applyTo(AppTheme.dark).motion.reduceMotion, isFalse);
    });

    test('基准已开减少动效时，主题包覆盖不会把它关掉', () {
      final base = AppTheme(
        id: 'base',
        name: '基准',
        isDark: true,
        tokens: AppTheme.dark.tokens,
        motion: DesignMotion.standard.copyWith(reduceMotion: true),
      );

      final merged = ThemePackage.fromJson(
        _pkg({'motion.hover': 90}),
      ).applyTo(base);

      expect(merged.motion.reduceMotion, isTrue);
      // 覆盖进来的 90ms 被「减少动效」压掉了
      expect(merged.motion.effectiveHover.duration, Duration.zero);
    });

    /// 畸形包不得导致崩溃：`(1e30 * 1000).round()` 会抛 UnsupportedError。
    test('超大时长不崩，被夹住并被告警', () {
      final result = loadThemePackage(
        _pkg({'motion.hover': 1e30}, brightness: 'dark'),
        base: AppTheme.dark,
      );

      expect(result.fellBack, isFalse);
      expect(result.theme.motion.hover.duration, const Duration(hours: 1));
      expect(result.warnings.join(), contains('超过 1000ms'));
    });

    test('动效问题只告警，不触发回退', () {
      final result = loadThemePackage(
        _pkg({'motion.overlay': -5}, brightness: 'dark'),
        base: AppTheme.dark,
      );
      expect(result.fellBack, isFalse);
      expect(result.warnings.join(), contains('不能为负'));
    });
  });
}
