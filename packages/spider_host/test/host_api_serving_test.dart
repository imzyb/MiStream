import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:spider_host/spider_host.dart';
import 'package:test/test.dart';

/// 宿主 API 的服务端接线：子进程发来的 `host.*` 请求要真的被应答。
///
/// 这条线以前是断的——`HostApi` 写好了却从没接到任何 channel 上，
/// `incomingRequests` 也没人消费。子进程发出的每条 `req` / `local.*` 都会
/// 石沉大海，而它正卡在同步阻塞读上等回话，表现是整个源静默卡死。
class _FakeProcess {
  final StreamController<List<int>> stdoutCtrl = StreamController<List<int>>();
  final _FakeSink stdinSink = _FakeSink();
  final Completer<int> exitCodeCompleter = Completer<int>();

  Stream<List<int>> get stdout => stdoutCtrl.stream;
  Future<int> get exitCode => exitCodeCompleter.future;

  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!exitCodeCompleter.isCompleted) exitCodeCompleter.complete(0);
    return true;
  }
}

class _FakeSink implements IOSink {
  final List<List<int>> written = [];

  /// 已写出的全部字节拼成的文本，用来断言宿主回了什么。
  String get text => utf8.decode(written.expand((e) => e).toList());

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

List<int> _frame(Map<String, Object?> msg) {
  final body = utf8.encode(jsonEncode(msg));
  return <int>[
    ...utf8.encode('Content-Length: ${body.length}\r\n\r\n'),
    ...body,
  ];
}

List<int> _handshakeResponse(int id) => _frame({
  'jsonrpc': '2.0',
  'id': id,
  'result': {
    'protocolVersion': 1,
    'runtimeVersion': '1.0.0',
    'features': <String>['storage'],
  },
});

int _extractId(String raw) =>
    int.parse(RegExp(r'"id":(\d+)').firstMatch(raw)!.group(1)!);

/// 等宿主写出下一条帧（应答是异步的：host.fetch 要真发网络）。
Future<String> _awaitWrite(_FakeSink sink, int fromIndex) async {
  for (var i = 0; i < 200; i++) {
    if (sink.written.length > fromIndex) {
      await Future<void>.delayed(Duration.zero);
      return utf8.decode(
        sink.written.skip(fromIndex).expand((e) => e).toList(),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('宿主 1s 内没有回话');
}

void main() {
  group('SpiderHost 服务宿主 API', () {
    late List<_FakeProcess> processes;
    late Map<String, String> store;

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

    HostApi apiWithStore() => HostApi(
      storage: HostStorage(
        get: (owner, key) async => store['$owner/$key'],
        set: (owner, key, value) async {
          store['$owner/$key'] = value;
          return value.length;
        },
        delete: (owner, key) async {
          store.remove('$owner/$key');
        },
      ),
    );

    /// 起一个已握手的 host，返回它与 fake 子进程。
    Future<SpiderHost> started({HostApi? api}) async {
      final host = SpiderHost(
        executable: 'fake',
        arguments: const [],
        launcher: fakeLauncher,
        hostApi: api,
      );
      final future = host.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      current().stdoutCtrl.add(
        _handshakeResponse(_extractId(current().stdinSink.text)),
      );
      await future;
      return host;
    }

    setUp(() {
      processes = [];
      store = <String, String>{};
    });

    test('子进程的 host.storage.set 被真正落到注入的实现上', () async {
      final host = await started(api: apiWithStore());
      addTearDown(host.dispose);

      final before = current().stdinSink.written.length;
      current().stdoutCtrl.add(
        _frame({
          'jsonrpc': '2.0',
          'id': 7,
          'method': 'host.storage.set',
          'params': {'instanceId': 'site:1', 'key': 'k', 'value': 'v'},
        }),
      );

      final reply = await _awaitWrite(current().stdinSink, before);
      expect(reply, contains('"id":7'));
      expect(reply, isNot(contains('"error"')));
      expect(store['site:1/k'], 'v');
    });

    test('set 之后 get 能读回同一个值', () async {
      final host = await started(api: apiWithStore());
      addTearDown(host.dispose);
      store['site:1/k'] = '海贼王';

      final before = current().stdinSink.written.length;
      current().stdoutCtrl.add(
        _frame({
          'jsonrpc': '2.0',
          'id': 8,
          'method': 'host.storage.get',
          'params': {'instanceId': 'site:1', 'key': 'k'},
        }),
      );

      final reply = await _awaitWrite(current().stdinSink, before);
      expect(reply, contains('海贼王'));
    });

    test('host.env 不需要注入存储也能答', () async {
      final host = await started(api: HostApi());
      addTearDown(host.dispose);

      final before = current().stdinSink.written.length;
      current().stdoutCtrl.add(
        _frame({
          'jsonrpc': '2.0',
          'id': 9,
          'method': 'host.env',
          'params': {'instanceId': 'site:1'},
        }),
      );

      final reply = await _awaitWrite(current().stdinSink, before);
      expect(reply, contains('"id":9'));
      expect(reply, contains('platform'));
    });

    test('未知方法回错误，而不是不回', () async {
      final host = await started(api: HostApi());
      addTearDown(host.dispose);

      final before = current().stdinSink.written.length;
      current().stdoutCtrl.add(
        _frame({
          'jsonrpc': '2.0',
          'id': 10,
          'method': 'host.nope',
          'params': <String, Object?>{},
        }),
      );

      final reply = await _awaitWrite(current().stdinSink, before);
      expect(reply, contains('"id":10'));
      expect(reply, contains('"error"'));
    });

    // 少回一条应答，子进程就永远醒不过来——所以「没注入」也必须是明确的错误。
    test('没注入 HostApi 时回 METHOD_NOT_FOUND 而不是沉默', () async {
      final host = await started();
      addTearDown(host.dispose);

      final before = current().stdinSink.written.length;
      current().stdoutCtrl.add(
        _frame({
          'jsonrpc': '2.0',
          'id': 11,
          'method': 'host.storage.get',
          'params': {'instanceId': 'site:1', 'key': 'k'},
        }),
      );

      final reply = await _awaitWrite(current().stdinSink, before);
      expect(reply, contains('"id":11'));
      expect(reply, contains('"error"'));
      expect(reply, contains('未注入 HostApi'));
    });

    test('处理器抛异常也要变成一条应答', () async {
      final host = await started(
        api: HostApi(
          storage: HostStorage(
            get: (_, _) async => throw StateError('落库炸了'),
            set: (_, _, _) async => 0,
            delete: (_, _) async {},
          ),
        ),
      );
      addTearDown(host.dispose);

      final before = current().stdinSink.written.length;
      current().stdoutCtrl.add(
        _frame({
          'jsonrpc': '2.0',
          'id': 12,
          'method': 'host.storage.get',
          'params': {'instanceId': 'site:1', 'key': 'k'},
        }),
      );

      final reply = await _awaitWrite(current().stdinSink, before);
      expect(reply, contains('"id":12'));
      expect(reply, contains('"error"'));
    });
  });
}
