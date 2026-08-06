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
  void writeAll(
    Iterable<Object?> iterable, [
    String separator = '',
  ]) => iterable.forEach((o) => frames.add(utf8.encode('$o$separator')));

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
  });
}
