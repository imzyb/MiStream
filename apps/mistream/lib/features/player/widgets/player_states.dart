/// 播放器加载 / 错误两个状态浮层。
library;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:player_engine/player_engine.dart';

/// 加载提示。
///
/// `docs/09-UI规范.md` §5.5 要求「加载态明确显示当前阶段与已耗时」，`docs/04`
/// §10 要求区分「解析中」「连接中」「缓冲中」。这里从 [PlayerState] 区分：
///
/// - [PlayerState.opening] → 解析中
/// - [PlayerState.buffering] → 缓冲中
///
/// 「连接中」是 `opening` 的内部一段，无独立状态，合并进解析中展示。骨架期先
/// 给到这一步，等嗅探/解析编排就位再拆出真正多段步骤。
class PlayerLoadingOverlay extends StatelessWidget {
  /// 构造加载提示。
  const PlayerLoadingOverlay({
    super.key,
    required this.state,
    required this.elapsed,
    required this.title,
  });

  /// 触发加载提示的播放状态。
  final PlayerState state;

  /// 当前阶段已耗时。
  final Duration elapsed;

  /// 正在尝试的媒体标题。
  final String? title;

  String get _label => switch (state) {
    PlayerState.opening => '解析中',
    PlayerState.buffering => '缓冲中',
    _ => '加载中',
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 12),
          Text(
            '$_label…',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          if (title != null) ...[
            const SizedBox(height: 4),
            Text(
              title!,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          if (elapsed.inSeconds > 3)
            Text(
              // 超过 3 秒追加已耗时（docs/09 §7：加载超过 3s 要说明阶段）。
              '已等待 ${elapsed.inSeconds}s',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// 错误卡片（`docs/04` §10、`docs/09` §5.5）。
///
/// 三段式文案（`docs/09` §10）：发生了什么 + 可能原因 + 你能做什么。错误码必须
/// 可见（排障依据），原始堆栈收进诊断复制、不直接展示（`docs/09` §7）。
class PlayerErrorCard extends StatelessWidget {
  /// 构造错误卡片。
  const PlayerErrorCard({
    super.key,
    required this.error,
    required this.title,
    this.onRetry,
    this.onSwitchLine,
    this.onCopyDiagnostics,
  });

  /// 出错媒体。
  final PlayerError error;

  /// 出错媒体的标题。
  final String? title;

  /// 重试当前线路。
  final VoidCallback? onRetry;

  /// 「换个线路」：骨架期未接线数据，允许为 null 时隐藏。
  final VoidCallback? onSwitchLine;

  /// 复制诊断信息。
  final VoidCallback? onCopyDiagnostics;

  String _humanMessage(ErrorCode code) => switch (code) {
    ErrorCode.playerOpenFailed => '打开媒体失败：地址可能失效或仍需鉴权。',
    ErrorCode.playerUnsupportedFormat => '该媒体格式暂不受支持。',
    ErrorCode.playerInitFailed => '播放器初始化失败。',
    ErrorCode.playerLibmpvMissing => '缺少或未能校验播放内核库。',
    ErrorCode.playerNoPlayableSource => '所有线路都无法播放。',
    _ => '播放出错了。',
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          color: Colors.black.withValues(alpha: 0.75),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  _humanMessage(error.code),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '错误码 ${error.code.name}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    if (onSwitchLine != null)
                      OutlinedButton(
                        onPressed: onSwitchLine,
                        child: const Text('换个线路'),
                      ),
                    if (onRetry != null)
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('重试'),
                      ),
                    if (onCopyDiagnostics != null)
                      TextButton(
                        onPressed: onCopyDiagnostics,
                        child: const Text('复制诊断信息'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
