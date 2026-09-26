import 'package:test/test.dart';
import 'package:theme_engine/theme_engine.dart';

void main() {
  group('DesignScale', () {
    test('默认值即规范 §2.2', () {
      const s = DesignScale.standard;
      expect(s.unit, 4);
      expect(
        [s.radiusSm, s.radiusMd, s.radiusLg, s.radiusFull],
        [4, 8, 16, 9999],
      );
      expect(
        [s.elevationCard, s.elevationDialog, s.elevationOverlay],
        [1, 8, 16],
      );
    });

    test('spacing 是 unit 的整数倍', () {
      const s = DesignScale.standard;
      expect(s.spacing(1), 4);
      expect(s.spacing(4), 16);
      expect(s.spacing(12), 48);
      // 规范列的每一档都落在整数倍上
      for (final step in DesignScale.steps) {
        expect(s.spacing(step) % s.unit, 0, reason: '第 $step 档不是 unit 的整数倍');
      }
    });

    test('默认值本身通过校验', () {
      expect(validateScale(DesignScale.standard), isEmpty);
    });

    test('非正数的 unit 报错', () {
      expect(validateScale(const DesignScale(unit: 0)), isNotEmpty);
      expect(validateScale(const DesignScale(unit: -4)), isNotEmpty);
    });

    test('圆角顺序反了要报出来', () {
      // lg 比 md 小 → 「大圆角」比「中圆角」还方
      final problems = validateScale(
        const DesignScale(radiusMd: 16, radiusLg: 8),
      );
      expect(problems.join(), contains('圆角必须单调递增'));
    });

    test('radius.full 小于 radius.lg 要报出来', () {
      final problems = validateScale(
        const DesignScale(radiusLg: 16, radiusFull: 12),
      );
      expect(problems.join(), contains('radius.full'));
    });

    test('投影顺序反了要报出来', () {
      final problems = validateScale(
        const DesignScale(elevationCard: 16, elevationDialog: 8),
      );
      expect(problems.join(), contains('投影必须单调递增'));
    });
  });

  group('DesignTypography', () {
    test('默认值即规范 §2.3', () {
      const t = DesignTypography.standard;
      expect(t.display, const TextStyleSpec(size: 28, weight: 600));
      expect(t.title, const TextStyleSpec(size: 20, weight: 600));
      expect(t.subtitle, const TextStyleSpec(size: 16, weight: 500));
      expect(t.body, const TextStyleSpec(size: 14, weight: 400));
      expect(t.caption, const TextStyleSpec(size: 12, weight: 400));
    });

    test('默认值本身通过校验', () {
      expect(validateTypography(DesignTypography.standard), isEmpty);
    });

    test('字号阶梯必须逐级递减', () {
      final problems = validateTypography(
        const DesignTypography(body: TextStyleSpec(size: 30, weight: 400)),
      );
      expect(problems.join(), contains('字号必须逐级递减'));
    });

    test('字重必须是 100~900 的百位整数', () {
      for (final w in [0, 99, 450, 1000]) {
        final problems = validateTypography(
          DesignTypography(body: TextStyleSpec(size: 14, weight: w)),
        );
        expect(problems.join(), contains('字重'), reason: '字重 $w 应被拒');
      }
    });

    test('非正数字号被拒', () {
      final problems = validateTypography(
        const DesignTypography(caption: TextStyleSpec(size: 0, weight: 400)),
      );
      expect(problems.join(), contains('字号必须是正数'));
    });

    test('font.scale 夹进 0.8~1.5，越界会被告警但不算致命', () {
      expect(
        const DesignTypography(scale: 3).effectiveScale,
        DesignTypography.maxScale,
      );
      expect(
        const DesignTypography(scale: 0.1).effectiveScale,
        DesignTypography.minScale,
      );
      expect(const DesignTypography(scale: 1.25).effectiveScale, 1.25);

      final problems = validateTypography(const DesignTypography(scale: 3));
      expect(problems.join(), contains('超出规范区间'));
    });

    test('空字符串字体族被拒', () {
      final problems = validateTypography(const DesignTypography(family: '  '));
      expect(problems.join(), contains('font.family'));
    });
  });

  group('validateTheme', () {
    test('四套内置主题的尺度与字体都合法', () {
      for (final theme in AppTheme.builtIns) {
        expect(validateTheme(theme), isEmpty, reason: '${theme.id} 有问题');
      }
    });

    test('内置主题用的是规范默认值', () {
      for (final theme in AppTheme.builtIns) {
        expect(theme.scale.unit, DesignScale.standard.unit);
        expect(theme.typography.body, DesignTypography.standard.body);
        expect(theme.typography.fallback, DesignTypography.defaultFallback);
      }
    });
  });
}
