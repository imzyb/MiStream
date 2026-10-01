/// 应用路由表。
library;

import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:live/live.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mistream/application/app_assembly.dart' show AppAssembly;
import 'package:mistream/application/resume_policy.dart';
import 'package:mistream/features/common/common.dart'
    show BreakpointContext, BreakpointType, ErrorView;
import 'package:mistream/features/detail/detail_page.dart';
import 'package:mistream/features/download/download_page.dart';
import 'package:mistream/features/home/home_page.dart';
import 'package:mistream/features/home/widgets/media_card.dart';
import 'package:mistream/features/library/library_page.dart';
import 'package:mistream/features/live/live_page.dart';
import 'package:mistream/features/live/live_player_page.dart';
import 'package:mistream/features/onboarding/onboarding_page.dart';
import 'package:mistream/features/player/player_controller.dart';
import 'package:mistream/features/player/player_page.dart';
import 'package:mistream/features/search/search_page.dart';
import 'package:mistream/features/settings/settings_page.dart';
import 'package:mistream/features/shell/scaffold_with_nav_bar.dart';
import 'package:mistream/features/sniffer/sniffer_settings_page.dart';
import 'package:player_engine/player_engine.dart';
import 'package:search_engine/search_engine.dart';

/// 全局装配实例。
AppAssembly? _globalRouterAssembly;

/// 获取全局装配实例。
AppAssembly? get globalRouterAssembly => _globalRouterAssembly;

/// 设置全局装配实例。
void setGlobalRouterAssembly(AppAssembly? assembly) {
  _globalRouterAssembly = assembly;
}

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
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return ScaffoldWithNavBar(navigationShell: navigationShell);
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomePage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/live',
            name: 'live',
            builder: (context, state) => const LivePage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/downloads',
            name: 'downloads',
            builder: (context, state) => const DownloadPage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/library',
            name: 'library',
            builder: (context, state) => const LibraryPage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: '/onboarding',
    name: 'onboarding',
    builder: (context, state) => const OnboardingPage(),
  ),
  GoRoute(
    path: '/live-player',
    name: 'live_player',
    builder: (context, state) {
      final extra = state.extra as Map<String, Object?>?;
      final channel = extra?['channel'];
      if (channel is! LiveChannel) {
        // 直播播放页没有「单 URL」形态了：它要按序试多条线路，必须有完整的
        // 频道对象。少传就是路由调用点写错了，明确报出来而不是播一个空地址。
        return const Scaffold(
          body: Center(child: Text('缺少频道信息，无法播放')),
        );
      }
      final channels = extra?['channels'];
      return LivePlayerPage(
        channel: channel,
        // 用户当前可见的频道列表：换台键在**这份**列表上走（所见即所切）。
        // 没传就当单台播放，换台键不生效。
        channels: channels is List<LiveChannel> ? channels : const [],
      );
    },
  ),
  GoRoute(
    path: '/search',
    name: 'search',
    builder: (context, state) => const SearchPage(),
  ),
  GoRoute(
    path: '/sniffer-settings',
    name: 'sniffer_settings',
    builder: (context, state) => const SnifferSettingsPage(),
  ),
  GoRoute(
    path: '/category/:siteId/:typeId',
    name: 'category_detail',
    builder: (context, state) {
      final typeId = state.pathParameters['typeId']!;
      final siteId = int.parse(state.pathParameters['siteId']!);
      final extra = state.extra;
      return _CategoryDetailPage(
        siteId: siteId,
        typeId: typeId,
        title: extra is String ? extra : '分类详情',
      );
    },
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
      String? episodeId;
      String? vodName;
      String? vodPic;
      if (extra is Map<String, Object?>) {
        episodeName = extra['episodeName'] as String?;
        episodeId = extra['episodeId'] as String?;
        vodName = extra['vodName'] as String?;
        vodPic = extra['vodPic'] as String?;
      }

      return PlayerPageWrapper(
        siteId: siteId,
        vodId: vodId,
        flag: flag,
        title: episodeName,
        episodeId: episodeId,
        vodName: vodName,
        vodPic: vodPic,
        assembly: globalRouterAssembly,
      );
    },
  ),
];

