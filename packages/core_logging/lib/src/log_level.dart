/// 日志级别。
library;

/// 日志级别，按严重程度递增。
///
/// 默认阈值是 [info]。用户可在设置里调到 [debug]，UI 需同时提示会影响性能
/// （`docs/10-开发规范.md` §9）。
enum LogLevel {
  /// 极细粒度，只在排查特定问题时临时打开。
  trace(0),

  /// 开发期诊断信息。
  debug(10),

  /// 正常运行的关键节点。默认阈值。
  info(20),

  /// 有问题但已降级处理，功能仍可用。
  warn(30),

  /// 操作失败。
  error(40),

  /// 进程即将不可用。
  fatal(50);

  const LogLevel(this.severity);

  /// 数值化的严重程度，仅用于比较。
  final int severity;

  /// 本级别是否达到 [threshold] 的门槛。
  bool isAtLeast(LogLevel threshold) => severity >= threshold.severity;
}
