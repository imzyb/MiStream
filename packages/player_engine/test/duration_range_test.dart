import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

void main() {
  group('DurationRange', () {
    test('长度是起止之差', () {
      final range = DurationRange(
        const Duration(seconds: 10),
        const Duration(seconds: 25),
      );

      expect(range.length, const Duration(seconds: 15));
      expect(range.isEmpty, isFalse);
    });

    test('起止相同即为空区间', () {
      final range = DurationRange(Duration.zero, Duration.zero);

      expect(range.isEmpty, isTrue);
      expect(range.length, Duration.zero);
    });

    test('contains 含端点', () {
      final range = DurationRange(
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      );

      expect(range.contains(const Duration(seconds: 10)), isTrue);
      expect(range.contains(const Duration(seconds: 15)), isTrue);
      expect(range.contains(const Duration(seconds: 20)), isTrue);
      expect(range.contains(const Duration(seconds: 9)), isFalse);
      expect(range.contains(const Duration(seconds: 21)), isFalse);
    });

    test('起点晚于终点被断言拦下', () {
      expect(
        () => DurationRange(
          const Duration(seconds: 20),
          const Duration(seconds: 10),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('按内容比较', () {
      final a = DurationRange(Duration.zero, const Duration(seconds: 5));
      final b = DurationRange(Duration.zero, const Duration(seconds: 5));
      final c = DurationRange(Duration.zero, const Duration(seconds: 6));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
