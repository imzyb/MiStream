import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/app/app.dart';
import 'package:mistream/application/app_assembly.dart';
import 'package:mistream/features/common/common.dart';
import 'package:storage/storage.dart';

/// 构造一个跑在内存库上的装配。
///
/// `AppDatabase.inMemory()` 只应出现在测试里——生产路径唯一的建库处是
/// `main.dart`，用 `AppDatabase.open` 落盘。
AppAssembly _testAssembly() {
  final db = AppDatabase.inMemory();
  return AppAssembly(db, Repositories(db));
}

void main() {
  testWidgets('引导已完成时启动显示首页', (tester) async {
    final assembly = _testAssembly();
    addTearDown(assembly.dispose);

    await tester.pumpWidget(
      MiStreamApp(
        assembly: assembly,
        onboardingDone: true,
        themeMode: ThemeMode.system,
      ),
    );
    await tester.pump();

    // 首页数据来自网络，测试环境里没有可用站点，只断言外壳已就位：
    // 标题、搜索入口、设置入口。
    expect(find.text('MiStream'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    // 设置入口在首页初始处于未选中态，导航栏渲染的是 outline 变体；
    // 选中后才变实心。这里只断言「有设置入口」，接受两种形态任一。
    expect(
      find.byIcon(Icons.settings_outlined).evaluate().isNotEmpty ||
          find.byIcon(Icons.settings).evaluate().isNotEmpty,
      isTrue,
      reason: '首页应显示设置入口（outline 或实心任一）',
    );
  });

  testWidgets('首页导航到搜索页', (tester) async {
    final assembly = _testAssembly();
    addTearDown(assembly.dispose);

    await tester.pumpWidget(
      MiStreamApp(
        assembly: assembly,
        onboardingDone: true,
        themeMode: ThemeMode.system,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('输入关键词开始搜索'), findsOneWidget);
  });

  testWidgets('响应式网格嵌套在 Sliver 中不会使用无限高度', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: ResponsiveGridView(
                itemCount: 1,
                shrinkWrap: true,
                itemBuilder: _testGridItem,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('引导未完成时启动落在引导页', (tester) async {
    final assembly = _testAssembly();
    addTearDown(assembly.dispose);

    await tester.pumpWidget(
      MiStreamApp(
        assembly: assembly,
        onboardingDone: false,
        themeMode: ThemeMode.system,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('欢迎使用 MiStream'), findsOneWidget);
  });

  group('组合根', () {
    // 回归测试：曾经 main / app / 引导页 / 详情页各建各的
    // `AppDatabase.inMemory()`，引导页写下的 onboarding_done 落在一个随即
    // 被丢弃的库里，启动入口又从另一个新库读，永远读回 false —— 应用因此
    // 死锁在引导页。这条钉住「写完能读回」。
    test('同一装配写入引导标记后能读回 true', () async {
      final assembly = _testAssembly();
      addTearDown(assembly.dispose);

      expect(await assembly.configInstaller.isOnboardingDone(), isFalse);

      await assembly.configInstaller.markOnboardingDone();

      expect(await assembly.configInstaller.isOnboardingDone(), isTrue);
    });

    test('标记经由新建的 Repositories 视图同样可见', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);

      await AppAssembly(
        db,
        Repositories(db),
      ).configInstaller.markOnboardingDone();

      // 另起一组仓储、同一个库：模拟「进程内不同位置各自取仓储」。
      final reread = AppAssembly(db, Repositories(db));
      expect(await reread.configInstaller.isOnboardingDone(), isTrue);
    });
  });
}

Widget _testGridItem(BuildContext context, int index) => const SizedBox();
