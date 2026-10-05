/// [RecommendRow] 渲染测试。
///
/// 回归 2026-10-05：首页「为你推荐」整行渲染成**空白** —— 标题在，下面一片
/// 留白。根因是这一行原来用裸的横向 `ListView.builder` 装 `MediaCard`：横向
/// ListView 给子项的约束是**宽度无界**，而 `MediaCard` 里的 `PosterImage` 是
/// `AspectRatio(0.7)`，无界宽度下算不出有限尺寸（debug 抛
/// `RenderAspectRatio has unbounded constraints`，release 得到 `Size(inf, inf)`），
/// 第一项占掉无限宽，后面的项永远排不到。
///
/// 所以这里断言的不是「有卡片」，而是**每张卡片的宽度有限且等于 `itemWidth`** ——
/// 只有 `SizedBox(width:)` 兜住宽度，`AspectRatio` 才有解。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/features/home/widgets/media_card.dart';
import 'package:mistream/features/home/widgets/recommend_row.dart';
import 'package:search_engine/search_engine.dart';

HomeItem _item(int i) => HomeItem(
  vodId: '$i',
  vodName: '影片$i',
  vodPic: 'https://img.example/$i.jpg',
);

void main() {
  Future<void> pumpRow(WidgetTester tester, List<HomeItem> items) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // RecommendRow 是 sliver（HomeSection 内部是 SliverToBoxAdapter），
          // 只能放进 slivers 列表。
          body: CustomScrollView(slivers: [RecommendRow(items: items)]),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('推荐行渲染出卡片，且每张宽度有限（回归：整行空白）', (tester) async {
    await pumpRow(tester, [for (var i = 0; i < 5; i++) _item(i)]);

    expect(find.text('为你推荐'), findsOneWidget);
    expect(find.byType(MediaCard), findsWidgets);

    final size = tester.getSize(find.byType(MediaCard).first);
    expect(
      size.width,
      120,
      reason:
          'ResponsiveHorizontalList 会给每项套 SizedBox(width: itemWidth)；宽度无界时 AspectRatio 无解，整行会渲染成空白',
    );
    expect(size.width.isFinite, isTrue);
    expect(size.height.isFinite, isTrue);
    expect(size.height, greaterThan(0));
  });

  testWidgets('推荐行渲染卡片标题，且点击回调带上对应的那一项', (tester) async {
    final tapped = <String>[];
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              RecommendRow(
                items: [_item(0), _item(1)],
                onTap: (item) => tapped.add(item.vodId),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('影片0'), findsOneWidget);
    expect(find.text('影片1'), findsOneWidget);

    await tester.tap(find.text('影片1'));
    expect(tapped, ['1']);
  });
}
