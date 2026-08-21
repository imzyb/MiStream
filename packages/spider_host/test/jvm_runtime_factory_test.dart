import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:spider_host/src/host/host_api.dart';
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
List<int> handshakeResponse(int id) {
  final body = jsonEncode({
    'jsonrpc': '2.0',
    'id': id,
    'result': {
      'protocolVersion': 1,
      'runtimeVersion': '1.0.0',
      'features': ['storage'],
    },
  });
  return framed(body);
}

/// 构造一个普通响应帧。
List<int> resultResponse(int id, Object? result) {
  final body = jsonEncode({
    'jsonrpc': '2.0',
    'id': id,
    'result': result,
  });
  return framed(body);
}

/// 按 LSP 风格给 JSON 文本加帧头；Content-Length 以 UTF-8 字节数计。
List<int> framed(String body) {
  final encoded = utf8.encode(body);
  final header = utf8.encode('Content-Length: ${encoded.length}\r\n\r\n');
  return [...header, ...encoded];
}

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
  group('SpiderRuntimeFactory JVM (csp_)', () {
    late List<_FakeProcess> processes;

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

    setUp(() {
      processes = [];
    });

    test('jvmClassName 映射 csp_ 前缀到包内类名', () {
      expect(
        SpiderRuntimeFactory.jvmClassName('csp_Fan'),
        'com.github.catvod.spider.Fan',
      );
      expect(
        SpiderRuntimeFactory.jvmClassName('csp_App3Q'),
        'com.github.catvod.spider.App3Q',
      );
      // 完整包名+类名原样透传
      expect(
        SpiderRuntimeFactory.jvmClassName('csp_com.other.pkg.Klz'),
        'com.other.pkg.Klz',
      );
    });

    test('type=3 + csp_ api 路由到 JVM 运行时并正确下发 create 参数', () async {
      final jarFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'jvm_factory_test_${DateTime.now().microsecondsSinceEpoch}.jar',
      );
      await jarFile.writeAsBytes([1, 2, 3]);

      final factory = SpiderRuntimeFactory(
        spiderJsPath: 'unused',
        hostApi: HostApi(),
        jvm: SpiderJvmConfig(
          javaPath: 'java',
          runtimeJarPath: 'runtime.jar',
          libsDirPath: 'libs',
          jarCacheDir: Directory(
            '${Directory.systemTemp.path}${Platform.pathSeparator}jvm_factory_test',
          ),
        ),
        jvmLauncher: fakeLauncher,
      );
      addTearDown(factory.dispose);

      final createFuture = factory.create(
        typeCode: 3,
        api: 'csp_Fan',
        ext: 'my-ext',
        spiderJarUrl: jarFile.path,
      );

      // 握手
      await Future<void>.delayed(Duration.zero);
      expect(processes, hasLength(1));
      final handshakeId = extractId(processes.first.stdinSink.written.first);
      processes.first.stdoutCtrl.add(handshakeResponse(handshakeId));

      // 等 create 请求写出后回应
      await Future<void>.delayed(Duration.zero);
      final createFrame = processes.first.stdinSink.written[1];
      expect(extractMethod(createFrame), 'spider.create');
      final createParams = extractParams(createFrame);
      expect(createParams['jarPath'], jarFile.path);
      expect(createParams['className'], 'com.github.catvod.spider.Fan');
      expect(createParams['extend'], 'my-ext');
      final createId = extractId(createFrame);
      processes.first.stdoutCtrl.add(
        resultResponse(
          createId,
          {
            'capabilities': ['home', 'category', 'detail', 'search', 'play'],
          },
        ),
      );

      final runtime = await createFuture;
      expect(runtime, isA<JvmRuntimeAdapter>());

      // 调 home → spider.home，args 应为布尔（JVM homeContent 收 boolean）
      final homeFuture = runtime.home();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final homeFrame = processes.first.stdinSink.written[2];
      expect(extractMethod(homeFrame), 'spider.home');
      expect(utf8.decode(homeFrame), contains('"args":[false]'));

      final homeId = extractId(homeFrame);
      processes.first.stdoutCtrl.add(
        resultResponse(
          homeId,
          {
            'class': [
              {'type_id': '1', 'type_name': '电影'},
            ],
            'list': <Object?>[],
          },
        ),
      );
      final result = await homeFuture;
      if (result.isErr) {
        fail(
          'home 失败: ${result.errorOrNull?.message} '
          'written=${processes.first.stdinSink.written.length}',
        );
      }
      expect(result.isOk, isTrue);
      final body = result.valueOrNull!.body;
      expect(body, contains('"type_id": "1"'));
    });

    test('csp_ 站点在未配置 JVM 时报清晰错误', () async {
      final factory = SpiderRuntimeFactory(
        spiderJsPath: 'unused',
        hostApi: HostApi(),
      );
      addTearDown(factory.dispose);

      await expectLater(
        factory.create(typeCode: 3, api: 'csp_Fan'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('JVM 运行时未配置'),
          ),
        ),
      );
    });

    test('spider jar 下载后按 MD5 校验，不匹配报错', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..add([0x01, 0x02, 0x03])
          ..close();
      });
      final url = 'http://127.0.0.1:${server.port}/spider.jar';
      final cacheDir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'jvm_md5_test_${DateTime.now().microsecondsSinceEpoch}',
      );

      final factory = SpiderRuntimeFactory(
        spiderJsPath: 'unused',
        hostApi: HostApi(),
        jvm: SpiderJvmConfig(
          javaPath: 'java',
          runtimeJarPath: 'runtime.jar',
          libsDirPath: 'libs',
          jarCacheDir: cacheDir,
        ),
        jvmLauncher: fakeLauncher,
      );
      addTearDown(factory.dispose);

      // 先回握手，否则下载前的 start() 一直悬着
      final createFuture = factory.create(
        typeCode: 3,
        api: 'csp_Fan',
        spiderJarUrl: url,
        spiderJarMd5: 'ffffffffffffffffffffffffffffffff',
      );
      await Future<void>.delayed(Duration.zero);
      final handshakeId = extractId(processes.first.stdinSink.written.first);
      processes.first.stdoutCtrl.add(handshakeResponse(handshakeId));

      await expectLater(
        createFuture,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('MD5 不匹配'),
          ),
        ),
      );

      // 校验失败后缓存目录不应残留 jar
      final cached = cacheDir.existsSync()
          ? cacheDir.listSync().whereType<File>().toList()
          : <File>[];
      expect(cached, isEmpty);
    });
  });
}
