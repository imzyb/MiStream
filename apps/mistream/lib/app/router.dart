/// 应用路由表。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mistream/features/detail/detail_page.dart';
import 'package:mistream/features/home/home_page.dart';
import 'package:mistream/features/onboarding/onboarding_page.dart';
import 'package:mistream/features/player/player_controller.dart';
import 'package:mistream/features/player/player_page.dart';
import 'package:mistream/features/search/search_page.dart';
import 'package:player_engine/player_engine.dart';
import 'package:search_engine/search_engine.dart';

/// 把「引导是否完成」下发给引导页，让它在完成时翻转标记。
///
/// 取代了早先的可变全局 `kOnboardingDone`——那个全局既无法在测试里隔离，
/// 也不会触发 redirect 重算，导致引导完成后仍被弹回引导页。
class OnboardingScope extends InheritedWidget {
  /// 以 [done] 包裹 [child]。
  const OnboardingScope({
    required this.done,
    required super.child,
    super.key,
  });

  /// 引导完成标记。翻转时 [GoRouter] 会重新求值 redirect。
  final ValueNotifier<bool> done;

  /// 取最近的 [OnboardingScope]。
  ///
  /// 同 `AppScope.of`：notifier 实例本身不变（变的是它的 value，由 GoRouter
  /// 直接监听），故不注册 build 依赖。
  static ValueNotifier<bool> of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<OnboardingScope>();
    assert(scope != null, '找不到 OnboardingScope，检查 MiStreamApp 是否在树上');
    return scope!.done;
  }

  @override
  bool updateShouldNotify(OnboardingScope oldWidget) => done != oldWidget.done;
}

/// 持有 [GoRouter] 及其 `refreshListenable`。
///
/// `GoRouter` 自身不释放传入的 listenable，这里统一管生命周期。
class AppRouter {
  /// 用 [_onboardingDone] 作为重定向依据构造路由。
  AppRouter({required this._onboardingDone}) {
    router = GoRouter(
      navigatorKey: _rootKey,
      initialLocation: _onboardingDone.value ? '/' : '/onboarding',
      refreshListenable: _onboardingDone,
      redirect: (context, state) {
        final goingToOnboarding = state.matchedLocation == '/onboarding';
        final done = _onboardingDone.value;
        if (!done && !goingToOnboarding) return '/onboarding';
        if (done && goingToOnboarding) return '/';
        return null;
      },
      routes: _routes,
    );
  }

  final ValueNotifier<bool> _onboardingDone;
  final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

  /// 路由实例。
  late final GoRouter router;

  /// 释放路由资源。
  void dispose() => router.dispose();
}

List<RouteBase> get _routes => [
  GoRoute(
    path: '/',
    name: 'home',
    builder: (context, state) => const HomePage(),
  ),
  GoRoute(
    path: '/onboarding',
    name: 'onboarding',
    builder: (context, state) => const OnboardingPage(),
  ),
  GoRoute(
    path: '/search',
    name: 'search',
    builder: (context, state) => const SearchPage(),
  ),
  GoRoute(
    path: '/detail/:siteId/:vodId',
    name: 'detail',
    builder: (context, state) {
      final siteId = int.parse(state.pathParameters['siteId']!);
      final vodId = state.pathParameters['vodId']!;
      final extra = state.extra;
      return DetailPage(
        siteId: siteId,
        vodId: vodId,
        item: extra is SearchItem ? extra : null,
      );
    },
  ),
  GoRoute(
    path: '/player/:siteId/:vodId/:flag',
    name: 'player',
    builder: (context, state) {
      final siteId = int.parse(state.pathParameters['siteId']!);
      final vodId = state.pathParameters['vodId']!;
      final flag = state.pathParameters['flag']!;
      final extra = state.extra;

      String? episodeName;
      if (extra is Map<String, Object?>) {
        episodeName = extra['episodeName'] as String?;
      }

      return _PlayerPageWrapper(
        siteId: siteId,
        vodId: vodId,
        flag: flag,
        title: episodeName,
      );
    },
  ),
];

/// 播放页包装：负责创建引擎和控制器。
///
/// 由于 `PlayerEngine.initialize()` 是异步的，这里在 `initState` 中初始化，
/// 完成后才展示真正的播放器。
class _PlayerPageWrapper extends StatefulWidget {
  const _PlayerPageWrapper({
    required this.siteId,
    required this.vodId,
    required this.flag,
    this.title,
  });

  final int siteId;
  final String vodId;
  final String flag;
  final String? title;

  @override
  State<_PlayerPageWrapper> createState() => _PlayerPageWrapperState();
}

class _PlayerPageWrapperState extends State<_PlayerPageWrapper> {
  PlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final engine = MediaKitEngine();
      final initResult = await engine.initialize(const PlayerConfig());
      if (initResult.isErr) {
        if (mounted) {
          setState(() => _error = initResult.errorOrNull!.message);
        }
        return;
      }

      // TODO(M5): 接 PlayCoordinator 取真实播放地址，见 ROADMAP M5「播放页
      // 接入编排层」。在此之前播放页只展示控制栏骨架，不加载媒体。
      final controller = PlayerController(engine: engine);

      if (mounted) {
        setState(() => _controller = controller);
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(error, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => context.pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PlayerPage(
      controller: controller,
      videoArea: const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('播放区域', style: TextStyle(color: Colors.grey)),
        ),
      ),
      title: widget.title,
    );
  }
}
