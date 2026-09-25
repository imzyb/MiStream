import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/src/host/spider_host.dart';
import 'package:test/test.dart';

/// 模拟一个子进程，向宿主提供可控的 stdin/stdout/exitCode。
class _FakeProcess {
  final StreamController<List<int>> stdoutCtrl = StreamController<List<int>>();
  final _FakeSink stdinSink = _FakeSink();
  final Completer<int> exitCodeCompleter = Completer<int>();

  Stream<List<int>> get stdout => stdoutCtrl.stream;
  IOSink get stdin => stdinSink;
  Future<int> get exitCode => exitCodeCompleter.future;

  bool _killed = false;
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _killed = true;
    if (!exitCodeCompleter.isCompleted) {
      exitCodeCompleter.complete(0);
    }
    return true;
  }

  bool get isKilled => _killed;

  void close() {
    unawaited(stdoutCtrl.close());
    exitCodeCompleter.complete(0);
  }

  void crash() {
    exitCodeCompleter.complete(-1);
    unawaited(stdoutCtrl.close());
  }
}

class _FakeSink implements IOSink {
  final List<List<int>> written = [];

  @override
  void add(List<int> data) => written.add(List<int>.of(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      stream.forEach((d) => written.add(List<int>.of(d)));

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  void write(Object? object) => written.add(utf8.encode('$object'));

  @override
  void writeAll(Iterable<Object?> iterable, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) => written.add(utf8.encode('$object\n'));

  @override
  Future<void> get done => Future<void>.value();
}

/// 构造一个成功握手响应帧。
List<int> handshakeResponse(int id, {int version = 1}) {
  final body = jsonEncode({
    'jsonrpc': '2.0',
    'id': id,
    'result': {
      'protocolVersion': version,
      'runtimeVersion': '1.0.0',
      'features': ['cancel', 'storage'],
    },
  });
  final header = utf8.encode('Content-Length: ${body.length}\r\n\r\n');
  return header.followedBy(utf8.encode(body)).toList();
}

/// 构造一个响应帧。
List<int> responseFrame(int id, Object? result) {
  final body = jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result});
  final header = utf8.encode('Content-Length: ${body.length}\r\n\r\n');
  return header.followedBy(utf8.encode(body)).toList();
}

/// 构造一个错误响应帧。
List<int> errorFrame(int id, {required int code, required String message}) {
  final body = jsonEncode({
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  });
  final header = utf8.encode('Content-Length: ${body.length}\r\n\r\n');
  return header.followedBy(utf8.encode(body)).toList();
}

/// 从请求帧中提取 id。
int extractId(List<int> frame) {
  final raw = utf8.decode(frame);
  return int.parse(RegExp(r'"id":(\d+)').firstMatch(raw)!.group(1)!);
}

