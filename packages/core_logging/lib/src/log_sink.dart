/// 日志输出目的地。
library;

import 'dart:collection';
import 'dart:io';

import 'package:core_logging/src/log_level.dart';
import 'package:core_logging/src/log_record.dart';
import 'package:core_logging/src/redactor.dart';

/// 一个日志输出目的地。
///
/// [write] 是同步的：日志调用点遍布全项目，要求每处都 `await` 会把异步污染
/// 传染到所有同步代码里。实现类自己负责把 IO 排队。
abstract interface class LogSink {
  /// 写入一条记录。不得抛异常——日志失败不该拖垮业务。
  void write(LogRecord record);

  /// 把缓冲刷到底层。
  Future<void> flush();

  /// 刷完并关闭。
  Future<void> close();
}

/// 输出到控制台。
///
/// [LogLevel.error] 及以上走 stderr，其余走 stdout——这样 CI 与 shell 管道能
/// 按流分开处理。
final class ConsoleSink implements LogSink {
  /// 构造一个控制台 sink。
  const ConsoleSink({this.redactor = const Redactor()});

  /// 脱敏器。
  final Redactor redactor;

  @override
  void write(LogRecord record) {
    final line = record.toDisplayString(redactor);
    if (record.level.isAtLeast(LogLevel.error)) {
      stderr.writeln(line);
    } else {
      stdout.writeln(line);
    }
  }

  @override
  Future<void> flush() async {
    await stdout.flush();
    await stderr.flush();
  }

  @override
  Future<void> close() async {}
}

/// 只保留最近 N 条的环形缓冲。
///
/// 两个用途：单测里断言输出，以及「复制诊断信息」按钮所需的「最近 50 条相关
/// 日志」（`docs/10-开发规范.md` §9）。
final class MemoryLogSink implements LogSink {
  /// 构造一个内存 sink，最多保留 [capacity] 条。
  MemoryLogSink({this.capacity = 50, this.redactor = const Redactor()})
    : assert(capacity > 0, 'capacity 必须为正');

  /// 保留条数上限。
  final int capacity;

  /// 脱敏器。
  final Redactor redactor;

  final Queue<Map<String, Object?>> _entries = Queue();

  /// 已脱敏的记录，从旧到新。
  List<Map<String, Object?>> get entries => List.unmodifiable(_entries);

  @override
  void write(LogRecord record) {
    _entries.addLast(record.toJson(redactor));
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async => _entries.clear();
}

/// 把一条记录分发给多个 sink。
final class MultiLogSink implements LogSink {
  /// 构造一个复合 sink。
  const MultiLogSink(this.sinks);

  /// 下游 sink 列表。
  final List<LogSink> sinks;

  @override
  void write(LogRecord record) {
    for (final sink in sinks) {
      sink.write(record);
    }
  }

  @override
  Future<void> flush() async {
    for (final sink in sinks) {
      await sink.flush();
    }
  }

  @override
  Future<void> close() async {
    for (final sink in sinks) {
      await sink.close();
    }
  }
}
