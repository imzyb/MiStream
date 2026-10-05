/// 首页「为你推荐」轮播行。
library;

import 'package:flutter/material.dart';

import 'package:mistream/features/common/common.dart'
    show ResponsiveHorizontalList;
import 'package:mistream/features/home/widgets/home_section.dart';
import 'package:mistream/features/home/widgets/media_card.dart';
import 'package:search_engine/search_engine.dart';

/// 首页「为你推荐」轮播行。
///
/// **这是一个 sliver**（[HomeSection] 内部是 `SliverToBoxAdapter`），只能放进
/// `CustomScrollView` 的 `slivers` 列表里。
///
/// 为什么必须用 [ResponsiveHorizontalList] 而不是裸的横向 `ListView.builder`：
/// 横向 ListView 给子项的约束是**宽度无界**，而 [MediaCard] 里的 `PosterImage`
/// 是 `AspectRatio(0.7)` —— 无界宽度下它算不出有限尺寸（debug 抛
/// `RenderAspectRatio has unbounded constraints`，release 得到 `Size(inf, inf)`），
/// 第一项就占掉无限宽，后面的项永远排不到，整行**看起来是空的**：标题在、
/// 下面一片留白。
///
/// 实测 2026-10-05：首页「为你推荐」空了一整行，而同一屏的分类行
/// （[ResponsiveGridView]，宽度是紧的）正常。[ResponsiveHorizontalList] 会给
/// 每项套 `SizedBox(width: itemWidth)` —— 首页的分类详情那几行用的也是它。
///
/// 抽成独立组件是为了**能直接写 widget 测试**把「每张卡片宽度有限且等于
/// [itemWidth]」钉住：`HomePage` 的装配依赖太重，端到端测不到这一行。
class RecommendRow extends StatelessWidget {
  /// 构造推荐行。
  const RecommendRow({
    super.key,
    required this.items,
    this.onTap,
    this.itemWidth = 120,
    this.spacing = 8,
  });

  /// 推荐项。
  final List<HomeItem> items;

  /// 点击某一项。
  final void Function(HomeItem item)? onTap;

  /// 单张卡片宽度。
  final double itemWidth;

  /// 卡片间距。
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    return HomeSection(
      title: '为你推荐',
      child: ResponsiveHorizontalList(
        itemCount: items.length,
        itemWidth: itemWidth,
        spacing: spacing,
        itemBuilder: (context, index) {
          final item = items[index];
          return MediaCard(
            title: item.vodName,
            coverUrl: item.vodPic,
            remarks: item.vodRemarks,
            onTap: tap == null ? null : () => tap(item),
          );
        },
      ),
    );
  }
}
