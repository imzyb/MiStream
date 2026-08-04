import 'package:core_domain/core_domain.dart';
import 'package:core_logging/core_logging.dart';
import 'package:test/test.dart';

void main() {
  late MemoryLogSink sink;
  late Logger logger;

  setUp(() {
    sink = MemoryLogSink();
    logger = Logger(
      scope: 'app',
      sink: sink,
      clock: () => DateTime.utc(2026, 8, 3),
    );
  });

  group('级别过滤', () {
    test('默认丢弃 info 以下', () {
      logger
        ..trace('t')
        ..debug('d')
        ..info('i');

      expect(sink.entries.map((e) => e['message']), ['i']);
    });

    test('isEnabled 与实际过滤一致', () {
      expect(logger.isEnabled(LogLevel.debug), isFalse);
      expect(logger.isEnabled(LogLevel.warn), isTrue);
    });

    test('改配置对已派生的子 logger 同样生效', () {
      final child = logger.scoped('spider');
      logger.config.minLevel = LogLevel.debug;

      child.debug('现在能过');

      expect(sink.entries, hasLength(1));
      expect(sink.entries.single['scope'], 'spider');
    });
  });

  group('派生', () {
    test('scoped 换 scope，保留 sink 与配置', () {
      logger.scoped('player').info('起播');

      expect(sink.entries.single['scope'], 'player');
    });

    test('forSite 绑定 siteId，单条调用可覆盖', () {
      logger.forSite('site-1')
        ..info('用默认的')
        ..info('临时换一个', siteId: 'site-2');

      expect(
        sink.entries.map((e) => e['siteId']),
        ['site-1', 'site-2'],
      );
    });
  });

  group('failure', () {
    test('摊开 AppError 的错误码、detail 与原始异常', () {
      final cause = StateError('底层炸了');
      final error = LocalError(
        code: ErrorCode.dbMigrationFailed,
        message: '迁移失败',
        detail: const {'from': 1, 'to': 2},
        cause: cause,
        stackTrace: StackTrace.current,
      );

      logger.failure(error, detail: const {'attempt': 3});

      final entry = sink.entries.single;
      expect(entry['level'], 'error');
      expect(entry['message'], '迁移失败');
      expect(entry['code'], 1101);
      expect(entry['codeName'], 'DB_MIGRATION_FAILED');
      expect(entry['detail'], {'from': 1, 'to': 2, 'attempt': 3});
      expect(entry['error'], contains('底层炸了'));
      expect(entry['stack'], isNotNull);
    });

    test('RemoteError 的 instanceId 自动填进 siteId', () {
      logger.failure(
        const RemoteError(
          code: ErrorCode.scriptTimeout,
          message: '超时',
          instanceId: 'site-9',
        ),
      );

      expect(sink.entries.single['siteId'], 'site-9');
    });

    test('可以降级成 warn，比如硬解回退这种非致命事件', () {
      logger.failure(
        const LocalError(
          code: ErrorCode.playerHwdecFallback,
          message: '硬解不可用，已降级软解',
        ),
        level: LogLevel.warn,
      );

      expect(sink.entries.single['level'], 'warn');
    });
  });

  test('经 sink 落地的内容一定是脱敏过的', () {
    logger.info(
      '请求 https://a.example.com/x?token=abc123',
      detail: const {'cookie': 'sid=1'},
    );

    final entry = sink.entries.single;
    expect(entry['message'], '请求 https://a.example.com/x?token=***');
    expect((entry['detail']! as Map)['cookie'], '***');
  });

  group('MemoryLogSink', () {
    test('只保留最近 N 条', () {
      final small = MemoryLogSink(capacity: 3);
      final ring = Logger(scope: 'app', sink: small);

      for (var i = 0; i < 5; i++) {
        ring.info('$i');
      }

      expect(small.entries.map((e) => e['message']), ['2', '3', '4']);
    });

    test('entries 不可从外部改', () {
      logger.info('x');

      expect(() => sink.entries.clear(), throwsUnsupportedError);
    });
  });
}
