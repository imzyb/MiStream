/// 日志门面。
library;

import 'package:core_domain/core_domain.dart';
import 'package:core_logging/src/log_level.dart';
import 'package:core_logging/src/log_record.dart';
import 'package:core_logging/src/log_sink.dart';

/// 可变的日志配置。
///
/// 单独成对象而不是 [Logger] 的字段，是为了让「设置里把级别调到 debug」能一次
/// 生效于所有 scope——子 logger 与父 logger 共享同一个实例。
final class LoggerConfig {
  /// 构造配置。
  LoggerConfig({this.minLevel = LogLevel.info});

  /// 低于此级别的记录直接丢弃。默认 [LogLevel.info]。
  LogLevel minLevel;
}

/// 打日志的入口。
///
/// 一个模块持有一个 [Logger]，`scope` 就是模块名。跨源的调用再用
/// [forSite] 派生出带 `siteId` 的子 logger，这样源诊断面板能按源过滤。
final class Logger {
  /// 构造一个 logger。
  Logger({
    required this.scope,
    required this.sink,
    LoggerConfig? config,
    this.siteId,
    DateTime Function() clock = DateTime.now,
  }) : config = config ?? LoggerConfig(),
       // ignore: prefer_initializing_formals — 命名参数不能以下划线开头
       _clock = clock;

  /// 模块名，如 `spider` / `player` / `storage`。
  final String scope;

  /// 输出目的地。
  final LogSink sink;

  /// 共享配置。
  final LoggerConfig config;

  /// 默认的源站点 id，可被单条调用覆盖。
  final String? siteId;

  final DateTime Function() _clock;

  /// 派生一个换了 scope 的子 logger，复用同一 sink 与配置。
  Logger scoped(String name, {String? siteId}) => Logger(
    scope: name,
    sink: sink,
    config: config,
    siteId: siteId ?? this.siteId,
    clock: _clock,
  );

  /// 派生一个绑定到某个源的子 logger。
  Logger forSite(String siteId) => Logger(
    scope: scope,
    sink: sink,
    config: config,
    siteId: siteId,
    clock: _clock,
  );

  /// 该级别当前是否会被记录。
  ///
  /// 用于跳过昂贵的 detail 构造：`if (log.isEnabled(LogLevel.debug))`。
  bool isEnabled(LogLevel level) => level.isAtLeast(config.minLevel);

  /// 记录一条日志。
  void log(
    LogLevel level,
    String message, {
    String? siteId,
    ErrorCode? code,
    Map<String, Object?> detail = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!isEnabled(level)) return;

    sink.write(
      LogRecord(
        timestamp: _clock(),
        level: level,
        scope: scope,
        message: message,
        siteId: siteId ?? this.siteId,
        code: code,
        detail: detail,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// 记录一个 [AppError]，自动带上错误码、detail、原始异常与堆栈。
  ///
  /// 比手工摊开字段可靠：漏掉 `code` 的日志在诊断面板里没法归类，漏掉
  /// `remoteStack` 则源作者无从排错。
  void failure(
    AppError error, {
    String? message,
    LogLevel level = LogLevel.error,
    String? siteId,
    Map<String, Object?> detail = const {},
  }) {
    log(
      level,
      message ?? error.message,
      siteId:
          siteId ??
          switch (error) {
            RemoteError(:final instanceId) => instanceId,
            LocalError() => null,
          },
      code: error.code,
      detail: {...error.detail, ...detail},
      error: error.cause,
      stackTrace: error.stackTrace,
    );
  }

  /// 记录 [LogLevel.trace]。
  void trace(
    String message, {
    String? siteId,
    ErrorCode? code,
    Map<String, Object?> detail = const {},
  }) =>
      log(LogLevel.trace, message, siteId: siteId, code: code, detail: detail);

  /// 记录 [LogLevel.debug]。
  void debug(
    String message, {
    String? siteId,
    ErrorCode? code,
    Map<String, Object?> detail = const {},
  }) =>
      log(LogLevel.debug, message, siteId: siteId, code: code, detail: detail);

  /// 记录 [LogLevel.info]。
  void info(
    String message, {
    String? siteId,
    ErrorCode? code,
    Map<String, Object?> detail = const {},
  }) => log(LogLevel.info, message, siteId: siteId, code: code, detail: detail);

  /// 记录 [LogLevel.warn]。
  void warn(
    String message, {
    String? siteId,
    ErrorCode? code,
    Map<String, Object?> detail = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.warn,
    message,
    siteId: siteId,
    code: code,
    detail: detail,
    error: error,
    stackTrace: stackTrace,
  );

  /// 记录 [LogLevel.error]。
  void error(
    String message, {
    String? siteId,
    ErrorCode? code,
    Map<String, Object?> detail = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.error,
    message,
    siteId: siteId,
    code: code,
    detail: detail,
    error: error,
    stackTrace: stackTrace,
  );

  /// 记录 [LogLevel.fatal]。
  void fatal(
    String message, {
    String? siteId,
    ErrorCode? code,
    Map<String, Object?> detail = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.fatal,
    message,
    siteId: siteId,
    code: code,
    detail: detail,
    error: error,
    stackTrace: stackTrace,
  );

  /// 把 sink 的缓冲刷到底层。
  Future<void> flush() => sink.flush();

  /// 关闭 sink。进程退出前调用，否则尾部日志可能丢。
  Future<void> close() => sink.close();
}
