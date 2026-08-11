import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/src/rpc/rpc_recorder.dart';
import 'package:test/test.dart';

void main() {
  group('RpcRecorder', () {
    test('记录事件并保存到 JSONL', () async {
      final recorder = RpcRecorder()
        ..record(<String, Object?>{
          'id': 1,
          'method': 'spider.ping',
          'params': <String, Object?>{},
        }, 'send')
        ..record(<String, Object?>{'id': 1, 'result': 'pong'}, 'recv');
      expect(recorder.events, hasLength(2));
      expect(recorder.events[0].method, 'spider.ping');
      expect(recorder.events[0].direction, 'send');
      expect(recorder.events[0].type, 'request');
      expect(recorder.events[1].type, 'response');
      expect(recorder.events[1].result, 'pong');
    });

    test('保存/加载 JSONL 往返', () async {
      final tmp = Directory.systemTemp.createTempSync('rpc_test');
      final filePath = '${tmp.path}\\session.jsonl';
      try {
        final recorder = RpcRecorder()
          ..record(<String, Object?>{
            'id': 1,
            'method': 'spider.home',
            'params': <String, Object?>{},
          }, 'send')
          ..record(<String, Object?>{
            'id': 1,
            'result': {'list': <Object?>[]},
          }, 'recv');
        await recorder.saveToFile(filePath);

        final loaded = await RpcRecorder.loadFromFile(filePath);
        expect(loaded, hasLength(2));
        expect(loaded[0].method, 'spider.home');
        expect(loaded[1].result, {'list': <Object?>[]});
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('错误事件记录', () async {
      final recorder = RpcRecorder()
        ..record({
          'error': {'code': -32101, 'message': '脚本错误'},
        }, 'recv');
      expect(recorder.events[0].type, 'error');
      expect(recorder.events[0].errorCode, -32101);
      expect(recorder.events[0].errorMessage, '脚本错误');
    });
  });

  group('RpcReplayer', () {
    test('从文件加载并回放', () async {
      final tmp = Directory.systemTemp.createTempSync('rpc_replay');
      final filePath = '${tmp.path}\\session.jsonl';
      try {
        final recorder = RpcRecorder()
          ..record(<String, Object?>{
            'id': 1,
            'method': 'spider.ping',
            'params': <String, Object?>{},
          }, 'send')
          ..record(<String, Object?>{'id': 1, 'result': 'pong'}, 'recv');
        await recorder.saveToFile(filePath);

        final replayer = await RpcReplayer.fromFile(filePath);
        final result = await replayer.findResponse('spider.ping', {});
        expect(result, 'pong');
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('注入错误', () async {
      final tmp = Directory.systemTemp.createTempSync('rpc_inject');
      final filePath = '${tmp.path}\\session.jsonl';
      try {
        final recorder = RpcRecorder()
          ..record(<String, Object?>{
            'id': 1,
            'method': 'spider.search',
            'params': {'wd': 'test'},
          }, 'send')
          ..record(<String, Object?>{
            'id': 1,
            'result': {'list': <Object?>[]},
          }, 'recv');
        await recorder.saveToFile(filePath);

        final replayer = await RpcReplayer.fromFile(filePath);
        replayer.injectErrorMethods.add('spider.search');
        final result = await replayer.findResponse('spider.search', {
          'wd': 'test',
        });
        expect(result, isA<RemoteError>());
        expect((result! as RemoteError).message, contains('注入错误'));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });
}
