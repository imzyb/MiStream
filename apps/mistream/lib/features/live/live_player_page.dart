/// 直播播放页：给定 URL 直接起播（不经过 VOD 解析链路）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mistream/features/player/player_controller.dart';
import 'package:mistream/features/player/player_page.dart';
import 'package:player_engine/player_engine.dart';

/// 直播播放页。
///
/// 与点播播放页的差别：不查 Spider API，直接把 [url] 作为直播流打开。
class LivePlayerPage extends StatefulWidget {
  /// 构造直播播放页。
  const LivePlayerPage({
    super.key,
    required this.url,
    this.title,
  });

  /// 直播流地址。
  final String url;

  /// 频道名（显示用）。
  final String? title;

  @override
  State<LivePlayerPage> createState() => _LivePlayerPageState();
}

class _LivePlayerPageState extends State<LivePlayerPage> {
  PlayerController? _controller;
  MediaKitEngine? _engine;
  mkv.VideoController? _videoController;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final engine = MediaKitEngine();
      _engine = engine;
      final initResult = await engine.initialize(const PlayerConfig());
      if (initResult.isErr) {
        if (mounted) {
          setState(() => _error = initResult.errorOrNull!.message);
        }
        return;
      }

      // 直播也必须在 open 前挂上 VideoController，否则画面是黑的。
      final videoController = mkv.VideoController(engine.player);

      final openResult = await engine.open(
        MediaSource(uri: Uri.parse(widget.url), isLive: true),
      );
      if (openResult.isErr) {
        if (mounted) {
          setState(() => _error = openResult.errorOrNull!.message);
        }
        return;
      }

      final controller = PlayerController(engine: engine)..attach();
      if (mounted) {
        setState(() {
          _videoController = videoController;
          _controller = controller;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
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
      title: widget.title,
    );
  }
}
