import 'package:test/test.dart';
import 'package:theme_engine/theme_engine.dart';

void main() {
  group('AppThemeChoice', () {
    test('枚举顺序即持久化值，与旧的 ThemeMode.index 对齐', () {
      // 这条是兼容性契约，不是实现细节：库里 `theme_mode` 存的是数字，早期
      // 版本存的是 Flutter ThemeMode 的 index（0=system/1=light/2=dark）。
      // 老用户升级后必须仍落在原来的外观上，所以前三个的顺序不能动，OLED
      // 只能追加在末尾。
      expect(AppThemeChoice.system.index, 0);
      expect(AppThemeChoice.light.index, 1);
      expect(AppThemeChoice.dark.index, 2);
      expect(AppThemeChoice.oled.index, 3);
    });

    test('默认外观是深色', () {
      expect(AppThemeChoice.defaultChoice, AppThemeChoice.dark);
    });

    test('fromIndex 越界回退默认而不是抛', () {
      expect(AppThemeChoice.fromIndex(-1), AppThemeChoice.dark);
      expect(AppThemeChoice.fromIndex(99), AppThemeChoice.dark);
      expect(AppThemeChoice.fromIndex(0), AppThemeChoice.system);
      expect(AppThemeChoice.fromIndex(3), AppThemeChoice.oled);
    });

    test('只有 dark 与 oled 需要强制走深色', () {
      expect(AppThemeChoice.dark.forceDark, isTrue);
      expect(AppThemeChoice.oled.forceDark, isTrue);
      expect(AppThemeChoice.light.forceDark, isFalse);
      expect(AppThemeChoice.system.forceDark, isFalse);
    });

    test('四种选择都有标题与副标题', () {
      for (final c in AppThemeChoice.values) {
        expect(c.label, isNotEmpty);
        expect(c.description, isNotEmpty);
        expect(c.description, isNot(c.label));
      }
    });
  });

  group('resolveTheme', () {
    test('system 随系统明暗切换', () {
      expect(
        resolveTheme(AppThemeChoice.system, platformIsDark: false),
        AppTheme.light,
      );
      expect(
        resolveTheme(AppThemeChoice.system, platformIsDark: true),
        AppTheme.dark,
      );
    });

    test('light / dark / oled 无视系统明暗', () {
      for (final dark in [false, true]) {
        expect(
          resolveTheme(AppThemeChoice.light, platformIsDark: dark),
          AppTheme.light,
        );
        expect(
          resolveTheme(AppThemeChoice.dark, platformIsDark: dark),
          AppTheme.dark,
        );
        expect(
          resolveTheme(AppThemeChoice.oled, platformIsDark: dark),
          AppTheme.oled,
        );
      }
    });

    /// MaterialApp 要同时拿到明暗两套主题。分别以 false / true 调一次就够，
    /// 不必让调用方再 branch——选 oled 时两次都是 oled，配 ThemeMode.dark 用。
    test('明暗各解析一次即得 MaterialApp 的两套主题', () {
      AppThemePair pair(AppThemeChoice c) => (
        light: resolveTheme(c, platformIsDark: false),
        dark: resolveTheme(c, platformIsDark: true),
      );

      expect(pair(AppThemeChoice.system), (
        light: AppTheme.light,
        dark: AppTheme.dark,
      ));
      expect(pair(AppThemeChoice.light), (
        light: AppTheme.light,
        dark: AppTheme.light,
      ));
      expect(pair(AppThemeChoice.dark), (
        light: AppTheme.dark,
        dark: AppTheme.dark,
      ));
      expect(pair(AppThemeChoice.oled), (
        light: AppTheme.oled,
        dark: AppTheme.oled,
      ));
    });
  });
}

typedef AppThemePair = ({AppTheme light, AppTheme dark});
