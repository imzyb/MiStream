/// JSONL 落盘 sink。
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_logging/src/log_record.dart';
import 'package:core_logging/src/log_sink.dart';
import 'package:core_logging/src/redactor.dart';
import 'package:path/path.dart' as p;

/// 把日志按行写成 JSONL 文件。
///
/// 落盘策略见 `docs/10-开发规范.md` §9：`logs/app-{date}.jsonl`，单文件超过
/// 20MB 后滚动，保留 7 天。
///
/// 滚动用**换文件**而不是改名：Windows 上重命名一个已打开的文件会失败，而
/// 「先关闭再改名再重开」在写入密集时留有丢日志的窗口。超限时直接开
/// `app-{date}.1.jsonl` 更简单，也没有竞态。
final class JsonlFileSink implements LogSink {
  JsonlFileSink._({
    required this.directory,
    required this.redactor,
    required this.maxFileBytes,
    required this.retentionDays,
    required this.filePrefix,
    required DateTime Function() clock,
    required void Function(Object error, StackTrace stackTrace) onError,
    // ignore: prefer_initializing_formals — 命名参数不能以下划线开头
  }) : _clock = clock,
       // ignore: prefer_initializing_formals — 同上
       _onError = onError;

  /// 打开（必要时创建）日志目录，清掉过期文件，续写当天最后一个文件。
  static Future<JsonlFileSink> open({
    required Directory directory,
    Redactor redactor = const Redactor(),
    int maxFileBytes = 20 * 1024 * 1024,
    int retentionDays = 7,
    String filePrefix = 'app',
    DateTime Function() clock = DateTime.now,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    final sink = JsonlFileSink._(
      directory: directory,
      redactor: redactor,
      maxFileBytes: maxFileBytes,
      retentionDays: retentionDays,
      filePrefix: filePrefix,
      clock: clock,
      onError: onError ?? _reportToStderr,
    );
    await sink._start();
    return sink;
  }

  /// 日志目录。
  final Directory directory;

  /// 脱敏器。序列化必经它，见 [LogRecord.toJson]。
  final Redactor redactor;

  /// 单文件字节上限，超过则滚动。
  final int maxFileBytes;

  /// 保留天数（含当天）。
  final int retentionDays;

  /// 文件名前缀。
  final String filePrefix;

  final DateTime Function() _clock;
  final void Function(Object error, StackTrace stackTrace) _onError;

  late final RegExp _namePattern = RegExp(
    '^${RegExp.escape(filePrefix)}'
    r'-(\d{4}-\d{2}-\d{2})(?:\.(\d+))?\.jsonl$',
  );

  IOSink? _out;
  String _date = '';
  int _index = 0;
  int _written = 0;

  // 所有文件操作串在这条链上，保证顺序，也让 flush/close 有东西可等。
  Future<void> _tail = Future<void>.value();

  /// 当前正在写入的文件。
  File get currentFile =>
      File(p.join(directory.path, _fileNameFor(_date, _index)));

  @override
  void write(LogRecord record) {
    final line = jsonEncode(
      record.toJson(redactor),
      toEncodable: (value) => value.toString(),
    );
    final bytes = utf8.encode('$line\n');
    _tail = _tail.then((_) => _append(bytes)).catchError(_onError);
  }

  @override
  Future<void> flush() async {
    await _tail;
    await _out?.flush();
  }

  @override
  Future<void> close() async {
    await _tail;
    final out = _out;
    _out = null;
    if (out == null) return;
    await out.flush();
    await out.close();
  }

  static void _reportToStderr(Object error, StackTrace stackTrace) {
    stderr.writeln('[core_logging] 日志落盘失败：$error');
  }

  static String _dateKey(DateTime time) {
    final year = time.year.toString().padLeft(4, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _fileNameFor(String date, int index) =>
      index == 0 ? '$filePrefix-$date.jsonl' : '$filePrefix-$date.$index.jsonl';

  Future<void> _start() async {
    await directory.create(recursive: true);
    await _prune();

    final date = _dateKey(_clock());
    var index = await _latestIndexFor(date);
    if (await _lengthOf(date, index) >= maxFileBytes) index += 1;
    await _openFile(date: date, index: index);
  }

  Future<void> _append(List<int> bytes) async {
    final date = _dateKey(_clock());

    if (date != _date) {
      await _openFile(date: date, index: 0);
      await _prune();
    } else if (_written > 0 && _written + bytes.length > maxFileBytes) {
      await _openFile(date: date, index: _index + 1);
    }

    _out?.add(bytes);
    _written += bytes.length;
  }

  Future<void> _openFile({required String date, required int index}) async {
    final previous = _out;
    _out = null;
    if (previous != null) {
      await previous.flush();
      await previous.close();
    }

    _date = date;
    _index = index;
    // 追加模式下已有内容也算进配额，否则重启后能把文件写到两倍上限。
    _written = await _lengthOf(date, index);
    _out = File(
      p.join(directory.path, _fileNameFor(date, index)),
    ).openWrite(mode: FileMode.append);
  }

  Future<int> _lengthOf(String date, int index) async {
    final file = File(p.join(directory.path, _fileNameFor(date, index)));
    // 同步判存在：异步版在这条路径上只是多绕一次事件循环，没有并发收益。
    if (!file.existsSync()) return 0;
    return file.length();
  }

  Future<int> _latestIndexFor(String date) async {
    var latest = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final match = _namePattern.firstMatch(p.basename(entity.path));
      if (match == null || match[1] != date) continue;
      final index = int.tryParse(match[2] ?? '0') ?? 0;
      if (index > latest) latest = index;
    }
    return latest;
  }

  Future<void> _prune() async {
    final cutoff = _dateKey(
      _clock().subtract(Duration(days: retentionDays - 1)),
    );

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final match = _namePattern.firstMatch(p.basename(entity.path));
      if (match == null || match[1]!.compareTo(cutoff) >= 0) continue;
      try {
        await entity.delete();
      } on FileSystemException catch (error, stackTrace) {
        // 文件被别的进程占着就跳过，下次启动再清。清不掉不该影响写入。
        _onError(error, stackTrace);
      }
    }
  }
}
