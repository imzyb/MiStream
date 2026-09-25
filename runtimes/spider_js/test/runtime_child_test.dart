import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:spider_js/spider_js.dart';
import 'package:spider_js/src/child/runtime_child.dart';
import 'package:spider_js/src/child/sync_frame_io.dart';
import 'package:test/test.dart';

/// 内置脚本（[type0Script]）首行注释，用来断言「跑的确实是内置脚本」。
/// 从导出常量现取，脚本改了这里自动跟着变，不会各自漂移。
final String _type0Marker = type0Script.trim().split('\n').first;

/// 驱动子进程主循环用的假管道：喂进去一串消息，收回它写出的那串。
class _Pipe {
  _Pipe(List<Map<String, Object?>> inbound) {
    inbound.forEach(_add);
  }

  final List<int> _in = <int>[];
  final List<int> _out = <int>[];
  int _cursor = 0;

  /// 主循环跑起来之后再追加消息（模拟宿主中途发来的东西）。
  void push(Map<String, Object?> msg) => _add(msg);

  /// 塞一条原样的帧体，用来喂畸形输入。
  void pushRaw(String body) {
    final bytes = utf8.encode(body);
    _in
      ..addAll(utf8.encode('Content-Length: ${bytes.length}\r\n\r\n'))
      ..addAll(bytes);
  }

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

  /// 解析子进程写出的全部消息。
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

/// 不需要 native 的假运行时，让协议层的用例在 CI 上照跑。
class _FakeRuntime implements JsRuntime {
  _FakeRuntime({this.evalHook});

  /// 每次 eval 的应答：返回 null 表示失败（配合 [failure]）。
  String? Function(String code)? evalHook;

  /// 下一次 eval 要报告的失败。
  JsEvalError? failure;

  final List<String> evaluated = <String>[];
  int cancelCount = 0;
  bool disposed = false;

  /// 真的给一个桥：这样 `installDrpyHostFunctions` 的默认路径也被这些用例走到，
  /// 而不是被一个 no-op 替身绕过去。
  @override
  final HostBridge bridge = HostBridge();

  @override
  String? eval(String code) {
    evaluated.add(code);
    return evalHook?.call(code) ?? 'null';
  }

  @override
  JsEvalError? get lastFailure => failure;

  @override
  void cancel() => cancelCount++;

  @override
  void dispose() => disposed = true;

  @override
  bool init([String? dllPath]) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> _req(int id, String method, [Map<String, Object?>? p]) =>
    <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': p ?? const <String, Object?>{},
    };

void main() {
  group('协议基本面', () {
    test('handshake 报告协议版本与能力位', () {
      final pipe = _Pipe([_req(1, 'runtime.handshake')]);
      RuntimeChild(codec: pipe.codec).run();

      final reply = pipe.written.single;
      expect(reply['id'], 1);
      final result = reply['result']! as Map<String, Object?>;
      expect(result['protocolVersion'], kProtocolVersion);
      expect(result['features'], containsAll(<String>['cancel', 'storage']));
    });

    test('ping 有回应', () {
      final pipe = _Pipe([_req(2, 'runtime.ping')]);
      RuntimeChild(codec: pipe.codec).run();
      expect(pipe.written.single['id'], 2);
    });

    test('未知方法回 METHOD_NOT_FOUND 而不是沉默', () {
      final pipe = _Pipe([_req(3, 'runtime.nope')]);
      RuntimeChild(codec: pipe.codec).run();

      final error = pipe.written.single['error']! as Map<String, Object?>;
      expect(error['code'], ErrorCode.methodNotFound.value);
    });

    test('shutdown 后主循环收工，不再处理后续消息', () {
      final pipe = _Pipe([
        _req(4, 'runtime.shutdown'),
        _req(5, 'runtime.ping'),
      ]);
      RuntimeChild(codec: pipe.codec).run();

      final written = pipe.written;
      expect(written, hasLength(1));
      expect(written.single['id'], 4);
    });

    test('通知（无 id）不产生回话', () {
      final pipe = _Pipe([
        <String, Object?>{
          'jsonrpc': '2.0',
          'method': 'host.networkChanged',
          'params': <String, Object?>{'online': true},
        },
        _req(6, 'runtime.ping'),
      ]);
      RuntimeChild(codec: pipe.codec).run();

      expect(pipe.written.single['id'], 6);
    });

    test('畸形 JSON 被跳过，不影响后续消息', () {
      final pipe = _Pipe([])
        ..pushRaw('{这不是 JSON')
        ..pushRaw('[1,2,3]') // 合法 JSON 但不是消息对象
        ..push(_req(7, 'runtime.ping'));
      RuntimeChild(codec: pipe.codec).run();

      // 两条垃圾都不该产生回话，也不该把主循环带崩。
      expect(pipe.written.single['id'], 7);
    });

    test('每条请求恰好换来一条回话', () {
      final pipe = _Pipe([
        _req(1, 'runtime.ping'),
        _req(2, 'runtime.handshake'),
        _req(3, 'runtime.stats'),
        _req(4, 'runtime.nope'),
      ]);
      RuntimeChild(codec: pipe.codec).run();

      // 少回一条，宿主那边就是一个永不 complete 的 Future。
      expect(pipe.written.map((m) => m['id']), <int>[1, 2, 3, 4]);
    });
  });

  group('实例管理', () {
    test('create 缺 script 报 SCRIPT_LOAD_FAILED', () {
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{'instanceId': 'site:1'}),
      ]);
      RuntimeChild(
        codec: pipe.codec,
        createRuntime: (_) => _FakeRuntime(),
      ).run();

      final error = pipe.written.single['error']! as Map<String, Object?>;
      expect(error['code'], ErrorCode.scriptLoadFailed.value);
    });

