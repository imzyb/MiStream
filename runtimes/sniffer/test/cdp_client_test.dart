/// CDP 协议层测试。
///
/// 覆盖 id 配对、事件分发、错误规范化、超时——这些都是「不出错时看不出、
/// 出错时极难查」的部分，也正是必须被测的。
library;

import 'dart:async';

import 'package:sniffer/sniffer.dart';
import 'package:test/test.dart';

import 'fake_cdp_transport.dart';

void main() {
  late FakeCdpTransport transport;
  late CdpClient client;

  setUp(() {
    transport = FakeCdpTransport();
    client = CdpClient(transport);
  });

  tearDown(() async {
    await client.close();
  });

  group('命令与响应配对', () {
    test('命令发出后拿到对应 result', () async {
      transport = FakeCdpTransport(
        replies: {
          'Page.navigate': [
            const CdpScriptedReply(
              result: {'frameId': 'F1', 'loaderId': 'L1'},
            ),
          ],
        },
      );
      client = CdpClient(transport);
      await client.connect();

      final r = await client.send(
        'Page.navigate',
        params: {'url': 'https://a.b'},
      );
      expect(r['frameId'], 'F1');
      expect(r['loaderId'], 'L1');
    });

    test('id 递增且不重复', () async {
      await client.connect();
      await client.send('A');
      await client.send('B');
      await client.send('C');
      final ids = transport.sent.map((f) => f['id']).toList();
      expect(ids, [1, 2, 3]);
    });

    test('params 缺省时不写 params 键', () async {
      await client.connect();
      await client.send('NoParams');
      expect(transport.sent.single.containsKey('params'), isFalse);
    });

    test('params 给出时原样透传', () async {
      await client.connect();
      final params = <String, Object?>{'url': 'https://x.y', 'n': 3};
      await client.send('Nav', params: params);
      expect(transport.sent.single['params'], params);
    });

    test('sessionId 透传（flat session 模式）', () async {
      await client.connect();
      await client.send('Runtime.evaluate', sessionId: 'S1');
      expect(transport.sent.single['sessionId'], 'S1');
    });

    test('并发命令各自拿到自己的响应', () async {
      transport = FakeCdpTransport(
        replies: {
          'First': [
            const CdpScriptedReply(result: {'v': 'first'}),
          ],
          'Second': [
            const CdpScriptedReply(result: {'v': 'second'}),
          ],
        },
      );
      client = CdpClient(transport);
      await client.connect();

      // 同时发出，靠 id 配对而不是靠先后顺序。
      final results = await Future.wait([
        client.send('First'),
        client.send('Second'),
      ]);
      expect(results[0]['v'], 'first');
      expect(results[1]['v'], 'second');
    });
  });

  group('错误规范化', () {
    test('CDP error 转成 CdpCommandException 且带方法名', () async {
      transport = FakeCdpTransport(
        replies: {
          'Bad.Method': [
            const CdpScriptedReply(
              error: {'code': -32601, 'message': 'method not found'},
            ),
          ],
        },
      );
      client = CdpClient(transport);
      await client.connect();

      await expectLater(
        client.send('Bad.Method'),
        throwsA(
          isA<CdpCommandException>()
              .having((e) => e.code, 'code', -32601)
              .having((e) => e.message, 'message', 'method not found')
              .having((e) => e.method, 'method', 'Bad.Method'),
        ),
      );
    });

    test('error 里的 data 被保留', () async {
      transport = FakeCdpTransport(
        replies: {
          'X': [
            const CdpScriptedReply(
              error: {'code': -1, 'message': 'm', 'data': 'extra'},
            ),
          ],
        },
      );
      client = CdpClient(transport);
      await client.connect();

      try {
        await client.send('X');
        fail('应当抛出');
      } on CdpCommandException catch (e) {
        expect(e.data, 'extra');
      }
    });

    test('未连接就发送会失败', () async {
      await expectLater(
        client.send('Anything'),
        throwsA(isA<CdpTransportException>()),
      );
    });

    test('result 缺失时给空 map 而不是 null', () async {
      transport = FakeCdpTransport(
        replies: {
          'Empty': [const CdpScriptedReply()],
        },
      );
      client = CdpClient(transport);
      await client.connect();
      final r = await client.send('Empty');
      expect(r, isEmpty);
    });
  });

  group('超时', () {
    test('命令超时抛 CdpTimeoutException 并带方法名', () async {
      transport = FakeCdpTransport(
        replies: {
          'Slow': [
            const CdpScriptedReply(delay: Duration(milliseconds: 300)),
          ],
        },
      );
      client = CdpClient(transport);
      await client.connect();

      await expectLater(
        client.send('Slow', timeout: const Duration(milliseconds: 30)),
        throwsA(
          isA<CdpTimeoutException>().having((e) => e.method, 'method', 'Slow'),
        ),
      );
    });

    test('超时后的迟到响应不会串到别的命令上', () async {
      transport = FakeCdpTransport(
        replies: {
          'Slow': [const CdpScriptedReply(delay: Duration(milliseconds: 80))],
          'Fast': [
            const CdpScriptedReply(result: {'v': 'fast'}),
          ],
        },
      );
      client = CdpClient(transport);
      await client.connect();

      await expectLater(
        client.send('Slow', timeout: const Duration(milliseconds: 10)),
        throwsA(isA<CdpTimeoutException>()),
      );

      // 迟到的 Slow 响应此刻才到；Fast 必须拿到自己的结果。
      final fast = await client.send('Fast');
      expect(fast['v'], 'fast');

      // 等迟到的响应被丢弃，确认没有未捕获异常。
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
  });

  group('事件分发', () {
    test('无 id 的帧被当作事件', () async {
      await client.connect();
      final got = <CdpEvent>[];
      final sub = client.events.listen(got.add);

      transport.emit(responseReceivedEvent(url: 'https://a/x.m3u8'));
      await Future<void>.delayed(Duration.zero);

      expect(got, hasLength(1));
      expect(got.single.method, 'Network.responseReceived');
      expect(got.single.params['response'], isA<Map<String, Object?>>());
      await sub.cancel();
    });

    test('多个订阅者都能收到同一事件（广播流）', () async {
      await client.connect();
      final a = <CdpEvent>[];
      final b = <CdpEvent>[];
      final sa = client.events.listen(a.add);
      final sb = client.events.listen(b.add);

      transport.emit(loadEventFired());
      await Future<void>.delayed(Duration.zero);

      expect(a, hasLength(1));
      expect(b, hasLength(1));
      await sa.cancel();
      await sb.cancel();
    });

    test('waitForEvent 命中即返回', () async {
      await client.connect();
      final future = client.waitForEvent(
        (e) => e.method == 'Page.loadEventFired',
        timeout: const Duration(seconds: 2),
      );
      transport.emit(responseReceivedEvent(url: 'https://a/x.m3u8'));
      transport.emit(loadEventFired());

      final event = await future;
      expect(event.method, 'Page.loadEventFired');
    });

    test('waitForEvent 无匹配则超时', () async {
      await client.connect();
      await expectLater(
        client.waitForEvent(
          (e) => e.method == 'Never.Happens',
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<CdpTimeoutException>()),
      );
    });
  });

  group('连接生命周期', () {
    test('传输报错时所有在途命令收到错误', () async {
      // 用一个永不回复的应答，让命令真正处于「在途」状态。
      transport = FakeCdpTransport(
        replies: {
          'Pending': [
            const CdpScriptedReply(delay: Duration(seconds: 30)),
          ],
        },
      );
      client = CdpClient(transport);
      await client.connect();

      final future = client.send(
        'Pending',
        timeout: const Duration(seconds: 30),
      );
      // 等命令真的发出去。
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 直接关闭传输，模拟内核崩溃。
      await transport.close();

      await expectLater(future, throwsA(isA<Object>()));
    });

    test('close 后发送失败', () async {
      await client.connect();
      await client.close();
      await expectLater(
        client.send('After.Close'),
        throwsA(isA<CdpTransportException>()),
      );
    });

    test('lastIssuedId 反映已发命令数', () async {
      await client.connect();
      await client.send('A');
      await client.send('B');
      expect(client.lastIssuedId, 2);
    });
  });
}
