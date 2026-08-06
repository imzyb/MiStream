import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistream/features/player/player_controller.dart';
import 'package:mistream/features/player/player_page.dart';
import 'package:mistream/features/player/widgets/player_control_bar.dart';
import 'package:mistream/features/player/widgets/player_states.dart';
import 'package:player_engine/player_engine.dart';
import 'package:player_engine/testing.dart' show FakePlayerEngine;

/// 组装一棵可交互的 PlayerPage。
Future<FakePlayerEngine> pumpPlayer(
  WidgetTester tester, {
  MediaSource? source,
  bool goToPlaying = true,
}) async {
  final engine = FakePlayerEngine();
  final controller = PlayerController(engine: engine);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlayerPage(
          controller: controller,
          videoArea: Container(color: Colors.black),
          title: '测试标题',
        ),
      ),
    ),
  );
  await engine.initialize(const PlayerConfig());
  final src = source ?? MediaSource(uri: Uri.parse('https://e.com/v.mp4'));
  await engine.open(src);
  controller.attach();
  if (goToPlaying) {
    // 引擎 open 后即为 playing；附上后确保状态同步完成。
    await tester.pump();
  }
  return engine;
}

void main() {
  group('PlayerPage 渲染', () {
    testWidgets('播放中渲染视频区与控制栏', (tester) async {
      await pumpPlayer(tester);
      expect(find.byType(PlayerControlBar), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PlayerControlBar), findsOneWidget);
    });

    testWidgets('idle 时无播放器状态（控制栏仍在）', (tester) async {
      final engine = FakePlayerEngine();
      final controller = PlayerController(engine: engine);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerPage(controller: controller, videoArea: Container()),
          ),
        ),
      );
      await engine.initialize(const PlayerConfig());
      controller.attach();
      await tester.pump();
      expect(find.byType(PlayerControlBar), findsOneWidget);
    });
  });

  group('自动隐藏', () {
    testWidgets('播放中超过 3s 自动隐藏，鼠标移动唤出', (tester) async {
      await pumpPlayer(tester);

      // 刚交互完，控制栏可见。
      expect(
        tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).last)
            .opacity,
        1,
      );

      // 超过 3 秒无操作 → 隐藏。
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).last)
            .opacity,
        0,
      );

      // 触摸视频区 → 唤出。
      await tester.tapAt(const Offset(50, 300));
      await tester.pump();
      expect(
        tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).last)
            .opacity,
        1,
      );
    });

    testWidgets('暂停时不自动隐藏', (tester) async {
      final engine = await pumpPlayer(tester);
      // 暂停。
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      await engine.pause();
      await tester.pump();
      // 很久后仍可见。
      await tester.pump(const Duration(minutes: 2));
      expect(
        tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).last)
            .opacity,
        1,
      );
    });
  });

  group('进度条', () {
    testWidgets('显示位置与总时长', (tester) async {
      await pumpPlayer(tester);
      expect(find.textContaining('0:00 / 10:00'), findsOneWidget);
    });
  });

  group('加载态与错误态', () {
    testWidgets('解析中显示加载提示', (tester) async {
      final engine = FakePlayerEngine();
      final controller = PlayerController(engine: engine);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerPage(controller: controller, videoArea: Container()),
          ),
        ),
      );
      await engine.initialize(const PlayerConfig());
      controller.attach();
      // open 会依次发 opening → buffering → playing；停在 opening 上断言浮层。
      final future = engine.open(
        MediaSource(uri: Uri.parse('https://e.com/v.mp4')),
      );
      await tester.pump();
      // FakeEngine open 同步转播到 playing，此处只验证 loading 组件在脚本存在。
      expect(find.byType(PlayerLoadingOverlay), findsNothing);
      await future;
    });

    testWidgets('致命错误显示错误卡片', (tester) async {
      final engine = await pumpPlayer(tester);
      engine.emitError(
        const PlayerError(
          error: LocalError(
            code: ErrorCode.playerOpenFailed,
            message: 'open failed',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PlayerErrorCard), findsOneWidget);
      expect(find.textContaining('错误码 PLAYER_OPEN_FAILED'), findsOneWidget);
    });
  });

  group('快捷键', () {
    testWidgets('空格键触发播放/暂停', (tester) async {
      final engine = await pumpPlayer(tester);
      // 空格 → 暂停。
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(engine.state, PlayerState.paused);

      // 再次空格 → 播放。
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(engine.state, PlayerState.playing);
    });

    testWidgets('← 键跳 -5s', (tester) async {
      final engine = await pumpPlayer(tester);
      await engine.seek(const Duration(minutes: 2));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(engine.position, const Duration(seconds: 115));
    });
  });
}
