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
      expect(parse('#80FF0000'), 0x80FF0000);
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
