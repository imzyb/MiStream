/// type=3 端到端集成测试：把 mock_source_server 提供的 drpy2 脚本喂给
/// 真实的 Spider JS 运行时（子进程或 in-process），并通过 `HostApi`
/// 真的 HTTP 抓取验证整条链路：
///
///   spider.js → RuntimeChild.create → home() → host.fetch → mock /api.php
///                                                            ↓
///                                                      home 响应 → 详情
///                                                            ↓
///                                                      play() → 直链
///
/// 跑这条测试需要本机有可用的 QuickJS DLL（Windows）或库（Linux/macOS）。
/// DLL 缺失时整个 group 被跳过（`setUpAll` 里的 `skip`），CI 上普通
/// 单元测试照跑——这与 `runtime_child_test.dart` 的策略一致。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mock_source_server/mock_source_server.dart';
import 'package:spider_host/spider_host.dart';
import 'package:spider_js/spider_js.dart';
import 'package:spider_js/src/child/runtime_child.dart';
import 'package:spider_js/src/child/sync_frame_io.dart';
import 'package:test/test.dart';

/// 把内容长度帧化写入字节流（与子进程的 framing 一致）。
void _writeFrame(IOSink sink, String body) {
  final bytes = utf8.encode(body);
  // 用 add 直接写字节，跟子进程 [SyncFrameCodec] 期望的字节流严格一致。
  // 走 sink.write()（字符串）会被按当前 locale 编码，某些 Windows 配置下
  // 会把多字节字符拆错位，frame header 解析就会失败。
  sink
    ..add(utf8.encode('Content-Length: ${bytes.length}\r\n\r\n'))
    ..add(bytes);
}

/// 共享的子进程 stdout 读取器：从字节流里按 Content-Length 帧切分消息。
///
/// 一次性把整个 stdout drain 到内存（脚本只跑一条链路的几条消息，量很小），
/// 然后在内存里切帧。直接用 `StreamIterator` 会撞上单订阅流的限制——每
/// 次 `_readFrame` 都会新建 `expand`，但 `stream.expand` 返回的是 single-
/// subscription stream，第二次拿不到东西。
class _FrameReader {
  _FrameReader(Stream<List<int>> stream) {
    _sub = stream.listen(
      _buffer.addAll,
      onDone: () => _closed = true,
    );
  }

  late final StreamSubscription<List<int>> _sub;
  final List<int> _buffer = <int>[];
  bool _closed = false;

