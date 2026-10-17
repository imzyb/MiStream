import 'package:test/test.dart';
import 'package:updater/updater.dart';

void main() {
  group('AppVersion.parse', () {
    test('三段式', () {
      final v = AppVersion.parse('1.2.3');
      expect([v.major, v.minor, v.patch], [1, 2, 3]);
      expect(v.preRelease, isEmpty);
      expect(v.build, isEmpty);
    });

    test('两段式缺省 patch 为 0', () {
      expect(AppVersion.parse('1.2'), AppVersion.parse('1.2.0'));
    });

    test('带构建号：保留但**不参与比较**', () {
      final v = AppVersion.parse('0.1.0+45');
      expect(v.build, '45');
      expect(v, AppVersion.parse('0.1.0'));
      expect(v.compareTo(AppVersion.parse('0.1.0+99')), 0);
    });

    test('带预发布后缀', () {
      final v = AppVersion.parse('1.0.0-beta.2');
      expect(v.preRelease, 'beta.2');
      expect(v.isPreRelease, isTrue);
    });

    test('空串 / 段数不对 / 非数字段都要抛，不许静默成 0.0.0', () {
      expect(() => AppVersion.parse(''), throwsFormatException);
      expect(() => AppVersion.parse('   '), throwsFormatException);
      expect(() => AppVersion.parse('1'), throwsFormatException);
      expect(() => AppVersion.parse('1.2.3.4'), throwsFormatException);
      expect(() => AppVersion.parse('a.b.c'), throwsFormatException);
      expect(() => AppVersion.parse('1.-2.3'), throwsFormatException);
    });

    test('tryParse 失败返回 null', () {
      expect(AppVersion.tryParse('nope'), isNull);
      expect(AppVersion.tryParse('1.0.0'), isNotNull);
    });
  });

  group('比较语义', () {
    test('按 major → minor → patch', () {
      expect(
        AppVersion.parse('2.0.0').isNewerThan(AppVersion.parse('1.9.9')),
        isTrue,
      );
      expect(
        AppVersion.parse('1.10.0').isNewerThan(AppVersion.parse('1.9.0')),
        isTrue,
      );
      expect(
        AppVersion.parse('1.0.10').isNewerThan(AppVersion.parse('1.0.9')),
        isTrue,
      );
    });

    test('正式版 > 预发布版', () {
      expect(
        AppVersion.parse('1.0.0').isNewerThan(AppVersion.parse('1.0.0-beta')),
        isTrue,
      );
      expect(
        AppVersion.parse('1.0.0-beta').isNewerThan(AppVersion.parse('1.0.0')),
        isFalse,
      );
    });

    test('预发布段按 semver：alpha < alpha.1 < beta', () {
      final alpha = AppVersion.parse('1.0.0-alpha');
      final alpha1 = AppVersion.parse('1.0.0-alpha.1');
      final beta = AppVersion.parse('1.0.0-beta');
      expect(alpha1.isNewerThan(alpha), isTrue);
      expect(beta.isNewerThan(alpha1), isTrue);
      expect(alpha.compareTo(alpha), 0);
    });

    test('数字段小于非数字段', () {
      expect(
        AppVersion.parse('1.0.0-1').compareTo(AppVersion.parse('1.0.0-alpha')),
        lessThan(0),
      );
    });

    test('相等与 hashCode 一致（构建号被忽略）', () {
      final a = AppVersion.parse('0.1.0+1');
      final b = AppVersion.parse('0.1.0+2');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString 还原可读形式', () {
      expect(AppVersion.parse('1.2.3-beta.1+7').toString(), '1.2.3-beta.1+7');
    });
  });
}
