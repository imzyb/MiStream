import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/app/app.dart';

void main() {
  // ROADMAP M0 的交付物是「能在 Windows 上运行出一个空窗口」。把它写成测试，
  // 是为了让后面往 MiStreamApp 里加路由和主题时，别把窗口本身搞崩了还没人发现。
  testWidgets('根 widget 能渲染出空窗口骨架', (tester) async {
    await tester.pumpWidget(const MiStreamApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