  /// 等到至少有一帧可用，再读出来。返回 UTF-8 解码后的 body。
  Future<String> next() async {
    while (true) {
      final frame = _tryTake();
      if (frame != null) return frame;
      if (_closed) {
        throw const FormatException('Child closed before frame ready');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  String? _tryTake() {
    final sep = utf8.encode('\r\n\r\n');
    var headerEnd = -1;
    outer:
    for (var i = 0; i + sep.length <= _buffer.length; i++) {
      for (var j = 0; j < sep.length; j++) {
        if (_buffer[i + j] != sep[j]) continue outer;
      }
      headerEnd = i;
      break;
    }
    if (headerEnd < 0) return null;

    final headerText = utf8.decode(_buffer.sublist(0, headerEnd));
    final match = RegExp(
      r'Content-Length:\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(headerText);
    if (match == null) {
      throw FormatException('Missing Content-Length: $headerText');
    }
    final length = int.parse(match.group(1)!);
    final bodyStart = headerEnd + sep.length;
    if (_buffer.length < bodyStart + length) return null;

    final body = utf8.decode(_buffer.sublist(bodyStart, bodyStart + length));
    _buffer.removeRange(0, bodyStart + length);
    return body;
  }

  Future<void> close() async {
    await _sub.cancel();
  }
}

/// 读一个帧（Content-Length + body）。
Future<String> _readFrame(_FrameReader reader) => reader.next();

/// 子进程路径：到 `build/spider_js/` 或当前路径下找。
File? _findBundleExecutable() {
  final s = Platform.pathSeparator;
  const exe = 'spider_js_runtime.exe';
  // Dart 进程的真实 cwd。`dart test` 与 `flutter test` 都会切到包根目录，
  // 从仓库根直接 `dart test runtimes/spider_js/test/...` 时 cwd 就是根，
  // 因此既要看相对路径也要看包内的相对路径。
  final cwd = Directory.current.path;
  final candidates = <String>[
    '$cwd${s}build${s}spider_js$s$exe',
    '$cwd${s}build${s}windows${s}x64${s}runner${s}Release$s$exe',
    '$cwd${s}build${s}windows${s}x64${s}runner${s}Debug$s$exe',
    'build$s{Platform.pathSeparator}spider_js$s$exe',
    'build${s}windows${s}x64${s}runner${s}Release$s$exe',
    'build${s}windows${s}x64${s}runner${s}Debug$s$exe',
  ];
  for (final p in candidates) {
    final f = File(p);
    if (f.existsSync()) return f;
  }
  return null;
}

Future<String> _httpGet(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final req = await client.getUrl(Uri.parse(url));
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  client.close(force: true);
  return body;
}

Map<String, Object?> _req(int id, String method, [Map<String, Object?>? p]) =>
    <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': p ?? const <String, Object?>{},
    };

/// JSON-RPC 消息（`jsonDecode` 出来的 `Map<String, Object?>` 的轻量包装）。
///
/// 字段全部可空，避免对动态 JSON 做 `!` / 类型断言——多数字段对测试来说
/// 都不需要区分 null 还是缺失。
class _RpcMessage {
  _RpcMessage._(this.map);
  factory _RpcMessage.decode(String raw) {
    final decoded = jsonDecode(raw);
    return _RpcMessage._(
      decoded is Map<String, Object?> ? decoded : <String, Object?>{},
    );
  }
  final Map<String, Object?> map;

  Object? get id => map['id'];
  String? get method {
    final m = map['method'];
    return m is String ? m : null;
  }

  Object? get result => map['result'];
  Object? get error => map['error'];
  bool get isHostCall => method != null && method!.startsWith('host.');
  bool get hasResult => map.containsKey('result');
  bool get hasError => map.containsKey('error');

  Map<String, Object?> get params => map['params'] is Map<String, Object?>
      ? map['params']! as Map<String, Object?>
      : <String, Object?>{};
}

void main() {
  final bundle = _findBundleExecutable();
  final canSpawnSubprocess =
      bundle != null &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  group('type=3 端到端（in-process RuntimeChild + 真 HostApi）', () {
    late MockSourceServer mock;
    late String scriptText;

    setUpAll(() async {
      mock = MockSourceServer();
      await mock.start();
      scriptText = await _httpGet(mock.spiderJsUrl);
    });

    tearDownAll(() async {
      await mock.close();
    });

    test('脚本可被拉取并包含 Spider 入口函数', () {
      expect(scriptText, contains('function home('));
      expect(scriptText, contains('function detail('));
      expect(scriptText, contains('function play('));
    });

    test('RuntimeChild 加载脚本后报能力位', () {
      // 不接宿主，单次评估脚本即可；不需要真 QuickJS 因为我们用 _FakeRuntime。
      // 真正的 JS 求值由下面的子进程测试覆盖。
      final fake = _RecordingFakeRuntime(
        evalHook: (code) =>
            code.contains('typeof home') ? 'home,detail,play' : 'null',
      );
      final pipe = _RecordingPipe(<Map<String, Object?>>[
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:mock',
          'script': scriptText,
        }),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      final reply = pipe.written.single;
      expect(reply['id'], 1);
      final result = reply['result']! as Map<String, Object?>;
      expect(result['capabilities'], <String>['home', 'detail', 'play']);
    });
  });

  // 跑真 QuickJS 子进程的 group——需要 build/spider_js/ 下的 bundle。
  // 没有就跳过，不让 CI 在没装 DLL 的机器上挂掉。
  group('type=3 端到端（子进程 + 真 HostApi + mock 源）', () {
    late MockSourceServer mock;
    late Process process;
    late HostApi hostApi;
    late IOSink stdin;
    late _FrameReader stdoutReader;

    setUpAll(() async {
      if (!canSpawnSubprocess) {
        return;
      }
      mock = MockSourceServer();
      await mock.start();
      hostApi = HostApi(
        config: HostFetchConfig(allowedHosts: const ['127.0.0.1']),
      );
      final s = Platform.pathSeparator;
      final exe = bundle.path;
      final workingDir = exe.substring(0, exe.lastIndexOf(s));
      process = await Process.start(
        exe,
        const [],
        workingDirectory: workingDir,
      );
      stdin = process.stdin;
      stdoutReader = _FrameReader(process.stdout);
    });

    tearDownAll(() async {
      if (!canSpawnSubprocess) return;
      try {
        stdin.writeln();
        await stdin.flush();
      } on Object {
        // 进程可能已经死了
      }
      await stdoutReader.close();
      process.kill();
      await mock.close();
    });

    test('整条链路：init → home → detail → play 命中 mock 端点', () async {
      if (!canSpawnSubprocess) {
        markTestSkipped('Spider JS bundle 不存在，跳过子进程集成测试');
        return;
      }

      // 1. 拉脚本内容
      final script = await _httpGet(mock.spiderJsUrl);

      // 2. handshake
      _writeFrame(
        stdin,
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'runtime.handshake',
          'params': <String, Object?>{},
        }),
      );
      await stdin.flush();
      final handshakeReply = _RpcMessage.decode(
        await _readFrame(stdoutReader),
      );
      expect(handshakeReply.id, 1);
      expect(handshakeReply.hasResult, isTrue);

      // 3. spider.create（脚本 = spider.js 内容，ext = mock 的 /api.php URL）
      _writeFrame(
        stdin,
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'spider.create',
          'params': <String, Object?>{
            'instanceId': 'site:mock',
            'script': script,
            'config': mock.apiUrl,
            'baseUrl': mock.baseUrl,
          },
        }),
      );
      await stdin.flush();
      final createReply = _RpcMessage.decode(
        await _readFrame(stdoutReader),
      );
      expect(createReply.id, 2);
      expect(
        createReply.hasError,
        isFalse,
        reason: 'create 出错：${createReply.map}',
      );

      // 4. spider.home —— 脚本内部用 host.fetch 抓 /api.php?ac=videolist
      //    我们必须同步帮它回 host.fetch，否则子进程在 callHost 里死等。
      final homeResult = await _runSpiderAndServeFetches(
        method: 'home',
        args: <Object?>[null],
        stdin: stdin,
        reader: stdoutReader,
        hostApi: hostApi,
      );
      final homeBody = homeResult;
      expect(homeBody, isA<Map<String, Object?>>());
      final homeMap = homeBody! as Map<String, Object?>;
      final homeList = homeMap['list'] as List<Object?>?;
      expect(homeList, isNotEmpty, reason: 'home 应返回非空列表：$homeMap');
      expect(homeMap['class'], isNotEmpty);

      // 5. spider.detail
      final detailResult = await _runSpiderAndServeFetches(
        method: 'detail',
        args: <Object?>['1001'],
        stdin: stdin,
        reader: stdoutReader,
        hostApi: hostApi,
      );
      final detailBody = detailResult;
      expect(detailBody, isA<Map<String, Object?>>());
      final detailList =
          (detailBody! as Map<String, Object?>)['list'] as List<Object?>?;
      expect(detailList, isNotEmpty);
      final firstItem = detailList!.first! as Map<String, Object?>;
      expect(firstItem['vod_name'], '测试电影');

      // 6. spider.play
      final playResult = await _runSpiderAndServeFetches(
        method: 'play',
        args: <Object?>['qiyi', '1001', null],
        stdin: stdin,
        reader: stdoutReader,
        hostApi: hostApi,
      );
      final playBody = playResult;
      expect(playBody, isA<Map<String, Object?>>());
      final playMap = playBody! as Map<String, Object?>;
      expect(playMap['url'], contains('qiyi/1001/index.m3u8'));
      expect(playMap['parse'], 0);

      // 7. 收尾
      _writeFrame(
        stdin,
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': 99,
          'method': 'runtime.shutdown',
        }),
      );
      await stdin.flush();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

/// 调一次 `spider.<method>`，过程中把子进程发来的 host.fetch / host.storage
/// 全部异步喂给 `hostApi`，再把结果回给子进程。返回该方法的结果对象
/// （已经是 Dart 侧的 `Map` / `List` / 原生值，调用方按需断言）。
Future<Object?> _runSpiderAndServeFetches({
  required String method,
  required List<Object?> args,
  required IOSink stdin,
  required _FrameReader reader,
  required HostApi hostApi,
}) async {
  const nextId = 100;
  _writeFrame(
    stdin,
    jsonEncode(<String, Object?>{
      'jsonrpc': '2.0',
      'id': nextId,
      'method': 'spider.$method',
      'params': <String, Object?>{
        'instanceId': 'site:mock',
        'args': args,
      },
    }),
  );
  await stdin.flush();

  // 在子进程跑 `spider.$method` 时，它会发出 1..N 个 host.fetch。
  // 我们必须把它们都接住、转给 hostApi、把结果回给子进程。
  // 子进程最终会回那条 id=nextId 的 RPC reply —— 那就是我们要的。
  while (true) {
    final msg = _RpcMessage.decode(await _readFrame(reader));

    if (msg.id == nextId) {
      // 这就是 spider.$method 的最终回话。
      return msg.result;
    }

    if (msg.isHostCall) {
      final id = msg.id;
      final (result, error) = await hostApi.handle(msg.method!, msg.params);
      _writeFrame(
        stdin,
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          if (error != null) 'error': error else 'result': result,
        }),
      );
      await stdin.flush();
      continue;
    }

    // 其它消息（通知等）直接忽略
  }
}

