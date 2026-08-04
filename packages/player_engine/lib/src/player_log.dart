/// 播放内核透出的日志。
library;

import 'package:meta/meta.dart';

/// 播放器日志级别。
///
/// 与 `core_logging` 的 `LogLevel` 取值一一对应，但**不复用它**：为了一个六
/// 项枚举让 `player_engine` 依赖整个日志包（连带 `dart:io` 的落盘实现），耦
/// 合的代价大于重复的代价。映射由 app 层在把 [PlayerLog] 转给 `Logger` 时
/// 一次性完成。
enum PlayerLogLevel {
  /// 最细粒度，mpv 的 `trace`。
  trace,

  /// 调试信息，mpv 的 `debug` / `v`。
  debug,

  /// 一般信息。
  info,

  /// 警告，mpv 的 `warn`。
  warn,

  /// 错误。
  error,

  /// 致命错误，mpv 的 `fatal`。
  fatal;

  /// 按 mpv 的级别名反查。
  ///
  /// mpv 的 `v` 与 `debug`、`error` 与 `fatal` 在不同版本里名称略有出入，
  /// 认不出的一律当 [info]——日志级别猜错只影响过滤，丢掉一条日志才是损失。
  static PlayerLogLevel fromMpvLevel(String level) => switch (level) {
    'trace' => PlayerLogLevel.trace,
    'debug' || 'v' => PlayerLogLevel.debug,
    'info' => PlayerLogLevel.info,
    'warn' => PlayerLogLevel.warn,
    'error' => PlayerLogLevel.error,
    'fatal' => PlayerLogLevel.fatal,
    _ => PlayerLogLevel.info,
  };
}

/// 播放内核的一条日志。
@immutable
final class PlayerLog {
  /// 构造一条日志。
  const PlayerLog({
    required this.level,
    required this.message,
    this.prefix,
  });

  /// 级别。
  final PlayerLogLevel level;

  /// 内容。
  final String message;

  /// 来源前缀，如 mpv 的 `ffmpeg/video`、`vo/gpu`。
  ///
  /// 保留它是因为定位解码问题时，「哪个子系统在报错」比错误文本本身更快指向
  /// 原因：`ffmpeg/video` 是解码器，`vo/gpu` 是渲染，两者的处理方式完全不同。
  final String? prefix;

  @override
  String toString() =>
      '[${level.name}]${prefix == null ? '' : ' $prefix:'} $message';
}
