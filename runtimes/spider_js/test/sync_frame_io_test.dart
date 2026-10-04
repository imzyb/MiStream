import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:spider_js/src/child/sync_frame_io.dart';
import 'package:test/test.dart';

/// 用一段固定字节喂 [SyncFrameCodec]，模拟阻塞读。
int Function() _bytesOf(List<int> bytes) {
  var i = 0;
  return () => i < bytes.length ? bytes[i++] : -1;
}

List<int> _framed(String body) {
  final b = utf8.encode(body);
  return <int>[...utf8.encode('Content-Length: ${b.length}\r\n\r\n'), ...b];
}

void main() {
  group('同步读帧', () {
    test('读出单条消息', () {
      final codec = SyncFrameCodec(readByte: _bytesOf(_framed('{"a":1}')));
      expect(codec.readFrame(), '{"a":1}');
    });

    test('连续读出粘在一起的多条消息', () {
      final codec = SyncFrameCodec(
        readByte: _bytesOf(<int>[
          ..._framed('{"a":1}'),
          ..._framed('{"b":2}'),
          ..._framed('{"c":3}'),
        ]),
      );
      expect(codec.readFrame(), '{"a":1}');
      expect(codec.readFrame(), '{"b":2}');
      expect(codec.readFrame(), '{"c":3}');
      expect(codec.readFrame(), isNull);
    });

    test('流正常结束返回 null 而不是抛异常', () {
      final codec = SyncFrameCodec(readByte: _bytesOf(<int>[]));
      expect(codec.readFrame(), isNull);
    });

    test('header 读一半断流要报错，不能当正常结束', () {
      final codec = SyncFrameCodec(
        readByte: _bytesOf(utf8.encode('Content-Length: 7\r\n')),
      );
      expect(codec.readFrame, throwsA(isA<FrameFormatException>()));
    });

    test('body 读一半断流要报错', () {
      final full = _framed('{"a":1}');
      final codec = SyncFrameCodec(
        readByte: _bytesOf(full.sublist(0, full.length - 3)),
      );
      expect(codec.readFrame, throwsA(isA<FrameFormatException>()));
    });

    test('缺 Content-Length 报错', () {
      final codec = SyncFrameCodec(
        readByte: _bytesOf(utf8.encode('X-Other: 1\r\n\r\n{}')),
      );
      expect(codec.readFrame, throwsA(isA<FrameFormatException>()));
    });

    test('Content-Length 非数字报错', () {
      final codec = SyncFrameCodec(
        readByte: _bytesOf(utf8.encode('Content-Length: abc\r\n\r\n{}')),
      );
      expect(codec.readFrame, throwsA(isA<FrameFormatException>()));
    });

    test('header 名大小写不敏感', () {
      final b = utf8.encode('{"a":1}');
      final codec = SyncFrameCodec(
        readByte: _bytesOf(<int>[
          ...utf8.encode('CONTENT-LENGTH: ${b.length}\r\n\r\n'),
          ...b,
        ]),
      );
      expect(codec.readFrame(), '{"a":1}');
    });

    test('多余 header 行被忽略', () {
      final b = utf8.encode('{"a":1}');
      final codec = SyncFrameCodec(
        readByte: _bytesOf(<int>[
          ...utf8.encode(
            'Content-Type: application/json\r\n'
            'Content-Length: ${b.length}\r\n\r\n',
          ),
          ...b,
        ]),
      );
      expect(codec.readFrame(), '{"a":1}');
    });

    test('超长 header 被截断报错，不会无限增长', () {
      final codec = SyncFrameCodec(
        readByte: _bytesOf(utf8.encode('X: ${'a' * 20000}')),
      );
      expect(codec.readFrame, throwsA(isA<FrameFormatException>()));
    });

    test('声明长度超上限时立刻报错，不去读那么多字节', () {
      final codec = SyncFrameCodec(
        readByte: _bytesOf(utf8.encode('Content-Length: 999999999\r\n\r\n')),
      );
      expect(codec.readFrame, throwsA(isA<FrameFormatException>()));
    });

    test('非法 UTF-8 消息体报错', () {
      final codec = SyncFrameCodec(
        readByte: _bytesOf(<int>[
          ...utf8.encode('Content-Length: 2\r\n\r\n'),
          0xC3, 0x28, // 非法续字节
        ]),
      );
      expect(codec.readFrame, throwsA(isA<FrameFormatException>()));
    });

    test('中文消息体按 UTF-8 字节长度读，不被截断', () {
      const body = '{"t":"海贼王 第1集"}';
      final codec = SyncFrameCodec(readByte: _bytesOf(_framed(body)));
      expect(codec.readFrame(), body);
    });

    test('空消息体', () {
      final codec = SyncFrameCodec(
        readByte: _bytesOf(utf8.encode('Content-Length: 0\r\n\r\n')),
      );
      expect(codec.readFrame(), '');
    });
  });

  group('同步写帧', () {
    test('写出的字节能被自己读回来', () {
      final out = <int>[];
      SyncFrameCodec(write: out.addAll).writeFrame('{"a":1}');

      expect(utf8.decode(out), startsWith('Content-Length: 7\r\n\r\n'));
      expect(SyncFrameCodec(readByte: _bytesOf(out)).readFrame(), '{"a":1}');
    });

    test('中文按字节数算长度', () {
      final out = <int>[];
      const body = '{"t":"海贼王"}';
      SyncFrameCodec(write: out.addAll).writeFrame(body);

      expect(
        utf8.decode(out),
        startsWith('Content-Length: ${utf8.encode(body).length}\r\n\r\n'),
      );
      expect(SyncFrameCodec(readByte: _bytesOf(out)).readFrame(), body);
    });
  });

  group('吞吐', () {
    test('1MB 消息体不退化成 O(n²)', () {
      final body = '{"html":"${'x' * (1024 * 1024)}"}';
      final codec = SyncFrameCodec(readByte: _bytesOf(_framed(body)));

      final sw = Stopwatch()..start();
      final got = codec.readFrame();
      sw.stop();

      expect(got?.length, body.length);
      // 逐字节喂增量解析器的话，这里是 10^12 级的字节拷贝，几分钟都跑不完。
      // 阈值给得很松，只为拦住量级性的退化，不为卡具体性能。
      expect(
        sw.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: '1MB 读取耗时 ${sw.elapsedMilliseconds}ms，疑似退化成二次复杂度',
      );
    });
  });

  group('真实 stdout 语义', () {
    // 这条是整个同步子进程方案的地基：dart:io 的 stdout 必须是阻塞写，
    // 否则子进程写完请求就退出/继续阻塞读，两边一起卡死。
    test('子进程不 flush 直接退出，父进程仍能收全', () async {
      final proc = await Process.start(Platform.resolvedExecutable, <String>[
        'run',
        'test/fixtures/stdout_probe.dart',
      ]);

      final err = <int>[];
      unawaited(proc.stderr.forEach(err.addAll));
      final bytes = <int>[];
      await proc.stdout
          .forEach(bytes.addAll)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              proc.kill();
              fail(
                '子进程 30s 没退出。stderr=${utf8.decode(err, allowMalformed: true)}',
              );
            },
          );
      final code = await proc.exitCode;
      expect(
        code,
        0,
        reason: 'stderr=${utf8.decode(err, allowMalformed: true)}',
      );

      final codec = SyncFrameCodec(readByte: _bytesOf(bytes));
      expect(codec.readFrame(), contains('第一条'));
      expect(codec.readFrame(), contains('第二条'));
      expect(codec.readFrame(), isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    // 方案里的头号风险：readByteSync 是 VM native 调用，逐字节读大响应体会不会
    // 吃掉 search 的 3s 预算。注入闭包测不出来（那是普通 Dart 调用），必须走真
    // stdin。这条同时也是个基准——数字变差了会先在这里露头。
    test('真实 stdin 上 1MB 的逐字节读耗时可接受', () async {
      final proc = await Process.start(Platform.resolvedExecutable, <String>[
        'run',
        'test/fixtures/stdin_throughput_probe.dart',
      ]);

      const payload = 1024 * 1024;
      final body = '{"html":"${'x' * (payload - 12)}"}';
      final encoded = utf8.encode(body);
      proc.stdin
        ..add(utf8.encode('Content-Length: ${encoded.length}\r\n\r\n'))
        ..add(encoded);
      await proc.stdin.flush();
      await proc.stdin.close();

      final bytes = <int>[];
      await proc.stdout.forEach(bytes.addAll);
      await proc.exitCode;

      final reply = SyncFrameCodec(readByte: _bytesOf(bytes)).readFrame();
      expect(reply, isNotNull, reason: '探针没回话，stdout=${utf8.decode(bytes)}');

      final decoded = jsonDecode(reply!) as Map<String, Object?>;
      expect(decoded['bytes'], encoded.length);

      final elapsedMs = decoded['elapsedMs']! as int;
      printOnFailure('1MB 逐字节读耗时 ${elapsedMs}ms');
      // 这条是**性能护栏**，不是正确性断言：它要拦的是「逐字节方案被改坏成
      // 量级性退化」，而不是给绝对时延立一个精确刻度。
      //
      // 实测（都走真 stdin、真 VM native readByteSync）：
      //   - 本机基线 668ms/MB
      //   - GitHub 共享 runner（ubuntu-latest）2008ms/MB —— 3 倍，纯粹是宿主机
      //     调度噪声，方案本身没变
      // 原阈值 1000ms 只比基线高 50%，于是 CI 上按概率翻红（macOS 同样如此）。
      // 现在取 5000ms ≈ 基线的 7.5 倍：既容得下共享 runner 的抖动，又仍能拦住
      // 5 倍以上的真实退化（例如把逐字节读改成每次多一次 syscall 那种）。
      //
      // 如果这条开始频繁失败，先怀疑宿主机变慢，而不是直接改大阈值——
      // 量级真退化时该换的是「大 payload 走临时文件」（见方案退路）。
      expect(
        elapsedMs,
        lessThan(5000),
        reason: '1MB 读了 ${elapsedMs}ms，逐字节方案撑不住，该换成大 payload 走临时文件（见方案退路）',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
