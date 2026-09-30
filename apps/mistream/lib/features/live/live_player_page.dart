/// 直播播放页：按序试频道的每条线路，起播后显示当前线路。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:live/live.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mistream/app/app.dart' show AppScope;
import 'package:mistream/features/player/player_controller.dart';
import 'package:mistream/features/player/player_page.dart';
import 'package:player_engine/player_engine.dart';

/// 直播播放页。
///
/// 与点播播放页的差别：不查 Spider API，直接按 [LiveChannel.allUrls] 的顺序
/// 试流 —— 真实直播源里同一频道挂多条地址是常态，第一条不通不代表这个台不能看。
class LivePlayerPage extends StatefulWidget {
  /// 构造直播播放页。
  const LivePlayerPage({super.key, required this.channel});

  /// 目标频道（含主地址与备用地址）。
  final LiveChannel channel;

  @override
  State<LivePlayerPage> createState() => _LivePlayerPageState();
}

class _LivePlayerPageState extends State<LivePlayerPage> {
  PlayerController? _controller;
  MediaKitEngine? _engine;
  mkv.VideoController? _videoController;
  LiveChannelSwitcher? _switcher;
  LiveSwitchResult? _result;
  String? _error;

  /// 本频道的节目单（拉到才有）。
  LiveEpg? _epg;
  EpgFetcher? _epgFetcher;
  bool _epgRequested = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_epgRequested) return;
    _epgRequested = true;
    _epgFetcher = AppScope.of(context).liveEpgFetcher;
    unawaited(_loadEpg());
  }

  /// 拉本频道的节目单。
  ///
  /// 与播放**并行**，不阻塞起播：EPG 是锦上添花，源站不收录这个台、接口挂了、
  /// 配置里根本没给 `epg` 都是常态，任何一种都不该让用户看不了电视。
  Future<void> _loadEpg() async {
    final fetcher = _epgFetcher;
    if (fetcher == null || !fetcher.hasTemplates) return;
    try {
      final epg = await fetcher.loadFor(
        widget.channel.id,
        widget.channel.name,
      );
      if (!mounted || epg == null) return;
      setState(() => _epg = epg);
    } on Object {
      // 见上。
    }
  }

  Future<void> _init() async {
    try {
      final engine = MediaKitEngine();
      _engine = engine;
      final initResult = await engine.initialize(const PlayerConfig());
      if (initResult.isErr) {
        _fail(initResult.errorOrNull!.message);
        return;
      }

      // 直播也必须在 open 前挂上 VideoController，否则画面是黑的。
      final videoController = mkv.VideoController(engine.player);

      final switcher = LiveChannelSwitcher(probe: _probe);
      _switcher = switcher;
      final result = await switcher.switchTo(widget.channel);
      if (!mounted) return;

      switch (result.status) {
        case LiveSwitchStatus.playing:
          final controller = PlayerController(engine: engine)..attach();
          setState(() {
            _videoController = videoController;
            _controller = controller;
            _result = result;
          });
        case LiveSwitchStatus.exhausted:
          setState(() => _result = result);
          _fail('所有线路都试过了，都播不了（共 ${result.lineCount} 条）');
        case LiveSwitchStatus.cancelled:
          // 页面已关或被后续换台作废，什么都不用做。
          break;
      }
    } on Object catch (e) {
      _fail(e.toString());
    }
  }

  /// 试播一条线路：能打开就算通。
  ///
  /// 这是能做到的最好的近似 —— `open` 成功不等于画面已经出来，真正等首帧
  /// 需要播放器的帧回调（本环境跑不了 widget 测试，也就无法覆盖）。所以
  /// 「换台时保留上一路画面直到新流首帧」这条出口标准**尚未实现**：它需要
  /// 双播放器交替 + 首帧回调，属于 UI 层的活，不是这个类能兜住的。
  Future<bool> _probe(String url) async {
    final engine = _engine;
    if (engine == null) return false;
    try {
      final result = await engine.open(
        MediaSource(uri: Uri.parse(url), isLive: true),
      );
      return result.isOk;
    } on Object {
      return false;
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  void dispose() {
    // 作废还在跑的换台循环，否则它会在页面销毁后继续往播放器里塞流。
    _switcher?.cancel();
    _controller?.dispose();
    final engine = _engine;
    if (engine != null) unawaited(engine.dispose());
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
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
    if (controller == null || videoController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PlayerPage(
      controller: controller,
      videoArea: ColoredBox(
        color: Colors.black,
        child: mkv.Video(controller: videoController, controls: null),
      ),
      title: _title(),
    );
  }

  /// 标题带上当前线路与正在播的节目 —— 出口标准要求「UI 显示当前线路」，
  /// 节目单则是 EPG 唯一的用户可见出口。
  String _title() {
    final parts = <String>[widget.channel.name];
    final label = _result?.lineLabel ?? '';
    if (label.isNotEmpty) parts.add(label);
    final program = _epg?.currentProgram;
    if (program != null && program.title.isNotEmpty) {
      parts.add('正在播 ${program.title}');
    }
    return parts.join(' · ');
  }
}
