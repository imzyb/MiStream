import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/src/rpc/rpc_message.dart';
import 'package:test/test.dart';

void main() {
  group('RpcMessage 编解码', () {
    test('RpcRequest 编码为 JSON-RPC 2.0 形态', () {
      final req = RpcRequest(
        id: 42,
        method: 'spider.search',
        params: {
          'q': '海贼王',
        },
      );
      final json = req.toJson();
      expect(json['jsonrpc'], '2.0');
      expect(json['id'], 42);
      expect(json['method'], 'spider.search');
      expect(json['params'], {'q': '海贼王'});
    });

    test('RpcNotification 编码无 id', () {
      final notif = RpcNotification(
        method: 'runtime.log',
        params: {
          'level': 'info',
        },
      );
      final json = notif.toJson();
      expect(json['jsonrpc'], '2.0');
      expect(json['id'], isNull);
      expect(json['method'], 'runtime.log');
    });

    test('RpcResponse.result 编码', () {
      final resp = RpcResponse.result(id: 42, result: {'ok': true});
      final json = resp.toJson();
      expect(json['id'], 42);
      expect(json['result'], {'ok': true});
      expect(json['error'], isNull);
    });

    test('RpcResponse.error 编码', () {
      final resp = RpcResponse.error(
        id: 7,
        error: const RemoteError(
          code: ErrorCode.scriptRuntimeError,
          message: 'boom',
        ),
      );
      final json = resp.toJson();
      expect(json['id'], 7);
      expect((json['error']! as Map)['code'], -32101);
      expect((json['error']! as Map)['message'], 'boom');
    });

    test('fromJson 解码请求', () {
      final msg = RpcMessage.fromJson({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'spider.detail',
        'params': {'ids': 'abc'},
      });
      expect(msg, isA<RpcRequest>());
      expect((msg as RpcRequest).id, 1);
      expect(msg.method, 'spider.detail');
      expect(msg.params['ids'], 'abc');
    });

    test('fromJson 解码通知（无 id）', () {
      final msg = RpcMessage.fromJson({
        'jsonrpc': '2.0',
        'method': 'runtime.progress',
        'params': {'id': 1, 'phase': 'loading'},
      });
      expect(msg, isA<RpcNotification>());
      expect((msg as RpcNotification).method, 'runtime.progress');
    });

    test('fromJson 解码成功响应', () {
      final msg = RpcMessage.fromJson({
        'jsonrpc': '2.0',
        'id': 3,
        'result': {'ts': 1234},
      });
      expect(msg, isA<RpcResponse>());
      final resp = msg as RpcResponse;
      expect(resp.id, 3);
      expect(resp.result, {'ts': 1234});
      expect(resp.isError, isFalse);
    });

    test('fromJson 解码错误响应为 RemoteError', () {
      final msg = RpcMessage.fromJson({
        'jsonrpc': '2.0',
        'id': 3,
        'error': {
          'code': -32101,
          'message': 'TypeError',
          'data': {'stack': 'at x', 'retryable': false},
        },
      });
      final resp = msg as RpcResponse;
      expect(resp.isError, isTrue);
      expect(resp.error?.code, ErrorCode.scriptRuntimeError);
      expect(resp.error?.remoteStack, 'at x');
      expect(resp.error?.retryable, isFalse);
    });

    test('encodeFramed 产出 Content-Length 帧', () {
      final bytes = encodeFramed(
        RpcRequest(id: 1, method: 'ping'),
      );
      final text = const Utf8Codec().decode(bytes);
      expect(text, contains('Content-Length: '));
      expect(text, contains('"method":"ping"'));
    });
  });
}