/// 播放页包装：负责创建引擎和控制器。
///
/// 由于 `PlayerEngine.initialize()` 是异步的，这里在 `initState` 中初始化，
/// 完成后才展示真正的播放器。
class PlayerPageWrapper extends StatefulWidget {
  const PlayerPageWrapper({
    super.key,
    required this.siteId,
    required this.vodId,
    required this.flag,
    this.title,
    this.episodeId,
    this.vodName,
    this.vodPic,
    this.assembly,
    this.engineFactory,
  });

  final int siteId;
  final String vodId;
  final String flag;
  final String? title;
  final String? episodeId;
  final String? vodName;
  final String? vodPic;

  /// 注入的装配。[assembly] 为空时回退全局装配。
  ///
  /// 这个可选参数是测试缝：续播验收需要可控的仓库与播放用例，而全局装配
  /// 在 widget 测试里起不来（它要真实数据库与子进程）。
  final AppAssembly? assembly;

  /// 注入的引擎构造器；为空时用 [MediaKitEngine]。
  final PlayerEngine Function()? engineFactory;

  @override
  State<PlayerPageWrapper> createState() => _PlayerPageWrapperState();
}

class _PlayerPageWrapperState extends State<PlayerPageWrapper> {
  static const _startupTimeout = Duration(seconds: 20);

  PlayerController? _controller;
  PlayerEngine? _engine;
  mkv.VideoController? _videoController;
  Timer? _startupTimer;
  Timer? _historyTimer;
  Duration? _resumeAt;
  String? _error;
  bool _isFullscreen = false;

  /// 本次播放的剧集序号。
  ///
  /// `initState` 里归一一次，写历史与判断能否续播都用它——不要在各处重复解析
  /// `widget.episodeId`，那正是两处约定漂移的起点（见 [EpisodeIndex]）。
  late final EpisodeIndex _episodeIndex;

  /// 当前可用的装配：优先注入的，其次全局。
  AppAssembly? get _assembly => widget.assembly ?? globalRouterAssembly;

