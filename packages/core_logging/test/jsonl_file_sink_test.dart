import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:core_logging/core_logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late DateTime now;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mistream_log_');
    // 用 UTC 时刻，断言才不会随 CI runner 的时区飘。
    now = DateTime.utc(2026, 8, 3, 10, 30);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<JsonlFileSink> openSink({
    int maxFileBytes = 20 * 1024 * 1024,
    int retentionDays = 7,
  }) => JsonlFileSink.open(
    directory: dir,
    maxFileBytes: maxFileBytes,
    retentionDays: retentionDays,
    clock: () => now,
  );

  LogRecord record(String message, {Map<String, Object?> detail = const {}}) =>
      LogRecord(
        timestamp: now,
        level: LogLevel.info,
        scope: 'test',
        message: message,
        detail: detail,
      );

  List<File> logFiles() =>
      dir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).endsWith('.jsonl'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('按日期命名文件，一条记录一行 JSON', () async {
    final sink = await openSink();
    sink
      ..write(record('第一条'))
      ..write(record('第二条'));
    await sink.close();

    final file = File(p.join(dir.path, 'app-2026-08-03.jsonl'));
    expect(file.existsSync(), isTrue);

    final lines = const LineSplitter().convert(file.readAsStringSync());
    expect(lines, hasLength(2));

    final first = jsonDecode(lines.first) as Map<String, Object?>;
    expect(first['ts'], '2026-08-03T10:30:00.000Z');
    expect(first['level'], 'info');
    expect(first['scope'], 'test');
    expect(first['message'], '第一条');
  });

  test('落盘内容已脱敏', () async {
    final sink = await openSink();
    sink.write(
      record(
        '起播 https://cdn.example.com/a.m3u8?token=abc123',
        detail: const {'authorization': 'Bearer xyz'},
      ),
    );
    await sink.close();

    final content = File(
      p.join(dir.path, 'app-2026-08-03.jsonl'),
    ).readAsStringSync();

    expect(content, contains('token=***'));
    expect(content, isNot(contains('abc123')));
    expect(content, isNot(contains('xyz')));
  });

  test('错误码同时落数值与常量名', () async {
    final sink = await openSink();
    sink.write(
      LogRecord(
        timestamp: now,
        level: LogLevel.error,
        scope: 'spider',
        message: '脚本超时',
        siteId: 'site-12',
        code: ErrorCode.scriptTimeout,
      ),
    );
    await sink.close();

    final line = File(
      p.join(dir.path, 'app-2026-08-03.jsonl'),
    ).readAsStringSync().trim();
    final json = jsonDecode(line) as Map<String, Object?>;

    expect(json['code'], -32102);
    expect(json['codeName'], 'SCRIPT_TIMEOUT');
    expect(json['siteId'], 'site-12');
  });

  test('超过单文件上限后换新文件，不改名', () async {
    final sink = await openSink(maxFileBytes: 300);
    for (var i = 0; i < 12; i++) {
      sink.write(record('填充填充填充填充填充填充 $i'));
    }
    await sink.close();

    final names = logFiles().map((f) => p.basename(f.path)).toList();
    expect(names, contains('app-2026-08-03.jsonl'));
    expect(names.length, greaterThan(1));
    expect(names, contains('app-2026-08-03.1.jsonl'));

    for (final file in logFiles()) {
      expect(
        file.lengthSync(),
        lessThanOrEqualTo(300 + 200),
        reason: '${p.basename(file.path)} 明显超出上限',
      );
    }
  });

  test('跨天自动换文件', () async {
    final sink = await openSink();
    sink.write(record('昨天'));
    await sink.flush();

    now = DateTime.utc(2026, 8, 4, 0, 1);
    sink.write(record('今天'));
    await sink.close();

    expect(
      logFiles().map((f) => p.basename(f.path)),
      containsAll(<String>['app-2026-08-03.jsonl', 'app-2026-08-04.jsonl']),
    );
  });

  test('重开时续写当天文件，已有内容算进配额', () async {
    final first = await openSink();
    first.write(record('第一次运行'));
    await first.close();

    final second = await openSink();
    second.write(record('第二次运行'));
    await second.close();

    final lines = const LineSplitter().convert(
      File(p.join(dir.path, 'app-2026-08-03.jsonl')).readAsStringSync(),
    );
    expect(lines, hasLength(2));
  });

  test('启动时清掉超出保留期的文件', () async {
    File(p.join(dir.path, 'app-2020-01-01.jsonl')).writeAsStringSync('旧\n');
    File(p.join(dir.path, 'app-2026-07-29.jsonl')).writeAsStringSync('刚好\n');
    File(p.join(dir.path, 'notes.txt')).writeAsStringSync('别删我\n');

    final sink = await openSink();
    await sink.close();

    final names = dir.listSync().map((e) => p.basename(e.path)).toList();
    expect(names, isNot(contains('app-2020-01-01.jsonl')));
    // 保留 7 天含当天：7-29 到 8-3 正好在窗口内。
    expect(names, contains('app-2026-07-29.jsonl'));
    expect(names, contains('notes.txt'));
  });
}
