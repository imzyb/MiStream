import 'package:flutter/material.dart';

/// 应用根 widget：装配主题、路由与全局 overlay。
///
/// M0 阶段只渲染一个空窗口。路由（go_router）在 M5 接入、主题令牌
/// （theme_engine）在 M9 接入 —— 在只有一个实现之前先搭抽象层，搭出来的
/// 形状基本都是猜的，所以这里刻意留白。
class MiStreamApp extends StatelessWidget {
  /// 构造应用根 widget。
  const MiStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiStream',
      debugShowCheckedModeBanner: false,
      // 默认深色：这是一个长时间看视频的应用（docs/09-UI规范.md §1）。
      // 底色取 color.background 令牌，M9 起改由 theme_engine 下发。
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
      ),
      home: const Scaffold(),
    );
  }
}
