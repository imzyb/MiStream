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
    stdoutCtrl.close();
    exitCodeCompleter.complete(0);
  }

  void crash() {
    exitCodeCompleter.complete(-1);
    stdoutCtrl.close();
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
      host.start();
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
      host.start();
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
}