    test("builtin='type0' 且不传 script 时用内置通用脚本建实例", () {
      final fake = _FakeRuntime();
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'builtin': 'type0',
        }),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      expect(
        pipe.written.single.containsKey('error'),
        isFalse,
        reason:
            'type=0 的 api 是站点地址而非脚本路径，宿主无从加载脚本，'
            '必须由子进程用内置脚本兜底',
      );
      expect(
        fake.evaluated.any((c) => c.contains(_type0Marker)),
        isTrue,
        reason: '求值过的代码里应当出现内置脚本正文',
      );
    });

    test("builtin='type0' 配空 script 同样走内置", () {
      final fake = _FakeRuntime();
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'builtin': 'type0',
          'script': '',
        }),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      expect(pipe.written.single.containsKey('error'), isFalse);
      expect(fake.evaluated.any((c) => c.contains(_type0Marker)), isTrue);
    });

    test('script 非空时优先于 builtin（内置只是兜底）', () {
      final fake = _FakeRuntime();
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'builtin': 'type0',
          'script': 'function home(){ return {list:[]}; }',
        }),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      expect(
        fake.evaluated.any((c) => c.contains('function home(){ return')),
        isTrue,
      );
      expect(
        fake.evaluated.any((c) => c.contains(_type0Marker)),
        isFalse,
        reason: '宿主已经给了脚本，就不该再执行内置脚本',
      );
    });

    test("builtin 是不认识的值时仍然报 SCRIPT_LOAD_FAILED", () {
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'builtin': 'type9',
        }),
      ]);
      RuntimeChild(
        codec: pipe.codec,
        createRuntime: (_) => _FakeRuntime(),
      ).run();

      final error = pipe.written.single['error']! as Map<String, Object?>;
      expect(error['code'], ErrorCode.scriptLoadFailed.value);
    });

    test('create 成功后返回探测到的能力位', () {
      final fake = _FakeRuntime(
        evalHook: (code) =>
            code.contains('typeof home') ? 'home,search' : 'null',
      );
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'function home(){} function search(){}',
        }),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      final result = pipe.written.single['result']! as Map<String, Object?>;
      expect(result['capabilities'], <String>['home', 'search']);
    });

    test('对不存在的实例调用报错', () {
      final pipe = _Pipe([
        _req(1, 'spider.search', <String, Object?>{'instanceId': '不存在'}),
      ]);
      RuntimeChild(
        codec: pipe.codec,
        createRuntime: (_) => _FakeRuntime(),
      ).run();

      final error = pipe.written.single['error']! as Map<String, Object?>;
      expect(error['code'], ErrorCode.invalidState.value);
    });

    test('destroy 释放实例', () {
      final fake = _FakeRuntime();
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        _req(2, 'spider.destroy', <String, Object?>{'instanceId': 'site:1'}),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      expect(fake.disposed, isTrue);
      expect(pipe.written, hasLength(2));
    });

    test('limits 从 RPC 参数映射到 JsRuntimeLimits', () {
      JsRuntimeLimits? captured;
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
          'limits': <String, Object?>{'timeoutMs': 2500, 'memoryMB': 32},
        }),
      ]);
      RuntimeChild(
        codec: pipe.codec,
        createRuntime: (limits) {
          captured = limits;
          return _FakeRuntime();
        },
      ).run();

      expect(captured?.evalTimeout, const Duration(milliseconds: 2500));
      expect(captured?.memoryBytes, 32 * 1024 * 1024);
    });
  });

  group('Spider 调用', () {
    test('参数按 JSON 编码后拼进调用表达式', () {
      final fake = _FakeRuntime(
        evalHook: (code) =>
            code.contains('typeof search') ? '[{"vod_id":"1"}]' : 'null',
      );
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        _req(2, 'spider.search', <String, Object?>{
          'instanceId': 'site:1',
          'args': <Object?>['海贼王', false],
        }),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      expect(
        fake.evaluated.any((c) => c.contains('search("海贼王", false)')),
        isTrue,
        reason: '实际求值：${fake.evaluated}',
      );
      final result = pipe.written.last['result']! as List<Object?>;
      expect((result.single! as Map<String, Object?>)['vod_id'], '1');
    });

    test('脚本异常带着错误码与堆栈上抛', () {
      final fake = _FakeRuntime(evalHook: (_) => null)
        ..failure = const JsEvalError(
          code: ErrorCode.scriptRuntimeError,
          message: '炸了',
          stack: '  at search',
        );
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        _req(2, 'spider.search', <String, Object?>{'instanceId': 'site:1'}),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      final error = pipe.written.last['error']! as Map<String, Object?>;
      expect(error['code'], ErrorCode.scriptRuntimeError.value);
      expect(error['message'], contains('炸了'));
      expect((error['data']! as Map<String, Object?>)['stack'], '  at search');
    });

    test('home 合并 homeVod，一次返回 {class, list}', () {
      const merged =
          '{"class":[{"type_id":"1","type_name":"电影"}],'
          '"list":[{"vod_id":"1","vod_name":"片"}]}';
      final fake = _FakeRuntime(
        evalHook: (code) => code.contains('typeof home') ? merged : 'null',
      );
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        _req(2, 'spider.home', <String, Object?>{'instanceId': 'site:1'}),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      // 宿主约定：home 一次调用返回 {class, list}（drpy 把两者拆在
      // home() 和 homeVod() 里，两个都要 await——源里 async 很常见）。
      expect(
        fake.evaluated.any((c) => c.contains('await homeVod(')),
        isTrue,
      );
      final result = pipe.written.last['result']! as Map<String, Object?>;
      expect(result, containsPair('class', isNotEmpty));
      expect(result, containsPair('list', isNotEmpty));
    });

    test('spider.detail 带两个参数路由到 category, 一个参数路由到 detail', () {
      final fake = _FakeRuntime(
        evalHook: (code) {
          if (code.contains('await category(')) {
            return '{"list":[]}';
          }
          return 'null';
        },
      );
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        // [tid, page] 是分类列表 → category(tid, pg)
        _req(2, 'spider.detail', <String, Object?>{
          'instanceId': 'site:1',
          'args': <Object?>['1', 1],
        }),
        // [ids] 是视频详情 → detail(ids)
        _req(3, 'spider.detail', <String, Object?>{
          'instanceId': 'site:1',
          'args': <Object?>['1001'],
        }),
      ]);
      RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake).run();

      expect(
        fake.evaluated.any((c) => c.contains('category("1", 1)')),
        isTrue,
        reason: '两参 detail 应路由到 category：$fake.evaluated',
      );
      expect(
        fake.evaluated.any((c) => c.contains('detail("1001")')),
        isTrue,
        reason: '单参 detail 应路由到 detail：$fake.evaluated',
      );
    });
  });

  group('宿主回调的重入与取消', () {
    /// 装一个会调 callHost 的宿主函数，模拟脚本里的 req。
    ///
    /// 匹配条件要精确到 `await search(`：`spider.create` 的能力探测表达式里
    /// 也有 `typeof search`，按它匹配的话建实例时就会触发宿主调用。
    RuntimeChild childCallingHost(
      _Pipe pipe,
      _FakeRuntime fake, {
      required void Function(HostCallOutcome outcome) onOutcome,
    }) {
      final child = RuntimeChild(codec: pipe.codec, createRuntime: (_) => fake);
      fake.evalHook = (code) {
        if (code.contains('await search(')) {
          onOutcome(
            child.callHost('host.fetch', <String, Object?>{'url': 'x'}),
          );
          return '"ok"';
        }
        return '';
      };
      return child;
    }

    test('宿主回话被正确匹配回发起的那次调用', () {
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        _req(2, 'spider.search', <String, Object?>{'instanceId': 'site:1'}),
        // 子进程发出的第一条出站请求 id 是 1。
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'result': <String, Object?>{'body': '响应体'},
        },
      ]);

      HostCallOutcome? got;
      final fake = _FakeRuntime();
      childCallingHost(pipe, fake, onOutcome: (o) => got = o).run();

      expect((got!.result! as Map<String, Object?>)['body'], '响应体');
      expect(got?.error, isNull);
    });

    // 这条守的是重入：等回话期间来的别的请求不能就地处理（此刻 C 栈还停在
    // JS_Eval 里），但也不能丢——必须排到本次调用之后。
    test('等待期间到达的其它请求被推迟，不被丢弃', () {
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        _req(2, 'spider.search', <String, Object?>{'instanceId': 'site:1'}),
        _req(3, 'runtime.ping'),
        <String, Object?>{'jsonrpc': '2.0', 'id': 1, 'result': null},
      ]);

      final fake = _FakeRuntime();
      childCallingHost(pipe, fake, onOutcome: (_) {}).run();

      final ids = pipe.written.map((m) => m['id']).toList();
      // 出站的 host.fetch 也带 id 1，所以按顺序应是：create 回话(1)、
      // host.fetch 请求(1)、search 回话(2)、被推迟的 ping 回话(3)。
      expect(ids.last, 3, reason: '被推迟的请求最终要被处理：$ids');
      expect(pipe.written.last['result'], isNotNull);
    });

    test('等待期间的取消立刻掐断脚本', () {
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        _req(2, 'spider.search', <String, Object?>{'instanceId': 'site:1'}),
        <String, Object?>{
          'jsonrpc': '2.0',
          'method': r'$/cancelRequest',
          'params': <String, Object?>{'id': 2},
        },
        <String, Object?>{'jsonrpc': '2.0', 'id': 1, 'result': null},
      ]);

      final fake = _FakeRuntime();
      childCallingHost(pipe, fake, onOutcome: (_) {}).run();

      expect(fake.cancelCount, greaterThan(0), reason: '取消没有传导到 runtime');
    });

    test('取消别的请求不误伤当前在途的调用', () {
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        _req(2, 'spider.search', <String, Object?>{'instanceId': 'site:1'}),
        <String, Object?>{
          'jsonrpc': '2.0',
          'method': r'$/cancelRequest',
          // 取消的是另一条请求，与在途的 id=2 无关。
          'params': <String, Object?>{'id': 999},
        },
        <String, Object?>{'jsonrpc': '2.0', 'id': 1, 'result': null},
      ]);

      final fake = _FakeRuntime();
      childCallingHost(pipe, fake, onOutcome: (_) {}).run();

      expect(fake.cancelCount, 0);
    });

    test('等回话时管道断了，主循环干净退出而不是抛出去', () {
      final pipe = _Pipe([
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'var a=1',
        }),
        _req(2, 'spider.search', <String, Object?>{'instanceId': 'site:1'}),
        // 故意不给回话，输入到此为止。
      ]);

      final fake = _FakeRuntime();
      final child = childCallingHost(pipe, fake, onOutcome: (_) {});
      expect(child.run, returnsNormally);
    });
  });

  /// 生成表达式从「三元 + JSON.stringify」改成 async IIFE（为了 `await` 异步入口），
  /// 这一组守住**同步 drpy 脚本照旧能跑**——真实存量源绝大多数是同步的，把它们的
  /// 返回值格式改坏，比异步源不能用严重得多。
  ///
  /// 用真 [JsRuntime]，但把宿主函数换成空实现（不装 `req`，脚本也不调它），
  /// 所以不需要回环端口，在本沙箱能跑。
  group('真实运行时下的调用表达式（同步 drpy 脚本回归）', () {
    const script = '''
function home() {
  return JSON.stringify({
    class: [{ type_id: "1", type_name: "电影" }],
    list: [{ vod_id: "1", vod_name: "片" }]
  });
}
function search(wd) { return JSON.stringify({ list: [{ vod_id: "s1", vod_name: wd }] }); }
function detail(ids) { return JSON.stringify({ list: [{ vod_id: ids }] }); }
function homeVod() { return JSON.stringify({ list: [{ vod_id: "hv", vod_name: "推荐" }] }); }
''';

    List<Object?> run(List<Map<String, Object?>> calls) {
      final pipe = _Pipe(<Map<String, Object?>>[
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': script,
        }),
        for (var i = 0; i < calls.length; i++)
          Map<String, Object?>.from(calls[i])..['id'] = i + 2,
      ]);
      final child = RuntimeChild(
        codec: pipe.codec,
        installHostFunctions: (_, _, _) {},
      );
      child.run();
      // 不释放的话 HostBridge 的 NativeCallable 会把进程钉住不退出。
      child.dispose();
      return pipe.written.map((m) => m['result']).skip(1).toList();
    }

    /// 把一次调用的结果归一成 Map。
    ///
    /// `_invokeSpider` 会 `jsonDecode` 脚本返回值一次：脚本返回 JSON 字符串时
    /// 拿到的是那个**字符串**（表达式里已经 stringify 过一遍），返回对象时拿到
    /// Map。两种约定在下游 `parseSpiderResult._encodeBody` 会收敛到同一个 body
    /// （`String` 原样透出、`Map` 才 `jsonEncode`），所以断言前统一一次。
    Map<String, Object?> asMap(Object? value) {
      if (value is Map) return value.cast<String, Object?>();
      if (value is String) {
        return (jsonDecode(value) as Map).cast<String, Object?>();
      }
      throw StateError('既不是 Map 也不是 JSON 字符串: $value');
    }

    test('home 合并 homeVod 后返回 {class, list}', () {
      final result = asMap(
        run(<Map<String, Object?>>[
          _req(0, 'spider.home', <String, Object?>{'instanceId': 'site:1'}),
        ]).single,
      );

      expect((result['class']! as List), hasLength(1));
      // homeVod 在后、覆盖 list —— 这是宿主的约定，别改顺序。
      final list = (result['list']! as List).cast<Map<String, Object?>>();
      expect(list.single['vod_id'], 'hv');
    });

    test('search 的参数按位置传到脚本', () {
      final result = asMap(
        run(<Map<String, Object?>>[
          _req(0, 'spider.search', <String, Object?>{
            'instanceId': 'site:1',
            'args': <Object?>['海贼王', false, 1],
          }),
        ]).single,
      );

      final list = (result['list']! as List).cast<Map<String, Object?>>();
      expect(list.single['vod_name'], '海贼王');
    });

    test('detail 的字符串 ids 原样传给脚本', () {
      final result = asMap(
        run(<Map<String, Object?>>[
          _req(0, 'spider.detail', <String, Object?>{
            'instanceId': 'site:1',
            'args': <Object?>['1001'],
          }),
        ]).single,
      );

      final list = (result['list']! as List).cast<Map<String, Object?>>();
      // 曾经按数组取 `ids[0]`，字符串会退化成首字符。
      expect(list.single['vod_id'], '1001');
    });

    test('脚本抛异常时如实上报，不退化成空结果', () {
      final pipe = _Pipe(<Map<String, Object?>>[
        _req(1, 'spider.create', <String, Object?>{
          'instanceId': 'site:1',
          'script': 'function search() { throw new Error("炸了"); }',
        }),
        _req(2, 'spider.search', <String, Object?>{'instanceId': 'site:1'}),
      ]);
      final child = RuntimeChild(
        codec: pipe.codec,
        installHostFunctions: (_, _, _) {},
      );
      child.run();
      child.dispose();

      final error = pipe.written.last['error']! as Map<String, Object?>;
      expect(error['code'], ErrorCode.scriptRuntimeError.value);
      expect(error['message'], contains('炸了'));
    });
  }, skip: isQuickJSAvailable ? null : 'QuickJS native 不可用，跳过');
}
