import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:spider_host/src/host/host_api.dart';
import 'package:spider_host/src/host/spider_host.dart';
import 'package:spider_host/src/runtime/spider_runtime_factory.dart';
import 'package:test/test.dart';

/// 模拟一个子进程，向宿主提供可控的 stdin/stdout/exitCode。
class _FakeProcess {
  final StreamController<List<int>> stdoutCtrl = StreamController<List<int>>();
  final _FakeSink stdinSink = _FakeSink();
  final Completer<int> exitCodeCompleter = Completer<int>();

  Stream<List<int>> get stdout => stdoutCtrl.stream;
  IOSink get stdin => stdinSink;
  Future<int> get exitCode => exitCodeCompleter.future;

  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!exitCodeCompleter.isCompleted) {
      exitCodeCompleter.complete(0);
    }
    return true;
  }

  void close() {
    unawaited(stdoutCtrl.close());
    if (!exitCodeCompleter.isCompleted) exitCodeCompleter.complete(0);
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

/// 按 LSP 风格给 JSON 文本加帧头；Content-Length 以 UTF-8 字节数计。
List<int> framed(String body) {
  final encoded = utf8.encode(body);
  final header = utf8.encode('Content-Length: ${encoded.length}\r\n\r\n');
  return [...header, ...encoded];
}

/// 构造一个成功握手响应帧。
List<int> handshakeResponse(int id) => framed(
  jsonEncode({
    'jsonrpc': '2.0',
    'id': id,
    'result': {
      'protocolVersion': 1,
      'runtimeVersion': '1.0.0',
      'features': ['storage'],
    },
  }),
);

/// 构造一个普通响应帧。
List<int> resultResponse(int id, Object? result) =>
    framed(jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}));

/// 从请求帧中提取 id。
int extractId(List<int> frame) {
  final raw = utf8.decode(frame);
  return int.parse(RegExp(r'"id":(\d+)').firstMatch(raw)!.group(1)!);
}

/// 从请求帧中提取 method 字段。
String? extractMethod(List<int> frame) {
  final raw = utf8.decode(frame);
  return RegExp('"method":"([^"]+)"').firstMatch(raw)?.group(1);
}

/// 解析请求帧的 params 映射。
Map<String, Object?> extractParams(List<int> frame) {
  final raw = utf8.decode(frame);
  final body = raw.substring(raw.indexOf('{', raw.indexOf('Content-Length')));
  final decoded = jsonDecode(body) as Map<String, Object?>;
  return (decoded['params'] as Map<String, Object?>?) ?? const {};
}

void main() {
  group('SpiderRuntimeFactory JS', () {
    late List<_FakeProcess> processes;
    late File scriptFile;

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

    SpiderRuntimeFactory newFactory() => SpiderRuntimeFactory(
      spiderJsPath: 'unused',
      hostApi: HostApi(),
      jsLauncher: fakeLauncher,
    );

    _FakeProcess proc() => processes.last;

    /// 轮询等条件成立，最多 2 秒。
    ///
    /// 不用固定 `delay`：换新要走一次退避（默认 1s）加进程启动，写死时长会
    /// 让用例在慢机器上闪断。
    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 400 && !condition(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    /// 等到当前进程最新写出的一帧是 [method]。
    Future<void> waitForMethod(String method) => waitFor(
      () =>
          processes.isNotEmpty &&
          extractMethod(proc().stdinSink.written.last) == method,
    );

    /// 应答当前进程上最新写出的那一帧，并断言它正是对 [method] 的请求。
    void reply(String method, {Object? result}) {
      final frame = proc().stdinSink.written.last;
      expect(extractMethod(frame), method);
      proc().stdoutCtrl.add(resultResponse(extractId(frame), result));
    }

    setUp(() async {
      processes = [];
      scriptFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'js_factory_test_${DateTime.now().microsecondsSinceEpoch}.js',
      );
      await scriptFile.writeAsString('export default {};');
    });

    tearDown(() async {
      if (scriptFile.existsSync()) await scriptFile.delete();
    });

    test('type=3 本地脚本走 JS 运行时，create 参数带上 baseUrl/configBaseUrl', () async {
      final factory = newFactory();
      addTearDown(factory.dispose);

      final pending = factory.create(typeCode: 3, api: scriptFile.path);
      await waitFor(
        () => processes.isNotEmpty && proc().stdinSink.written.isNotEmpty,
      );
      // 补握手，否则 start() 一直悬着。
      proc().stdoutCtrl.add(
        handshakeResponse(extractId(proc().stdinSink.written.first)),
      );

      await waitForMethod('spider.create');
      final frame = proc().stdinSink.written.last;
      final params = extractParams(frame);
      expect(params['script'], 'export default {};');
      expect(params['baseUrl'], scriptFile.path);
      expect(params['configBaseUrl'], '');

      reply('spider.create', result: <String, Object?>{});
      expect(await pending, isA<JsRuntimeAdapter>());
      expect(processes, hasLength(1));
    });

    test('换新窗口内再创建源：等同一个宿主回来，不另起子进程', () async {
      final factory = newFactory();
      addTearDown(factory.dispose);

      // 建源 → 毁源，重复 kSourceTearDownsPerProcess 次；最后一次销毁触发换新。
      for (var i = 0; i < kSourceTearDownsPerProcess; i++) {
        final pending = factory.create(typeCode: 3, api: scriptFile.path);
        if (i == 0) {
          await waitFor(
            () => processes.isNotEmpty && proc().stdinSink.written.isNotEmpty,
          );
          proc().stdoutCtrl.add(
            handshakeResponse(extractId(proc().stdinSink.written.first)),
          );
        }
        await waitForMethod('spider.create');
        reply('spider.create', result: <String, Object?>{});
        final runtime = await pending;

        final destroy = runtime.dispose();
        await waitForMethod('spider.destroy');
        reply('spider.destroy', result: <String, Object?>{});
        await destroy;
      }

      // 换新已启动：老进程正在关停，新进程还在退避（默认 1s）里。
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(processes, hasLength(1), reason: '还没到重启时刻');

      // 窗口内再创建源。此刻 isReady 是 false——照旧逻辑这里会新建一个
      // SpiderHost，而旧的那个还在后台重启，于是并存两个子进程。
      final pending = factory.create(typeCode: 3, api: scriptFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        processes,
        hasLength(1),
        reason: '窗口内不能新建宿主——旧的还在后台重启，新建就是两个子进程',
      );

      // 新进程被拉起 → 握手 → 这才轮到 create。
      await waitFor(
        () => processes.length == 2 && proc().stdinSink.written.isNotEmpty,
      );
      proc().stdoutCtrl.add(
        handshakeResponse(extractId(proc().stdinSink.written.first)),
      );
      await waitForMethod('spider.create');
      reply('spider.create', result: <String, Object?>{});
      expect(await pending, isA<JsRuntimeAdapter>());

      // 全程只该有两个进程：原来的 + 换新后的。多出来的那个是失控的孤儿。
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(processes, hasLength(2), reason: '重复建宿主会留下失控的子进程');
    });
  });
}