  @override
  void initState() {
    super.initState();
    // `null`、空串、脏值一律按第一集算。
    _episodeIndex = EpisodeIndex.parse(widget.episodeId);
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final engine = widget.engineFactory?.call() ?? MediaKitEngine();
      _engine = engine;
      final initResult = await engine.initialize(const PlayerConfig());
      if (initResult.isErr) {
        if (mounted) {
          setState(() => _error = initResult.errorOrNull!.message);
        }
        return;
      }

      // 获取真实播放地址
      final assembly = _assembly;
      if (assembly == null) {
        if (mounted) {
          setState(() => _error = '应用未初始化');
        }
        return;
      }

      final playResult = await assembly.playUseCase.getPlayableSource(
        siteId: widget.siteId,
        vodId: widget.vodId,
        flag: widget.flag,
        // 空串与脏值由 `EpisodeIndex` 归一，这里不必预判。
        episodeId: widget.episodeId,
      );

      if (playResult.isErr) {
        if (mounted) {
          setState(() => _error = playResult.errorOrNull!.message);
        }
        return;
      }

      // VideoController 必须在 open 之前创建，否则 mpv 不会挂载视频输出，
      // 画面永远是黑的（media_kit 用 isVideoControllerAttached 决定 vo）。
      //
      // 只有真实 MediaKitEngine 才需要它；测试注入的假引擎没有 mpv 实例，
      // 此时跳过（对应 widget 测试只关心状态流转，不看画面）。
      final videoController = engine is MediaKitEngine
          ? mkv.VideoController(engine.player)
          : null;

      final mediaSource = playResult.valueOrNull!.mediaSource;
      final openResult = await engine.open(mediaSource);
      if (openResult.isErr) {
        if (mounted) {
          setState(() => _error = '打开媒体失败: ${openResult.errorOrNull!.message}');
        }
        return;
      }

      final controller = PlayerController(engine: engine)..attach();
      controller.addListener(_checkStartupEvidence);

      if (mounted) {
        setState(() {
          _videoController = videoController;
          _controller = controller;
        });
        _armStartupWatchdog(
          controller: controller,
          playResult: playResult.valueOrNull!,
        );
        unawaited(_prepareResumeAndRecord(controller, playResult.valueOrNull!));
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _historyTimer?.cancel();
    _flushProgress();
    _controller?.removeListener(_checkStartupEvidence);
    _controller?.removeListener(_maybeResume);
    _controller?.dispose();
    // 引擎持有 libmpv 实例，必须显式释放，否则离开播放页后 mpv 还在后台解码。
    final engine = _engine;
    if (engine != null) unawaited(engine.dispose());
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  /// 读取历史进度准备续播，并启动周期进度落库。
  ///
  /// 是否续播、续到哪由 [ResumePolicy] 决定（位置不足 5s 或离结尾不足 30s
  /// 都不续播），这里只负责读库、把结果挂上监听。
  Future<void> _prepareResumeAndRecord(
    PlayerController controller,
    PlayResult playResult,
  ) async {
    final assembly = _assembly;
    if (assembly == null || playResult.mediaSource.isLive) return;

    try {
      final history = await assembly.repositories.histories.byVod(
        widget.siteId,
        widget.vodId,
      );
      if (!mounted || controller != _controller) return;
      // 历史按 `(siteId, vodId)` 唯一，整部片只有一条记录。切集之后那条记录里的
      // 进度属于**上一集**，拿它来 seek 会让新一集从中间开始播。集号对不上就
      // 当作没有历史——只是不续播，下面的周期落库照常启动。
      final resumeFrom =
          history == null ||
              EpisodeIndex.of(history.episodeIndex) != _episodeIndex
          ? null
          : ResumePoint(
              position: Duration(milliseconds: history.positionMs),
              duration: Duration(milliseconds: history.durationMs),
            );
      final target = ResumePolicy.resolve(resumeFrom);
      if (target != null) {
        _resumeAt = target;
        controller.addListener(_maybeResume);
      }
    } on Object {
      // 历史读取失败不影响正常起播。
    }

    _historyTimer?.cancel();
    _historyTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _flushProgress(),
    );
  }

  /// 首个播放证据出现且位置仍接近开头时，一次性 seek 到续播点。
  void _maybeResume() {
    final controller = _controller;
    if (controller == null) return;
    if (!ResumePolicy.shouldSeekAfterStart(
      pending: _resumeAt,
      hasPlaybackEvidence: controller.hasPlaybackEvidence,
      currentPosition: controller.position,
    )) {
      return;
    }
    final resumeAt = _resumeAt!;
    _resumeAt = null;
    controller.removeListener(_maybeResume);
    unawaited(controller.seekTo(resumeAt));
  }

  /// 把当前播放进度写入历史（周期 + 退出时各一次）。
  ///
  /// 集号必须一起写：历史按 `(siteId, vodId)` 唯一，整部片只留一条记录，
  /// 不记集号的话「继续播放」就分不清进度属于哪一集（见
  /// [_prepareResumeAndRecord] 里的续播判断）。
  void _flushProgress() {
    final controller = _controller;
    final assembly = _assembly;
    if (controller == null || assembly == null) return;
    final positionMs = controller.position.inMilliseconds;
    final durationMs = controller.duration.inMilliseconds;
    if (durationMs <= 0) return;
    unawaited(
      assembly.repositories.histories.upsert(
        siteId: widget.siteId,
        vodId: widget.vodId,
        vodName: widget.vodName ?? widget.title ?? '未知影片',
        vodPic: widget.vodPic,
        flag: widget.flag,
        episodeIndex: _episodeIndex.value,
        episodeName: widget.title,
        positionMs: positionMs,
        durationMs: durationMs,
      ),
    );
  }

  void _armStartupWatchdog({
    required PlayerController controller,
    required PlayResult playResult,
  }) {
    final source = playResult.mediaSource;
    if (source.isLive || controller.hasPlaybackEvidence) return;
    _startupTimer = Timer(_startupTimeout, () {
      if (!mounted || controller.hasPlaybackEvidence) return;
      controller.reportStartupTimeout(
        source: source.uri,
        diagnostics: {
          'siteId': widget.siteId,
          'vodId': widget.vodId,
          'flag': widget.flag,
          // 实际播出的集号（权威值来自播放编排，不是入参原样回显）。
          'episodeIndex': playResult.episodeIndex.value,
          'url': source.uri.toString(),
          'viaSniffing': playResult.viaSniffing,
          'state': controller.state.name,
          'durationMs': controller.duration.inMilliseconds,
          'positionMs': controller.position.inMilliseconds,
        },
      );
    });
  }

  void _checkStartupEvidence() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.hasPlaybackEvidence || controller.fatalError != null) {
      _startupTimer?.cancel();
      _startupTimer = null;
    }
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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
    final videoController = _videoController;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 注入假引擎（单元测试）时没有 mpv 实例，用黑底占位代替视频区，
    // 这样状态流转仍可断言，且不依赖真实内核。
    if (videoController == null && widget.engineFactory == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PlayerPage(
      controller: controller,
      videoArea: videoController == null
          ? const ColoredBox(color: Colors.black)
          : ColoredBox(
              color: Colors.black,
              child: mkv.Video(
                controller: videoController,
                controls: null,
              ),
            ),
      title: widget.title,
      onToggleFullscreen: _toggleFullscreen,
    );
  }
}

