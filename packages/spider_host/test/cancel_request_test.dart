import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/src/rpc/stdio_rpc_channel.dart';
import 'package:test/test.dart';

/// 取消能真正释放在途请求（ROADMAP M3 出口标准③、docs/08 §3.4）。
///
/// 这条以前是断的：子进程侧会处理 `$/cancelRequest`，但**宿主侧从来不发**。
/// 聚合搜索里用户改一次搜索词，几十个源的在途请求就会一直挂着占连接与内存，
/// 直到各自超时——而取消正是 docs/08 §3.4 明写「必须实现，不是可选项」的。
class _MockSink implements IOSink {
  final List<List<int>> frames = [];

  /// 已写出的全部文本。
  String get text => utf8.decode(frames.expand((e) => e).toList());

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
  void writeAll(Iterable<Object?> iterable, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) => frames.add(utf8.encode('$object\n'));

  @override
  Future<void> get done => Future<void>.value();
}

void main() {
  group('取消在途请求', () {
    late StreamController<List<int>> childStdout;
    late _MockSink sink;
    late StdioRpcChannel channel;

    setUp(() {
      childStdout = StreamController<List<int>>();
      sink = _MockSink();
      channel = StdioRpcChannel(stdin: childStdout.stream, stdout: sink);
    });

    tearDown(() async {
      await channel.close();
      await childStdout.close();
    });

    /// 等到至少写出了一条请求帧。
    Future<void> waitForRequest() async {
      for (var i = 0; i < 100 && sink.frames.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    int idOf(String text) =>
        int.parse(RegExp(r'"id":(\d+)').firstMatch(text)!.group(1)!);

    void replyTo(int id) {
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': <String, Object?>{},
      });
      final bytes = utf8.encode(body);
      childStdout.add(<int>[
        ...utf8.encode('Content-Length: ${bytes.length}\r\n\r\n'),
        ...bytes,
      ]);
    }

    test('cancelOn 完成后发出取消通知，调用以 REQUEST_CANCELLED 返回', () async {
      final cancel = Completer<void>();
      final call = channel.call(
        'spider.search',
        params: const {'wd': '海贼王'},
        cancelOn: cancel.future,
      );

      await waitForRequest();
      cancel.complete();
      final result = await call;

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.requestCancelled);
      expect(sink.text, contains(r'$/cancelRequest'));
    });

    test('取消通知带上原请求的 id，子进程才知道掐哪一条', () async {
      final cancel = Completer<void>();
      final call = channel.call('spider.search', cancelOn: cancel.future);

      await waitForRequest();
      final requestId = idOf(sink.text);

      cancel.complete();
      await call;

      final cancelPart = sink.text.substring(
        sink.text.indexOf(r'$/cancelRequest'),
      );
      expect(cancelPart, contains('"id":$requestId'));
    });

    test('不取消时不会发出任何取消通知', () async {
      final call = channel.call(
        'runtime.ping',
        timeout: const Duration(milliseconds: 50),
      );
      await call;
      expect(sink.text, isNot(contains(r'$/cancelRequest')));
    });

    // 已经回来的请求再发取消，对端只能困惑——还可能误伤复用了同一 id 的新请求。
    test('请求已返回后再取消，不会多发一条', () async {
      final cancel = Completer<void>();
      final call = channel.call('runtime.ping', cancelOn: cancel.future);

      await waitForRequest();
      replyTo(idOf(sink.text));
      expect((await call).isOk, isTrue);

      cancel.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sink.text, isNot(contains(r'$/cancelRequest')));
    });

    test('取消后释放写队列配额，不会把队列耗尽', () async {
      // 取消若不释放配额，连续取消 kWriteQueueMax 次之后就全是 RUNTIME_BUSY。
      for (var i = 0; i < kWriteQueueMax + 5; i++) {
        final cancel = Completer<void>()..complete();
        final r = await channel.call('spider.search', cancelOn: cancel.future);
        expect(
          r.errorOrNull?.code,
          isNot(ErrorCode.runtimeBusy),
          reason: '第 $i 次调用时写队列已满，说明取消没有释放配额',
        );
      }
    });
  });
}
