import 'dart:convert';

import 'package:spider_js/spider_js.dart';
import 'package:spider_js/src/child/drpy_host_functions.dart';
import 'package:spider_js/src/child/runtime_child.dart';
import 'package:spider_js/src/child/sync_frame_io.dart';
import 'package:test/test.dart';

/// 一个可编程的假宿主：按方法名给回话，并记下收到的请求。
class _FakeHost {
  _FakeHost(this.replies);

  /// 方法名 → 回话构造器。返回 `(result, error)`。
  final Map<String, (Object?, Object?) Function(Map<String, Object?> params)>
  replies;

  final List<Map<String, Object?>> received = <Map<String, Object?>>[];
  final List<int> _out = <int>[];

  /// 子进程写出来的字节先进这里，我们据此产生回话；再从 [_in] 读回去。
  final List<int> _in = <int>[];
  int _cursor = 0;

  late final SyncFrameCodec codec = SyncFrameCodec(
    readByte: () => _cursor < _in.length ? _in[_cursor++] : -1,
    write: _onWrite,
  );

  void pushInbound(Map<String, Object?> msg) {
    final body = utf8.encode(jsonEncode(msg));
    _in
      ..addAll(utf8.encode('Content-Length: ${body.length}\r\n\r\n'))
      ..addAll(body);
  }

  /// 子进程每写出一条完整帧就立刻应答——模拟宿主的即时回话。
  void _onWrite(List<int> bytes) {
    _out.addAll(bytes);
    _drain();
  }

  void _drain() {
    for (;;) {
      final frame = _takeFrame();
      if (frame == null) return;
      final msg = jsonDecode(frame) as Map<String, Object?>;
      final method = msg['method'];
      final id = msg['id'];
      if (method is! String || id is! int) continue; // 是回话，不是请求

      received.add(msg);
      final reply = replies[method];
      if (reply == null) {
        pushInbound(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'error': <String, Object?>{
            'code': -32601,
            'message': '假宿主没实现 $method',
          },
        });
        continue;
      }
      final params = msg['params'] is Map<String, Object?>
          ? msg['params']! as Map<String, Object?>
          : const <String, Object?>{};
      final (result, error) = reply(params);
      pushInbound(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        if (error != null) 'error': error else 'result': result,
      });
    }
  }

  /// 从已写出的字节里取一条完整帧，不足则返回 null。
  String? _takeFrame() {
    final text = utf8.decode(_out, allowMalformed: true);
    final headerEnd = text.indexOf('\r\n\r\n');
    if (headerEnd < 0) return null;

    final match = RegExp(
      r'Content-Length:\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(text.substring(0, headerEnd));
    if (match == null) return null;

    final length = int.parse(match.group(1)!);
    final bodyStart = utf8.encode(text.substring(0, headerEnd + 4)).length;
    if (_out.length < bodyStart + length) return null;

    final body = utf8.decode(_out.sublist(bodyStart, bodyStart + length));
    _out.removeRange(0, bodyStart + length);
    return body;
  }
}

/// 只实现 A4 需要的那点表面，其余交给 noSuchMethod。
class _FakeRuntime implements JsRuntime {
  @override
  final HostBridge bridge = HostBridge();

