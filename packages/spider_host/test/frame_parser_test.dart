import 'dart:convert';

import 'package:spider_host/src/rpc/frame_parser.dart';
import 'package:test/test.dart';

void main() {
  group('LspFrameParser', () {
    late LspFrameParser parser;

    setUp(() {
      parser = LspFrameParser();
    });

    List<int> frame(String body) {
      final header = utf8.encode('Content-Length: ${body.length}\r\n\r\n');
      return header.followedBy(utf8.encode(body)).toList();
    }

    test('单块完整消息', () {
      final result = parser.add(frame('{"a":1}'));
      expect(result, isA<FrameComplete>());
      expect((result as FrameComplete).body, '{"a":1}');
    });

    test('半包：header 分两次收到', () {
      final bytes = frame('{"a":1}');
      final first = parser.add(bytes.sublist(0, 10));
      expect(first, isA<FrameNeedMore>());
      final second = parser.add(bytes.sublist(10));
      expect(second, isA<FrameComplete>());
      expect((second as FrameComplete).body, '{"a":1}');
    });

    test('半包：body 分两次收到', () {
      final bytes = frame('{"hello":"world"}');
      final hdrEnd = bytes.indexOf(utf8.encode('{"hello":"world"}')[0]);
      final first = parser.add(bytes.sublist(0, hdrEnd + 5));
      expect(first, isA<FrameNeedMore>());
      final second = parser.add(bytes.sublist(hdrEnd + 5));
      expect(second, isA<FrameComplete>());
      expect((second as FrameComplete).body, '{"hello":"world"}');
    });

    test('粘包：一个块包含两条消息', () {
      final bytes = frame('{"a":1}').followedBy(frame('{"b":2}')).toList();
      final first = parser.add(bytes);
      expect(first, isA<FrameComplete>());
      expect((first as FrameComplete).body, '{"a":1}');
      final second = parser.add([]);
      expect(second, isA<FrameComplete>());
      expect((second as FrameComplete).body, '{"b":2}');
    });

    test('超大消息体：超过 32MB 返回 FrameError', () {
      const huge = 33 * 1024 * 1024;
      final header = utf8.encode('Content-Length: $huge\r\n\r\n');
      final result = parser.add(
        header.followedBy(utf8.encode('{"a":1}')).toList(),
      );
      expect(result, isA<FrameError>());
      expect((result as FrameError).reason, contains('超过上限'));
    });

    test('畸形 header：缺少 Content-Length', () {
      final result = parser.add(utf8.encode('X-Length: 5\r\n\r\n{"a":1}'));
      expect(result, isA<FrameError>());
    });

    test('畸形 header：Content-Length 不是数字', () {
      final result = parser.add(
        utf8.encode('Content-Length: abc\r\n\r\n{"a":1}'),
      );
      expect(result, isA<FrameError>());
    });

    test('畸形 header：Content-Length 为负数', () {
      final result = parser.add(
        utf8.encode('Content-Length: -1\r\n\r\n{"a":1}'),
      );
      expect(result, isA<FrameError>());
    });

    test('畸形 header 无限增长超过上限', () {
      final hugeHeader = utf8.encode('X: ${'x' * 17000}');
      final result = parser.add(hugeHeader);
      expect(result, isA<FrameError>());
      expect((result as FrameError).reason, contains('超过上限'));
    });

    test('非法 UTF-8：body 含非法序列', () {
      final invalid = [0xff, 0xfe, 0x00, 0x01];
      final header = utf8.encode('Content-Length: ${invalid.length}\r\n\r\n');
      final result = parser.add(header.followedBy(invalid).toList());
      expect(result, isA<FrameError>());
      expect((result as FrameError).reason, contains('UTF-8'));
    });

    test('空 body', () {
      final result = parser.add(frame(''));
      expect(result, isA<FrameComplete>());
      expect((result as FrameComplete).body, '');
    });

    test('连续三条消息', () {
      for (final body in ['{"a":1}', '{"b":2}', '{"c":3}']) {
        final result = parser.add(frame(body));
        expect(result, isA<FrameComplete>());
        expect((result as FrameComplete).body, body);
      }
    });

    test('header 中 Content-Length 大小写不敏感', () {
      final header = utf8.encode('content-length: 7\r\n\r\n');
      final result = parser.add(
        header.followedBy(utf8.encode('{"a":1}')).toList(),
      );
      expect(result, isA<FrameComplete>());
      expect((result as FrameComplete).body, '{"a":1}');
    });
  });
}
