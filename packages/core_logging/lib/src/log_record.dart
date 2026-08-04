/// 一条结构化日志。
library;

import 'package:core_domain/core_domain.dart';
import 'package:core_logging/src/log_level.dart';
import 'package:core_logging/src/redactor.dart';
import 'package:meta/meta.dart';

/// 一条日志记录。
///
/// 字段对应 `docs/10-开发规范.md` §9 的落盘格式。
@immutable
final class LogRecord {
  /// 构造一条日志记录。
  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.scope,
    required this.message,
    this.siteId,
    this.code,
    this.detail = const {},
    this.error,
    this.stackTrace,
  });

  /// 产生时刻。落盘时统一转 UTC，避免跨时区对不上。
  final DateTime timestamp;

  /// 级别。
  final LogLevel level;

  /// 产生位置，模块级粒度，如 `spider` / `player` / `storage`。
  final String scope;

  /// 人可读的说明。会经过文本脱敏。
  final String message;

  /// 相关的源站点 id。源诊断面板按它过滤。
  final String? siteId;

  /// 相关错误码。
  final ErrorCode? code;

  /// 结构化补充信息。敏感键会被整值打掉。
  final Map<String, Object?> detail;

  /// 原始异常对象。
  final Object? error;

  /// 原始堆栈。
  final StackTrace? stackTrace;

  /// 序列化成一行 JSONL 的内容。
  ///
  /// **必须**传入 [redactor]——没有无参重载，这是脱敏不可绕过的实现方式。
  Map<String, Object?> toJson(Redactor redactor) => {
    'ts': timestamp.toUtc().toIso8601String(),
    'level': level.name,
    'scope': scope,
    if (siteId != null) 'siteId': siteId,
    if (code != null) 'code': code!.value,
    if (code != null) 'codeName': code!.name,
    'message': redactor.redactText(message),
    if (detail.isNotEmpty) 'detail': redactor.redactMap(detail),
    if (error != null) 'error': redactor.redactText(error.toString()),
    if (stackTrace != null) 'stack': redactor.redactText(stackTrace.toString()),
  };

  /// 渲染成一行人读的文本，供控制台输出。
  String toDisplayString(Redactor redactor) {
    final buffer = StringBuffer()
      ..write(timestamp.toUtc().toIso8601String())
      ..write(' ')
      ..write(level.name.toUpperCase().padRight(5))
      ..write(' [')
      ..write(scope);
    if (siteId != null) buffer.write('/$siteId');
    buffer
      ..write('] ')
      ..write(redactor.redactText(message));
    if (code != null) buffer.write(' ($code)');
    if (detail.isNotEmpty) buffer.write(' ${redactor.redactMap(detail)}');
    return buffer.toString();
  }

  @override
  String toString() => toDisplayString(const Redactor());
}
