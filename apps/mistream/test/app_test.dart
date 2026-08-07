import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/app/app.dart';

void main() {
  testWidgets('应用启动显示首页', (tester) async {
    await tester.pumpWidget(const MiStreamApp());
    await tester.pumpAndSettle();

    expect(find.text('MiStream'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
  });

  testWidgets('首页导航到搜索页', (tester) async {
    await tester.pumpWidget(const MiStreamApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('输入关键词开始搜索'), findsOneWidget);
  });
}
