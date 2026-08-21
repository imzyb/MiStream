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
    test('四套内置主题对比度达 WCAG AA', () {
      for (final theme in AppTheme.builtIns) {
        final t = theme.tokens;
        final fails = ContrastChecker.checkPairs([
          ('onBackground/background', t.onBackground, t.background),
          ('onSurface/surface', t.onSurface, t.surface),
          ('primary/background', t.primary, t.background),
        ]);
        expect(
          fails,
          isEmpty,
          reason: '${theme.id} 未通过 AA: $fails',
        );
      }
    });

    test('builtInsMap 覆盖四主题', () {
      expect(AppTheme.builtInsMap.length, 4);
      expect(AppTheme.builtInsMap['light'], AppTheme.light);
      expect(AppTheme.builtInsMap['dark'], AppTheme.dark);
    });
  });
}