void main() {
  group('SpiderHost', () {
    late List<_FakeProcess> processes;
    late SpiderHost host;

    _FakeProcess current() => processes.last;

    Future<
      ({
        IOSink stdin,
        Stream<List<int>> stdout,
        Future<int> exitCode,
        bool Function([ProcessSignal signal]) kill,
      })
    >
    fakeLauncher(String exec, List<String> args) async {
      final p = _FakeProcess();
      processes.add(p);
      return (
        stdin: current().stdinSink,
        stdout: p.stdout,
        exitCode: p.exitCode,
        kill: p.kill,
      );
    }

    setUp(() {
      processes = [];
      host = SpiderHost(
        executable: 'fake',
        arguments: [],
        launcher: fakeLauncher,
      );
    });

    tearDown(() async {
      await host.dispose();
    });

    test('start 成功握手后 isReady 为 true', () async {
      final future = host.start();
      // 等待请求帧
      await Future<void>.delayed(Duration.zero);
      expect(current().stdinSink.written, isNotEmpty);
      final frame = current().stdinSink.written.first;
      final id = extractId(frame);

      current().stdoutCtrl.add(handshakeResponse(id));
      final result = await future;
      expect(result.isOk, isTrue);
      expect(host.isReady, isTrue);
      expect(host.features, contains('cancel'));
    });

    test('协议版本不匹配返回错误', () async {
      final future = host.start();
      await Future<void>.delayed(Duration.zero);
      final id = extractId(current().stdinSink.written.first);

      current().stdoutCtrl.add(handshakeResponse(id, version: 999));
      final result = await future;
      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.protocolVersionMismatch);
      expect(host.isReady, isFalse);
    });

    test('dispose 后进程被 kill', () async {
      final future = host.start();
      await Future<void>.delayed(Duration.zero);
      final id = extractId(current().stdinSink.written.first);
      current().stdoutCtrl.add(handshakeResponse(id));
      await future;
      expect(host.isReady, isTrue);

      await host.dispose();
      expect(current().isKilled, isTrue);
      expect(host.isReady, isFalse);
    });

    test('进程退出后自动重启（退避）', () async {
      host = SpiderHost(
        executable: 'fake',
        arguments: [],
        backoffFor: (_) => Duration.zero,
        launcher: fakeLauncher,
      );
      final future = host.start();
      await Future<void>.delayed(Duration.zero);
      final id = extractId(current().stdinSink.written.first);
      current().stdoutCtrl.add(handshakeResponse(id));
      await future;
      expect(host.isReady, isTrue);

      // 模拟进程崩溃
      current().crash();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 应自动重启：新进程被创建且发送了握手请求
      expect(processes.length, greaterThanOrEqualTo(2));
      expect(current().stdinSink.written, isNotEmpty);
      final raw = utf8.decode(current().stdinSink.written.first);
      expect(raw, contains('"method":"runtime.handshake"'));
    });

    test('连续失败超过上限后熔断', () async {
      host = SpiderHost(
        executable: 'fake',
        arguments: [],
        maxRestartAttempts: 2,
        handshakeTimeout: const Duration(milliseconds: 10),
        backoffFor: (_) => Duration.zero,
        launcher: fakeLauncher,
      );

      // 启动后不给握手响应 → 10ms 超时 → 自动重启 → 再次失败 → 熔断
      unawaited(host.start());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(host.isTripped, isTrue);
    });

    test('reset 复位熔断并重新启动', () async {
      host = SpiderHost(
        executable: 'fake',
        arguments: [],
        maxRestartAttempts: 2,
        handshakeTimeout: const Duration(milliseconds: 10),
        backoffFor: (_) => Duration.zero,
        launcher: fakeLauncher,
      );

      // 触发熔断
      unawaited(host.start());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(host.isTripped, isTrue);

      // reset 应重新启动并握手
      final future = host.reset();
      await Future<void>.delayed(Duration.zero);
      final id = extractId(current().stdinSink.written.first);
      current().stdoutCtrl.add(handshakeResponse(id));
      final result = await future;
      expect(result.isOk, isTrue);
      expect(host.isTripped, isFalse);
      expect(host.isReady, isTrue);
    });
  });

  group('SpiderHost 换新（子进程内存回收）', () {
    late List<_FakeProcess> processes;
    late SpiderHost host;

    _FakeProcess current() => processes.last;

    Future<
      ({
        IOSink stdin,
        Stream<List<int>> stdout,
        Future<int> exitCode,
        bool Function([ProcessSignal signal]) kill,
      })
    >
    fakeLauncher(String exec, List<String> args) async {
      final p = _FakeProcess();
      processes.add(p);
      return (
        stdin: p.stdinSink,
        stdout: p.stdout,
        exitCode: p.exitCode,
        kill: p.kill,
      );
    }

    /// 启动并完成握手。
    Future<void> startReady() async {
      final future = host.start();
      await Future<void>.delayed(Duration.zero);
      current().stdoutCtrl.add(
        handshakeResponse(extractId(current().stdinSink.written.first)),
      );
      await future;
    }

    /// 发一条请求，并把「最后写出的那一帧」当成它，回一个成功响应。
    ///
    /// 子进程侧是同步阻塞的，所以每次调用必定恰好写出一帧；用 `written.last`
    /// 就能对上，不必自己维护 id 序列。
    Future<void> callAndReply(String method, Object? result) async {
      final pending = host.call(method);
      await Future<void>.delayed(Duration.zero);
      final frame = current().stdinSink.written.last;
      current().stdoutCtrl.add(responseFrame(extractId(frame), result));
      await pending;
    }

    setUp(() {
      processes = [];
      host = SpiderHost(
        executable: 'fake',
        arguments: [],
        // 阈值压到 1，一次销毁就该换新。
        sourceTearDownsPerProcess: 1,
        backoffFor: (_) => Duration.zero,
        launcher: fakeLauncher,
      );
    });

    tearDown(() async {
      await host.dispose();
    });

    test('攒够销毁次数后换新子进程，且发的是 runtime.shutdown', () async {
      await startReady();
      await callAndReply('spider.create', <String, Object?>{});
      await callAndReply('spider.destroy', <String, Object?>{});

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final firstProcessFrames = processes.first.stdinSink.written
          .map(utf8.decode)
          .join();
      expect(
        firstProcessFrames,
        contains('"method":"runtime.shutdown"'),
        reason: '换新要走优雅关停，让子进程自己退出、把内存交还 OS',
      );
      expect(processes, hasLength(greaterThanOrEqualTo(2)), reason: '换新后要重新拉起');
    });

    test('还有活实例时不换新（换新会把别人的实例一起带走）', () async {
      await startReady();
      await callAndReply('spider.create', <String, Object?>{});
      await callAndReply('spider.create', <String, Object?>{});
      await callAndReply('spider.destroy', <String, Object?>{});

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(host.liveInstanceCount, 1);
      expect(
        processes,
        hasLength(1),
        reason: '此刻还挂着一个实例，换新会把它一起杀掉，得等它销毁',
      );

      // 最后一个也销毁 → 计数归零 → 这才换新。
      await callAndReply('spider.destroy', <String, Object?>{});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(host.liveInstanceCount, 0);
      expect(processes, hasLength(greaterThanOrEqualTo(2)));
    });

    test('失败的 destroy 不计数', () async {
      await startReady();
      await callAndReply('spider.create', <String, Object?>{});
      // 子进程回错误：这次没有真的毁掉实例，不该攒换新额度。
      final pending = host.call('spider.destroy');
      await Future<void>.delayed(Duration.zero);
      final frame = current().stdinSink.written.last;
      current().stdoutCtrl.add(
        errorFrame(extractId(frame), code: -32602, message: '实例不存在'),
      );
      await pending;

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(processes, hasLength(1));
      expect(host.liveInstanceCount, 1, reason: '失败的 destroy 不该动实例计数');
    });
  });
}
