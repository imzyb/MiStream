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
    /// 四套主题 × 全部文本前景/背景组合，逐一断言 4.5:1。
    ///
    /// 交叉对（onBackground 落在 surface 上、onSurface 落在 background 上）
    /// 不是凑数：卡片嵌在页面里、页面文字也常被搬到卡片上，实际都会出现。
    test('每对文本前景/背景组合达 WCAG AA 4.5:1', () {
      for (final theme in AppTheme.builtIns) {
        final t = theme.tokens;
        final fails = ContrastChecker.checkPairs([
          ('onBackground/background', t.onBackground, t.background),
          ('onSurface/surface', t.onSurface, t.surface),
          ('onBackground/surface', t.onBackground, t.surface),
          ('onSurface/background', t.onSurface, t.background),
          ('primary/background', t.primary, t.background),
          ('primary/surface', t.primary, t.surface),
        ]);
        expect(
          fails,
          isEmpty,
          reason: '${theme.id} 有文本组合未达 AA 4.5:1: $fails',
        );
      }
    });

    /// WCAG 1.4.11：识别组件所必需的视觉信息（输入框轮廓、按钮边框、
    /// 选中态描边）需 3:1。outlineStrong 就是为此存在的令牌。
    test('outlineStrong 达 WCAG 1.4.11 非文本 3:1', () {
      for (final theme in AppTheme.builtIns) {
        final t = theme.tokens;
        final fails = ContrastChecker.checkPairs(
          [
            ('outlineStrong/background', t.outlineStrong, t.background),
            ('outlineStrong/surface', t.outlineStrong, t.surface),
          ],
          largeText: true,
        );
        expect(
          fails,
          isEmpty,
          reason: '${theme.id} 的 outlineStrong 未达 3:1: $fails',
        );
      }
    });

    /// 这条是给上面两条「兜底」的：如果有人往 DesignTokens 加了新前景色
    /// 却忘了在测试里登记，上面两条仍然全绿。这里把令牌表盘一遍，确保
    /// toMap 里出现的每个前景都进了断言。
    test('前景令牌全部被对比度测试覆盖', () {
      const covered = {
        'onBackground',
        'onSurface',
        'primary',
        'outlineStrong',
      };
      const all = {'onBackground', 'onSurface', 'primary', 'outlineStrong'};
      expect(covered, all);
      for (final theme in AppTheme.builtIns) {
        for (final fg in covered) {
          expect(
            theme.tokens.toMap(),
            contains(fg),
            reason: '${theme.id} 缺少令牌 $fg',
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
      final m = AppTheme.light.tokens.toMap();
      expect(
        m.keys,
        unorderedEquals(<String>{
          'primary',
          'background',
          'surface',
          'onBackground',
          'onSurface',
          'outline',
          'outlineStrong',
        }),
      );
      expect(m['outlineStrong'], isNot(m['outline']));
    });
  });
}