  @override
  String? eval(String code) => '';

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

/// 建一个装好 drpy 宿主函数的桥，直接调它的 handler 就等于「脚本调了 req」。
({HostBridge bridge, _FakeHost host}) wired({
  required Map<String, (Object?, Object?) Function(Map<String, Object?>)>
  replies,
}) {
  final host = _FakeHost(replies);
  final runtime = _FakeRuntime();
  final child = RuntimeChild(codec: host.codec, createRuntime: (_) => runtime);
  installDrpyHostFunctions(runtime, 'site:7', child);
  return (bridge: runtime.bridge, host: host);
}

void main() {
  group('req 走 host.fetch', () {
    test('响应体映射成 drpy 的 content/headers/code/url', () {
      final w = wired(
        replies: {
          'host.fetch': (_) => (
            <String, Object?>{
              'status': 200,
              'headers': <String, Object?>{'set-cookie': 'a=1'},
              'body': '<html>海贼王</html>',
              'finalUrl': 'https://s.com/after-redirect',
              'elapsedMs': 12,
            },
            null,
          ),
        },
      );

      final out = w.bridge.invoke('req', <Object?>['https://s.com/x', null]);
      final result = out['v']! as Map<String, Object?>;
      expect(result['content'], '<html>海贼王</html>');
      expect(result['code'], 200);
      expect(result['url'], 'https://s.com/after-redirect');
      expect(
        (result['headers']! as Map<String, Object?>)['set-cookie'],
        'a=1',
      );
    });

    test('options 映射到 host.fetch 的参数，并带上 instanceId', () {
      final w = wired(
        replies: {
          'host.fetch': (_) => (<String, Object?>{'body': ''}, null),
        },
      );

      w.bridge.invoke('req', <Object?>[
        'https://s.com/x',
        <String, Object?>{
          'method': 'post',
          'headers': <String, Object?>{'User-Agent': 'MiStream'},
          'body': 'k=v',
          'timeout': 3000,
        },
      ]);

      final params = w.host.received.single['params']! as Map<String, Object?>;
      expect(params['instanceId'], 'site:7');
      expect(params['url'], 'https://s.com/x');
      // 大小写归一：真实源里 method 写小写的很常见。
      expect(params['method'], 'POST');
      expect(params['body'], 'k=v');
      expect(params['timeoutMs'], 3000);
      expect(
        (params['headers']! as Map<String, Object?>)['User-Agent'],
        'MiStream',
      );
    });

    test('buffer:true 请求二进制响应', () {
      final w = wired(
        replies: {
          'host.fetch': (_) => (<String, Object?>{'body': ''}, null),
        },
      );

      w.bridge.invoke('req', <Object?>[
        'https://s.com/i.jpg',
        <String, Object?>{'buffer': true},
      ]);

      final params = w.host.received.single['params']! as Map<String, Object?>;
      expect(params['responseType'], 'buffer');
    });

    test('缺省 options 时按 GET/text 走', () {
      final w = wired(
        replies: {
          'host.fetch': (_) => (<String, Object?>{'body': ''}, null),
        },
      );

      w.bridge.invoke('req', <Object?>['https://s.com/x']);

      final params = w.host.received.single['params']! as Map<String, Object?>;
      expect(params['method'], 'GET');
      expect(params['responseType'], 'text');
      expect(params['redirect'], true);
    });

    // 宿主拦截（SSRF、白名单）走的就是这条路，脚本必须看得见失败。
    test('宿主报错变成脚本里的异常', () {
      final w = wired(
        replies: {
          'host.fetch': (_) => (
            null,
            <String, Object?>{'code': -32201, 'message': '私网地址被拦截'},
          ),
        },
      );

      final out = w.bridge.invoke('req', <Object?>['http://127.0.0.1/x']);
      expect(out['v'], isNull);
      expect(out['e'], contains('私网地址被拦截'));
    });

    test('宿主没实现该方法也是异常，不是静默空响应', () {
      final w = wired(replies: {});
      final out = w.bridge.invoke('req', <Object?>['https://s.com/x']);
      expect(out['e'], isNotNull);
    });
  });

  group('local.* 走 host.storage', () {
    test('set 把 key/value 与 instanceId 一起送出去', () {
      final w = wired(
        replies: {
          'host.storage.set': (_) => (<String, Object?>{}, null),
        },
      );

      w.bridge.invoke('local.set', <Object?>['k', 'v']);

      final params = w.host.received.single['params']! as Map<String, Object?>;
      expect(params['instanceId'], 'site:7');
      expect(params['key'], 'k');
      expect(params['value'], 'v');
    });

    test('get 返回宿主给的 value', () {
      final w = wired(
        replies: {
          'host.storage.get': (_) => (
            <String, Object?>{'value': '火影'},
            null,
          ),
        },
      );

      expect(w.bridge.invoke('local.get', <Object?>['k'])['v'], '火影');
    });

    test('get 不存在的 key 得到 null', () {
      final w = wired(
        replies: {
          'host.storage.get': (_) => (<String, Object?>{'value': null}, null),
        },
      );

      final out = w.bridge.invoke('local.get', <Object?>['nope']);
      expect(out['v'], isNull);
      expect(out['e'], isNull, reason: '不存在不该是错误');
    });

    test('delete 送出 key', () {
      final w = wired(
        replies: {
          'host.storage.delete': (_) => (<String, Object?>{}, null),
        },
      );

      w.bridge.invoke('local.delete', <Object?>['k']);

      final params = w.host.received.single['params']! as Map<String, Object?>;
      expect(params['key'], 'k');
    });

    test('存储配额被拒时脚本能看见异常', () {
      final w = wired(
        replies: {
          'host.storage.set': (_) => (
            null,
            <String, Object?>{'code': -32203, 'message': '超出存储配额'},
          ),
        },
      );

      final out = w.bridge.invoke('local.set', <Object?>['k', 'v']);
      expect(out['e'], contains('超出存储配额'));
    });

    test('owner 恒为宿主给的 instanceId，脚本传什么都改不了', () {
      final w = wired(
        replies: {
          'host.storage.get': (_) => (<String, Object?>{'value': null}, null),
        },
      );

      // 脚本多传一个参数试图指定 owner。
      w.bridge.invoke('local.get', <Object?>['k', 'site:999']);

      final params = w.host.received.single['params']! as Map<String, Object?>;
      expect(params['instanceId'], 'site:7');
    });
  });

  group('多次调用', () {
    test('连续三次 req 各自匹配到自己的回话', () {
      var n = 0;
      final w = wired(
        replies: {
          'host.fetch': (params) {
            n++;
            return (<String, Object?>{'body': '第 $n 条', 'status': 200}, null);
          },
        },
      );

      for (var i = 1; i <= 3; i++) {
        final out = w.bridge.invoke('req', <Object?>['https://s.com/$i']);
        expect((out['v']! as Map<String, Object?>)['content'], '第 $i 条');
      }
      expect(w.host.received, hasLength(3));
    });
  });
}
