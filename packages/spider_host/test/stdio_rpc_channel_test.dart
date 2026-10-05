import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/src/rpc/stdio_rpc_channel.dart';
import 'package:test/test.dart';

/// 一个假的 IOSink：把写出的每个分块累积进 [frames]，便于测试断言。
class _MockSink implements IOSink {
  final List<List<int>> frames = [];

  @override
  void add(List<int> data) => frames.add(List<int>.of(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      stream.forEach((d) => frames.add(List<int>.of(d)));

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  void write(Object? object) => frames.add(utf8.encode('$object'));

  @override
  void writeAll(Iterable<Object?> iterable, [String separator = '']) {
    for (final o in iterable) {
      frames.add(utf8.encode('$o$separator'));
    }
  }

  @override
  void writeCharCode(int charCode) =>
      frames.add(utf8.encode(String.fromCharCode(charCode)));

  @override
  void writeln([Object? object = '']) => frames.add(utf8.encode('$object\n'));

  @override
  Future<void> get done => Future<void>.value();
}

/// 复刻 `dart:io` 的 `_StreamSinkImpl` 绑定语义的 IOSink。
///
/// [_MockSink] 的 `flush()` 是 `async {}` —— 永不绑定，所以它**测不出**
/// `Process.stdin` 的真实行为。而 `Process.stdin` 实际是
/// `_StdSink(_Socket._writePipe())`，底层 `IOSink(_SocketStreamConsumer)`
/// 就是 `_StreamSinkImpl`：
///
/// - `flush()` 在函数体内**同步**把 `_isBound` 置 true，直到底层 `addStream`
///   完成才在 `whenComplete` 里复位；
/// - `add()` 走的 `_controller` getter 在 `_isBound` 为真时直接抛
///   `StateError("StreamSink is bound to a stream")`。
///
/// 这个 mock 用 [holdFlush] 把「flush 在飞」的窗口显式撑开，用来复现
/// 「add 紧跟 await flush」在交错时必炸的缺陷。
class _BindingMockSink implements IOSink {
  final List<List<int>> frames = [];

  /// 为 true 时 `flush()` 挂起不返回，模拟底层写还没落盘。
  bool holdFlush = true;

  /// 置 true 后，下一次 [add] 抛错 —— 模拟底层写失败（对端管道已断）。
  bool failNextAdd = false;

  bool _isBound = false;
  final List<Completer<void>> _pendingFlushes = [];

  @override
  void add(List<int> data) {
    if (failNextAdd) {
      failNextAdd = false;
      throw StateError('模拟底层写失败');
    }
    if (_isBound) throw StateError('StreamSink is bound to a stream');
    frames.add(List<int>.of(data));
  }

  @override
  Future<void> flush() {
    if (_isBound) throw StateError('StreamSink is bound to a stream');
    if (!holdFlush) return Future<void>.value();
    _isBound = true;
    final completer = Completer<void>();
    _pendingFlushes.add(completer);
    return completer.future.whenComplete(() => _isBound = false);
  }

  /// 放行全部挂起的 flush，并让后续 flush 立即完成。
  void releaseFlush() {
    holdFlush = false;
    for (final completer in _pendingFlushes) {
      if (!completer.isCompleted) completer.complete();
    }
    _pendingFlushes.clear();
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      stream.forEach((d) => frames.add(List<int>.of(d)));

  @override
  Future<void> close() async {}

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  void write(Object? object) => frames.add(utf8.encode('$object'));

  @override
  void writeAll(Iterable<Object?> iterable, [String separator = '']) {
    for (final o in iterable) {
      frames.add(utf8.encode('$o$separator'));
    }
  }

  @override
  void writeCharCode(int charCode) =>
      frames.add(utf8.encode(String.fromCharCode(charCode)));

  @override
  void writeln([Object? object = '']) => frames.add(utf8.encode('$object\n'));

  @override
  Future<void> get done => Future<void>.value();
}

void main() {
  group('StdioRpcChannel', () {
    late StreamController<List<int>> stdinController;
    late _MockSink mockSink;
    late StdioRpcChannel channel;

    setUp(() {
      stdinController = StreamController<List<int>>();
      mockSink = _MockSink();
      channel = StdioRpcChannel(
        stdin: stdinController.stream,
        stdout: mockSink,
      );
    });

    tearDown(() async {
      await channel.close();
      await stdinController.close();
    });

    /// 等待 mockSink 累积到至少 [n] 帧后返回第 [i] 帧。
    Future<List<int>> outputFrame(int i) async {
      while (mockSink.frames.length <= i) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return mockSink.frames[i];
    }

    /// 构造一条 Content-Length 分帧。
    List<int> frame(String body) {
      final header = utf8.encode('Content-Length: ${body.length}\r\n\r\n');
      return header.followedBy(utf8.encode(body)).toList();
    }

    test('call 发送请求帧并接收响应', () async {
      final result = channel.call('spider.ping', params: {'ts': 1});
      final frame0 = await outputFrame(0);
      final raw = utf8.decode(frame0);
      expect(raw, contains('"method":"spider.ping"'));
      expect(raw, contains('Content-Length'));
      final id = int.parse(
        RegExp(r'"id":(\d+)').firstMatch(raw)!.group(1)!,
      );

      stdinController.add(frame('{"id":$id,"result":"pong"}'));
      final resp = await result;
      expect(resp.isOk, isTrue);
      expect(resp.valueOrNull, 'pong');
    });

    test('call 超时返回 Err', () async {
      final result = channel.call('spider.slow', timeout: Duration.zero);
      final resp = await result;
      expect(resp.isErr, isTrue);
      expect(resp.errorOrNull?.code, ErrorCode.scriptTimeout);
    });

    test('call 写队列超过上限返回 RUNTIME_BUSY', () async {
      final futures = <Future<Result<Object?, RemoteError>>>[];
      for (var i = 0; i < kWriteQueueMax + 5; i++) {
        futures.add(
          channel.call(
            'spider.ping',
            timeout: const Duration(milliseconds: 10),
          ),
        );
      }
      final results = await Future.wait(futures);
      final busyCount = results.where(
        (r) => r.isErr && r.errorOrNull?.code == ErrorCode.runtimeBusy,
      );
      expect(busyCount.length, greaterThan(0));
    });

    test('超时后写队列归零，背压闸门不会失效（回归）', () async {
      // 曾经的缺陷：超时路径与正常路径各扣一次计数，一轮超时就把计数扣成负数，
      // 之后 `>= kWriteQueueMax` 永远不成立，闸门形同虚设。
      Future<List<Result<Object?, RemoteError>>> round(int n) =>
          Future.wait(<Future<Result<Object?, RemoteError>>>[
            for (var i = 0; i < n; i++)
              channel.call('spider.ping', timeout: Duration.zero),
          ]);

      final first = await round(kWriteQueueMax);
      expect(first.every((r) => r.isErr), isTrue);

      // 队列已归零：这一轮正好装满 64 条，第 65 条必须被拒。
      final second = await round(kWriteQueueMax + 1);
      final busyCount = second
          .where((r) => r.errorOrNull?.code == ErrorCode.runtimeBusy)
          .length;
      expect(busyCount, 1);
    });

    test('notify 发送通知帧', () async {
      await channel.notify('runtime.log', params: {'level': 'info'});
      final frame = mockSink.frames.single;
      final raw = utf8.decode(frame);
      expect(raw, contains('"method":"runtime.log"'));
      expect(raw, contains('"level":"info"'));
      expect(raw, isNot(contains('"id"')));
    });

    test('收到通知触发 notifications 流', () async {
      late Map<String, Object?> received;
      channel.notifications.listen((n) => received = n);

      stdinController.add(
        frame('{"method":"runtime.log","params":{}}'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(received['method'], 'runtime.log');
    });

    test('管道关闭后 pending 请求被取消', () async {
      final result = channel.call('spider.ping');
      await channel.close();
      final resp = await result;
      expect(resp.isErr, isTrue);
      expect(resp.errorOrNull?.code, ErrorCode.requestCancelled);
    });

    test('收到错误响应返回 Err', () async {
      final result = channel.call('spider.fail');
      final frame0 = await outputFrame(0);
      final raw = utf8.decode(frame0);
      // 从请求帧中提取 id，用于构造响应
      final id = int.parse(
        RegExp(r'"id":(\d+)').firstMatch(raw)!.group(1)!,
      );

      stdinController.add(
        frame('{"id":$id,"error":{"code":-32101,"message":"fail"}}'),
      );
      final resp = await result;
      expect(resp.isErr, isTrue);
      expect(resp.errorOrNull?.code, ErrorCode.scriptRuntimeError);
    });

    // ── 回归：写必须串行化（2026-10-04 用户报「所有站点都不能用」的根因） ──
    //
    // 症状是 GUI 里报
    //   Bad state: JVM 实例创建失败: 发送失败: Bad state: StreamSink is bound to a stream
    // 根因是 `_send` 里 `add()` 紧跟 `await flush()`，而 `Process.stdin` 的
    // `flush()` 会同步置 `_isBound`，此时另一次 `add()` 必抛。
    // 触发者是并发的发送方：心跳 `runtime.ping`、宿主 API 的 `respond()`、
    // 聚合搜索里的并发请求，任何一个和 `spider.create` 交错就炸。

    group('写串行化（回归）', () {
      late _BindingMockSink sink;
      late StreamController<List<int>> stdin;
      late StdioRpcChannel ch;

      setUp(() {
        sink = _BindingMockSink();
        stdin = StreamController<List<int>>();
        ch = StdioRpcChannel(stdin: stdin.stream, stdout: sink);
      });

      tearDown(() async {
        sink.releaseFlush();
        await ch.close();
        await stdin.close();
      });

      test('flush 在飞时的第二次发送会排队，不抛 StreamSink is bound', () async {
        final first = ch.notify('runtime.log', params: {'n': 1});
        final second = ch.notify('runtime.log', params: {'n': 2});
        await pumpEventQueue();

        // 第一次写已落地、flush 挂起；第二次必须仍在排队。
        expect(sink.frames.length, 1);
        expect(utf8.decode(sink.frames.single), contains('"n":1'));

        sink.releaseFlush();
        await Future.wait(<Future<void>>[first, second]);

        expect(sink.frames.length, 2);
        // 顺序必须保持。
        expect(utf8.decode(sink.frames[0]), contains('"n":1'));
        expect(utf8.decode(sink.frames[1]), contains('"n":2'));
      });

      test('一次失败不毒化写链，后续写照常发出', () async {
        final first = ch.notify('runtime.log', params: {'n': 1});
        await pumpEventQueue();
        // 模拟底层写失败（对端管道断了）。
        sink.failNextAdd = true;
        final second = ch.notify('runtime.log', params: {'n': 2});
        sink.releaseFlush();

        await expectLater(first, completes);
        await expectLater(second, throwsA(isA<StateError>()));

        // 链没断：再来一次仍能成功。
        final third = ch.notify('runtime.log', params: {'n': 3});
        await expectLater(third, completes);
        expect(utf8.decode(sink.frames.last), contains('"n":3'));
      });

      test('flush 在飞时 close 不抛 StreamSink is bound', () async {
        final inFlight = ch.notify('runtime.log', params: {'n': 1});
        await pumpEventQueue();
        expect(sink.frames.length, 1);

        final closing = ch.close();
        sink.releaseFlush();

        await closing;
        await inFlight;
      });

      test('并发 8 次发送全部落地且顺序不乱', () async {
        final futures = <Future<void>>[
          for (var i = 0; i < 8; i++)
            ch.notify('runtime.log', params: {'n': i}),
        ];
        await pumpEventQueue();
        expect(sink.frames.length, 1, reason: '串行化：同一时刻只有一次写在飞');

        sink.releaseFlush();
        await Future.wait(futures);

        expect(sink.frames.length, 8);
        for (var i = 0; i < 8; i++) {
          expect(utf8.decode(sink.frames[i]), contains('"n":$i'));
        }
      });
    });
  });
}