/// 分类详情页。
class _CategoryDetailPage extends StatefulWidget {
  const _CategoryDetailPage({
    required this.siteId,
    required this.typeId,
    required this.title,
  });

  final int siteId;
  final String typeId;
  final String title;

  @override
  State<_CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<_CategoryDetailPage> {
  bool _loading = true;
  String? _error;
  List<HomeItem> _items = [];
  int _page = 1;
  int _pageCount = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    final assembly = globalRouterAssembly;
    if (assembly == null) return;

    setState(() => _loading = true);

    final result = await assembly.homeUseCase.getCategoryDetail(
      typeId: widget.typeId,
      siteId: widget.siteId,
    );

    result.fold(
      (ok) {
        if (mounted) {
          setState(() {
            _items = ok.items;
            _page = ok.page;
            _pageCount = ok.pageCount;
            _loading = false;
          });
        }
      },
      (err) {
        if (mounted) {
          setState(() {
            _error = err.message;
            _loading = false;
          });
        }
      },
    );
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _pageCount) return;

    final assembly = globalRouterAssembly;
    if (assembly == null) return;

    setState(() => _loading = true);

    final result = await assembly.homeUseCase.getCategoryDetail(
      typeId: widget.typeId,
      page: _page + 1,
      siteId: widget.siteId,
    );

    result.fold(
      (ok) {
        if (mounted) {
          setState(() {
            _items.addAll(ok.items);
            _page = ok.page;
            _pageCount = ok.pageCount;
            _loading = false;
          });
        }
      },
      (err) {
        if (mounted) {
          setState(() => _loading = false);
        }
      },
    );
  }

  /// 网格列数随断点变化（对应 ResponsiveGridPresets.mediaCards）。
  int get _gridColumns => switch (context.breakpoint) {
    BreakpointType.xs => 2,
    BreakpointType.sm => 3,
    BreakpointType.md => 4,
    BreakpointType.lg => 5,
    BreakpointType.xl => 6,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
          ? ErrorView(message: _error!, onRetry: _loadData)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridColumns,
                  childAspectRatio: 0.6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount:
                    _items.length + (_loading && _page < _pageCount ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _items.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final item = _items[index];
                  return MediaCard(
                    title: item.vodName,
                    coverUrl: item.vodPic,
                    remarks: item.vodRemarks,
                    onTap: () => context.pushNamed(
                      'detail',
                      pathParameters: {
                        'siteId': '${widget.siteId}',
                        'vodId': item.vodId,
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
