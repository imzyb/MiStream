/// 响应式布局工具：断点定义与自适应组件。
library;

import 'package:flutter/material.dart';

/// 断点常量（符合 Material Design 规范）。
class Breakpoints {
  // 大屏

  const Breakpoints._();
  static const double xs = 600; // 手机
  static const double sm = 900; // 平板
  static const double md = 1200; // 平板横屏 / 小笔记本
  static const double lg = 1800; // 桌面
  static const double xl = 2400;
}

/// 当前断点枚举。
enum BreakpointType { xs, sm, md, lg, xl }

/// 根据宽度判断断点。
BreakpointType getBreakpoint(double width) {
  if (width < Breakpoints.xs) return BreakpointType.xs;
  if (width < Breakpoints.sm) return BreakpointType.sm;
  if (width < Breakpoints.md) return BreakpointType.md;
  if (width < Breakpoints.lg) return BreakpointType.lg;
  return BreakpointType.xl;
}

/// 响应式网格列数配置。
class ResponsiveGridConfig {
  const ResponsiveGridConfig({
    this.xsColumns = 1,
    this.smColumns = 2,
    this.mdColumns = 3,
    this.lgColumns = 4,
    this.xlColumns = 5,
  });
  final int xsColumns;
  final int smColumns;
  final int mdColumns;
  final int lgColumns;
  final int xlColumns;

  int columnsFor(BreakpointType bp) {
    return switch (bp) {
      BreakpointType.xs => xsColumns,
      BreakpointType.sm => smColumns,
      BreakpointType.md => mdColumns,
      BreakpointType.lg => lgColumns,
      BreakpointType.xl => xlColumns,
    };
  }
}

/// 预设网格配置。
class ResponsiveGridPresets {
  static const ResponsiveGridConfig mediaCards = ResponsiveGridConfig(
    xsColumns: 2,
    smColumns: 3,
    mdColumns: 4,
    lgColumns: 5,
    xlColumns: 6,
  );

  static const ResponsiveGridConfig categoryChips = ResponsiveGridConfig(
    xsColumns: 2,
    smColumns: 3,
    mdColumns: 4,
    lgColumns: 5,
    xlColumns: 6,
  );

  static const ResponsiveGridConfig detailEpisodes = ResponsiveGridConfig(
    xsColumns: 3,
    smColumns: 4,
    mdColumns: 5,
    lgColumns: 6,
    xlColumns: 7,
  );

  static const ResponsiveGridConfig libraryList = ResponsiveGridConfig(
    smColumns: 1,
    mdColumns: 1,
    lgColumns: 1,
    xlColumns: 1,
  );
}

/// 响应式布局构建器。
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, BreakpointType breakpoint)
  builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bp = getBreakpoint(constraints.maxWidth);
        return builder(context, bp);
      },
    );
  }
}

/// 响应式网格视图。
class ResponsiveGridView extends StatelessWidget {
  const ResponsiveGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.config = ResponsiveGridPresets.mediaCards,
    this.padding = const EdgeInsets.all(16),
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.childAspectRatio = 0.7,
    this.physics,
    this.shrinkWrap = false,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ResponsiveGridConfig config;
  final EdgeInsetsGeometry padding;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, bp) {
        final columns = config.columnsFor(bp);
        return GridView.builder(
          padding: padding,
          physics: physics,
          shrinkWrap: shrinkWrap,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

/// 响应式 Sliver 网格（用于 CustomScrollView 内）。
class ResponsiveSliverGrid extends StatelessWidget {
  const ResponsiveSliverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.config = ResponsiveGridPresets.mediaCards,
    this.padding = const EdgeInsets.all(16),
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.childAspectRatio = 0.7,
  });

  /// 条目数。
  final int itemCount;

  /// 条目构建器。
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// 列数随断点变化的配置。
  final ResponsiveGridConfig config;

  /// 外边距。
  final EdgeInsetsGeometry padding;

  /// 主轴间距。
  final double mainAxisSpacing;

  /// 交叉轴间距。
  final double crossAxisSpacing;

  /// 单元格宽高比（宽/高）。
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    final columns = config.columnsFor(context.breakpoint);
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          itemBuilder,
          childCount: itemCount,
        ),
      ),
    );
  }
}

/// 响应式水平列表（卡片轮播）。
class ResponsiveHorizontalList extends StatelessWidget {
  const ResponsiveHorizontalList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemWidth = 160,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 12,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double itemWidth;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemWidth / 0.7 + 40, // 估算高度
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(right: index == itemCount - 1 ? 0 : spacing),
          child: SizedBox(width: itemWidth, child: itemBuilder(context, index)),
        ),
      ),
    );
  }
}

/// 响应式侧边栏/主区布局。
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.sidebar,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final Widget body;
  final Widget? sidebar;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, bp) {
        final isDesktop = bp.index >= BreakpointType.md.index;

        if (isDesktop && sidebar != null) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                SizedBox(width: 280, child: sidebar),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
            bottomNavigationBar: bottomNavigationBar,
            floatingActionButton: floatingActionButton,
          );
        }

        return Scaffold(
          appBar: appBar,
          drawer: sidebar != null ? Drawer(child: sidebar) : null,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}

/// 响应式值（根据断点返回不同值）。
class ResponsiveValue<T> {
  const ResponsiveValue({
    this.xs,
    this.sm,
    this.md,
    this.lg,
    this.xl,
  });

  final T? xs;
  final T? sm;
  final T? md;
  final T? lg;
  final T? xl;

  T? resolve(BreakpointType bp) {
    return switch (bp) {
      BreakpointType.xs => xs ?? sm ?? md ?? lg ?? xl,
      BreakpointType.sm => sm ?? xs ?? md ?? lg ?? xl,
      BreakpointType.md => md ?? sm ?? xs ?? lg ?? xl,
      BreakpointType.lg => lg ?? md ?? sm ?? xs ?? xl,
      BreakpointType.xl => xl ?? lg ?? md ?? sm ?? xs,
    };
  }
}

/// 便捷扩展：在 Builder 中直接获取断点类型。
extension BreakpointContext on BuildContext {
  BreakpointType get breakpoint =>
      getBreakpoint(MediaQuery.of(this).size.width);

  bool get isMobile => breakpoint == BreakpointType.xs;
  bool get isTablet => breakpoint == BreakpointType.sm;
  bool get isDesktop => breakpoint.index >= BreakpointType.md.index;
}
