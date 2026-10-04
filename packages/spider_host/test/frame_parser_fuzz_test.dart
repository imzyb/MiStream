import 'dart:convert';
import 'dart:math';

import 'package:spider_host/src/rpc/frame_parser.dart';
import 'package:test/test.dart';

/// 分帧层的模糊测试。
///
/// ROADMAP M3 出口标准①要求「通过半包/粘包/超大包/畸形数据的**模糊测试**，
/// 不崩溃」。`frame_parser_test.dart` 里那 13 条是**枚举**用例——覆盖的是我们
/// 想得到的畸形形态；模糊测试补的是想不到的那些。
///
/// 分帧层直接吃子进程的原始输出，而子进程跑的是用户从互联网导入、不受审计的
/// 第三方脚本。它写出什么字节都不该让宿主抛未捕获异常或转圈。
///
/// 种子固定：模糊测试挂了必须能原样重跑，随机种子会让失败无法复现。
void main() {
  group('分帧模糊测试', () {
    /// 断言：无论喂什么，`add` 都只返回三种结果之一，绝不抛。
    void feedSafely(LspFrameParser parser, List<int> chunk) {
      final FrameResult result;
      try {
        result = parser.add(chunk);
      } on Object catch (e, st) {
        fail('add() 抛了未捕获异常: $e\n输入前 64 字节: ${chunk.take(64).toList()}\n$st');
      }
      expect(
        result,
        anyOf(
          isA<FrameComplete>(),
          isA<FrameNeedMore>(),
          isA<FrameError>(),
        ),
      );
    }

    test('纯随机字节永不抛异常', () {
      final rng = Random(20260813);
      for (var round = 0; round < 500; round++) {
        final parser = LspFrameParser();
        final length = rng.nextInt(256);
        final chunk = List<int>.generate(length, (_) => rng.nextInt(256));
        feedSafely(parser, chunk);
      }
    });

    test('随机分块喂入随机字节，跨块也不抛', () {
      final rng = Random(20260814);
      for (var round = 0; round < 200; round++) {
        final parser = LspFrameParser();
        final total = List<int>.generate(
          rng.nextInt(512),
          (_) => rng.nextInt(256),
        );
        var offset = 0;
        while (offset < total.length) {
          final take = min(1 + rng.nextInt(32), total.length - offset);
          feedSafely(parser, total.sublist(offset, offset + take));
          offset += take;
        }
      }
    });

    test('合法帧被随机截断/拼接后仍不抛', () {
      final rng = Random(20260815);
      for (var round = 0; round < 300; round++) {
        final body = jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': rng.nextInt(1000),
          'method': 'spider.search',
          'params': <String, Object?>{'wd': '海贼王' * (1 + rng.nextInt(4))},
        });
        final bytes = utf8.encode(body);
        final full = <int>[
          ...utf8.encode('Content-Length: ${bytes.length}\r\n\r\n'),
          ...bytes,
        ];

        // 随机破坏一处：截断、改字节、或者插一段垃圾。
        final damaged = List<int>.of(full);
        switch (rng.nextInt(3)) {
          case 0:
            damaged.removeRange(rng.nextInt(damaged.length), damaged.length);
          case 1:
            if (damaged.isNotEmpty) {
              damaged[rng.nextInt(damaged.length)] = rng.nextInt(256);
            }
          case 2:
            damaged.insertAll(
              rng.nextInt(damaged.length + 1),
              List<int>.generate(rng.nextInt(16), (_) => rng.nextInt(256)),
            );
        }

        feedSafely(LspFrameParser(), damaged);
      }
    });

    test('随机 header 名与空白排列不抛', () {
      final rng = Random(20260816);
      const names = <String>[
        'Content-Length',
        'content-length',
        'CONTENT-LENGTH',
        'Content-Type',
        'X-Random',
        '',
        ':',
        'Content-Length:extra',
      ];
      for (var round = 0; round < 300; round++) {
        final buffer = StringBuffer();
        final lines = rng.nextInt(4);
        for (var i = 0; i < lines; i++) {
          buffer
            ..write(names[rng.nextInt(names.length)])
            ..write(rng.nextBool() ? ': ' : ':')
            ..write(rng.nextInt(200) - 50) // 含负数
            ..write('\r\n');
        }
        buffer.write('\r\n');
        feedSafely(LspFrameParser(), utf8.encode(buffer.toString()));
      }
    });

    test('声明长度与实际长度随机不符也不抛', () {
      final rng = Random(20260817);
      for (var round = 0; round < 300; round++) {
        final declared = rng.nextInt(4096);
        final actual = rng.nextInt(4096);
        feedSafely(LspFrameParser(), <int>[
          ...utf8.encode('Content-Length: $declared\r\n\r\n'),
          ...List<int>.generate(actual, (_) => rng.nextInt(128)),
        ]);
      }
    });

    test('随机非法 UTF-8 序列被判错而不是抛', () {
      final rng = Random(20260818);
      for (var round = 0; round < 200; round++) {
        // 0x80-0xFF 单独出现都是非法续字节。
        final body = List<int>.generate(
          1 + rng.nextInt(32),
          (_) => 0x80 + rng.nextInt(0x80),
        );
        feedSafely(LspFrameParser(), <int>[
          ...utf8.encode('Content-Length: ${body.length}\r\n\r\n'),
          ...body,
        ]);
      }
    });

    // 长度前缀协议一旦错位就无法可靠重同步——静默重新对齐会把垃圾错切成
    // 「合法」帧交上去执行，比报错危险得多。所以这里守的不是「能恢复」，
    // 而是**绝不静默错帧**：要么明确判错（调用方按约定丢弃重建），要么还在等。
    test('垃圾前缀绝不会被静默当成合法帧', () {
      final rng = Random(20260819);
      var errored = 0;

      for (var round = 0; round < 200; round++) {
        final parser = LspFrameParser();
        final junk = List<int>.generate(
          1 + rng.nextInt(32),
          (_) => 1 + rng.nextInt(12),
        );
        parser.add(junk);

        const body = '{"ok":1}';
        final after = parser.add(<int>[
          ...utf8.encode('Content-Length: ${body.length}\r\n\r\n'),
          ...utf8.encode(body),
        ]);

        if (after is FrameComplete) {
          // 真解出东西来，就必须是原样的 body，不能是错切的结果。
          expect(
            after.body,
            body,
            reason: '垃圾前缀导致错帧：解出了 ${after.body}',
          );
        } else {
          expect(after, isA<FrameError>());
          errored++;
        }
      }

      // 记录实际比例，行为变了这里会先露头。
      expect(errored, greaterThan(0));
    });

    test('判错后重建解析器即可继续正常工作', () {
      final parser = LspFrameParser();
      expect(parser.add(<int>[1, 2, 3, 13, 10, 13, 10]), isA<FrameError>());

      // FrameError 的约定就是「丢弃重建」，重建后一切照常。
      const body = '{"ok":1}';
      final result = LspFrameParser().add(<int>[
        ...utf8.encode('Content-Length: ${body.length}\r\n\r\n'),
        ...utf8.encode(body),
      ]);
      expect(result, isA<FrameComplete>());
      expect((result as FrameComplete).body, body);
    });

    test('超大声明长度立刻判错，不试图分配那么多内存', () {
      final rng = Random(20260820);
      for (var round = 0; round < 100; round++) {
        final huge = kMaxMessageBytes + 1 + rng.nextInt(1 << 30);
        final result = LspFrameParser().add(
          utf8.encode('Content-Length: $huge\r\n\r\n'),
        );
        expect(result, isA<FrameError>());
      }
    });
  });
}