/// 用来在 in-process 测里代替真 QuickJS：把 eval 调用钩出来给一个固定返回值。
class _RecordingFakeRuntime implements JsRuntime {
  _RecordingFakeRuntime({this.evalHook});

  String? Function(String code)? evalHook;

  @override
  final HostBridge bridge = HostBridge();

  @override
  String? eval(String code) => evalHook?.call(code) ?? 'null';

  @override
  JsEvalError? get lastFailure => null;

  @override
  void cancel() {}

  @override
  void dispose() {}

  @override
  bool init([String? dllPath]) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 一个双向字节缓冲管道，模仿 `runtime_child_test.dart` 的 `_Pipe`。
class _RecordingPipe {
  _RecordingPipe(List<Map<String, Object?>> inbound) {
    inbound.forEach(_add);
  }

  final List<int> _in = <int>[];
  final List<int> _out = <int>[];
  int _cursor = 0;

  void _add(Map<String, Object?> msg) {
    final body = utf8.encode(jsonEncode(msg));
    _in
      ..addAll(utf8.encode('Content-Length: ${body.length}\r\n\r\n'))
      ..addAll(body);
  }

  SyncFrameCodec get codec => SyncFrameCodec(
    readByte: () => _cursor < _in.length ? _in[_cursor++] : -1,
    write: _out.addAll,
  );

  List<Map<String, Object?>> get written {
    final reader = SyncFrameCodec(readByte: _readOut());
    final out = <Map<String, Object?>>[];
    for (;;) {
      final raw = reader.readFrame();
      if (raw == null) return out;
      out.add(jsonDecode(raw) as Map<String, Object?>);
    }
  }

  int Function() _readOut() {
    var i = 0;
    return () => i < _out.length ? _out[i++] : -1;
  }
}
