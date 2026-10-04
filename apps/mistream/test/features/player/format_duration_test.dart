import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/features/player/widgets/player_control_bar.dart';

void main() {
  group('formatDuration', () {
    test('小于一小时显示 M:SS', () {
      expect(formatDuration(const Duration(seconds: 65)), '1:05');
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
    });

    test('超过一小时显示 H:MM:SS', () {
      expect(formatDuration(const Duration(seconds: 3661)), '1:01:01');
      expect(formatDuration(const Duration(minutes: 75)), '1:15:00');
    });

    test('负值按零处理', () {
      expect(formatDuration(const Duration(seconds: -5)), '0:00');
    });
  });
}
