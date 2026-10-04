import 'package:test/test.dart';
import 'package:theme_engine/theme_engine.dart';

void main() {
  group('ContrastChecker', () {
    test('luminance 0 为黑，1 为白', () {
      expect(ContrastChecker.luminance(0xFF000000), closeTo(0, 0.01));
      expect(ContrastChecker.luminance(0xFFFFFFFF), closeTo(1, 0.01));
    });

    test('ratio 黑白 21:1', () {
      expect(ContrastChecker.ratio(0xFF000000, 0xFFFFFFFF), closeTo(21, 0.1));
    });

    test('passesAA 同色不通过', () {
      expect(ContrastChecker.passesAA(0xFF888888, 0xFF888888), isFalse);
    });
  });

  group('AppTheme builtIns', () {
    /// 四套内置主题跑同一份 [checkContrast]——主题包加载用的也是它，所以
    /// 这里过了，主题包的兜底逻辑就不必再单独验一遍矩阵本身。
    test('对比度全部达标（正文 4.5 / UI 组件 3.0）', () {
      for (final theme in AppTheme.builtIns) {
        expect(
          checkContrast(theme.tokens),
          isEmpty,
          reason: '${theme.id} 有组合不达标',
        );
      }
    });

    /// 防止「加了新前景令牌却没进断言矩阵」的假绿：只要 DesignTokens 里多出
    /// 一个没被任何规则用到的色值，这里就红。
    test('每个颜色令牌都进了断言矩阵', () {
      for (final theme in AppTheme.builtIns) {
        final used = <int>{
          for (final r in contrastRules(theme.tokens)) ...[r.fg, r.bg],
        };
        for (final entry in theme.tokens.toMap().entries) {
          if (entry.key == 'outline') continue; // 装饰性，刻意不设下限
          expect(
            used,
            contains(entry.value),
            reason: '${theme.id} 的 ${entry.key} 没进对比度矩阵',
          );
        }
      }
    });

    test('builtInsMap 覆盖四主题', () {
      expect(AppTheme.builtInsMap.length, 4);
      expect(AppTheme.builtInsMap['light'], AppTheme.light);
      expect(AppTheme.builtInsMap['dark'], AppTheme.dark);
      expect(AppTheme.builtInsMap['oled'], AppTheme.oled);
      expect(AppTheme.builtInsMap['system'], AppTheme.system);
      expect(AppTheme.builtInsMap.keys, AppTheme.builtIns.map((t) => t.id));
    });

    test('toMap 序列化全部令牌', () {
      expect(
        AppTheme.light.tokens.toMap().keys,
        unorderedEquals(<String>{
          'primary',
          'onPrimary',
          'primaryText',
          'background',
          'surface',
          'surfaceVariant',
          'onSurface',
          'onSurfaceMuted',
          'outline',
          'outlineStrong',
        }),
      );
    });

    test('明度阶梯方向一致：页面 → 卡片 → 次级面板', () {
      // 三个底的亮度必须单调，否则「卡片浮在页面上」这件事实会被破坏。
      // OLED 三级差极小（0 → 0.003 → 0.007），方向仍然一致。
      for (final theme in AppTheme.builtIns) {
        final t = theme.tokens;
        final bg = ContrastChecker.luminance(t.background);
        final sf = ContrastChecker.luminance(t.surface);
        final sv = ContrastChecker.luminance(t.surfaceVariant);
        if (theme.isDark) {
          expect(bg, lessThan(sf), reason: '${theme.id} 页面应比卡片暗');
          expect(sf, lessThan(sv), reason: '${theme.id} 卡片应比次级面板暗');
        } else {
          expect(sf, greaterThan(bg), reason: '${theme.id} 卡片应比页面亮');
          expect(sv, lessThan(sf), reason: '${theme.id} 次级面板应比卡片暗');
        }
      }
    });
  });
}
