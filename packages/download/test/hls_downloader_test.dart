import 'dart:async';
import 'dart:io';

import 'package:download/download.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late _Transport transport;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mistream_hls_test_');
    transport = _Transport();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  HlsDownloader downloader({int maxConcurrency = 3}) => HlsDownloader(
    fetchText: transport.fetchText,
    fetchBytes: transport.fetchBytes,
    maxConcurrency: maxConcurrency,
  );

  /// 造一个两片（或 [count] 片）的点播列表。
  void givenPlaylist({
    required String url,
    int count = 2,
    String prefix = 'https://a.com/v/',
  }) {
    final lines = <String>[
      '#EXTM3U',
      '#EXT-X-VERSION:3',
      '#EXT-X-TARGETDURATION:10',
    ];
    for (var i = 0; i < count; i++) {
      lines
        ..add('#EXTINF:10.0,')
        ..add('$prefix$i.ts');
    }
    transport.playlists[url] = '${lines.join('\n')}\n';
    for (var i = 0; i < count; i++) {
      transport.segments['$prefix$i.ts'] = List<int>.filled(
        10 * (i + 1),
        i + 1,
      );
    }
  }

  group('基本下载', () {
    test('逐片下载、跳过注释行、相对地址按播放列表解析', () async {
      transport.playlists['https://a.com/v/index.m3u8'] = [
        '#EXTM3U',
        '#EXT-X-TARGETDURATION:10',
        '#EXTINF:10.0,',
        'seg0.ts',
        '#EXTINF:10.0,',
        'seg1.ts',
        '#EXT-X-ENDLIST',
      ].join('\n');
      transport.segments['https://a.com/v/seg0.ts'] = List<int>.filled(5, 1);
      transport.segments['https://a.com/v/seg1.ts'] = List<int>.filled(7, 2);

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(result.totalSegments, 2);
      expect(result.downloadedSegments, 2);
      expect(result.downloadedBytes, 12);
      expect(transport.byteRequests, [
        'https://a.com/v/seg0.ts',
        'https://a.com/v/seg1.ts',
      ]);
    });

    test('每个分片成功后回调 (seq, url, bytes)', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8');
      final done = <(int, String, int)>[];

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        onSegmentDone: (seq, url, bytes) => done.add((seq, url, bytes)),
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(done, hasLength(2));
      expect(done.map((e) => e.$1).toSet(), {0, 1});
      expect(done.firstWhere((e) => e.$1 == 0).$3, 10);
      expect(done.firstWhere((e) => e.$1 == 1).$3, 20);
    });

    test('请求头原样传给传输层', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8');

      await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        headers: const {'Referer': 'https://a.com/', 'User-Agent': 'X/1'},
      );

      expect(transport.headersSeen, isNotEmpty);
      for (final seen in transport.headersSeen) {
        expect(seen['Referer'], 'https://a.com/');
        expect(seen['User-Agent'], 'X/1');
      }
    });

    test('分片全部写完才改名，目录里不留 .part', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8');

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      final names = await _names(dir);
      expect(names.where((n) => n.endsWith('.part')), isEmpty);
      expect(names, contains('segment_000000.ts'));
      expect(names, contains('segment_000001.ts'));
    });

    test('分片写一半时，成品名不出现在盘上（原子写）', () async {
      // 「先写 .part 再改名」唯一的可观测差别，就是落盘那一刻用的是哪个名字。
      // 所以把落盘拆成两半、在中间停住，看盘上有什么：如果成品名已经存在且只有
      // 半截，进程此时被杀就会留下一个长度不对、却被续传当成「已完成」的文件，
      // 最后拼出来的视频中间缺一段。落盘做成可注入的就是为了能看见这一步。
      givenPlaylist(url: 'https://a.com/v/index.m3u8', count: 1);
      final halfWritten = Completer<void>();
      final resume = Completer<void>();

      final probed = HlsDownloader(
        fetchText: transport.fetchText,
        fetchBytes: transport.fetchBytes,
        writeBytes: (path, bytes) async {
          final half = bytes.length ~/ 2;
          await File(path).writeAsBytes(bytes.sublist(0, half), flush: true);
          halfWritten.complete();
          await resume.future;
          await File(path).writeAsBytes(
            bytes.sublist(half),
            mode: FileMode.append,
            flush: true,
          );
        },
      );

      final pending = probed.download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
      );

      await halfWritten.future;
      final finalFile = File('${dir.path}/segment_000000.ts');
      final lengthMidWrite = await finalFile.exists()
          ? await finalFile.length()
          : null;
      resume.complete();

      final result = await pending;
      expect(result.success, isTrue, reason: result.error ?? '');
      expect(lengthMidWrite, isNull, reason: '写一半时成品名不该存在');
      expect(await finalFile.length(), 10, reason: '改名之后才是完整的一片');
    });

    test('合并成一个可播文件，内容按序拼接', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8');

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(result.mergedPath, endsWith('merged.ts'));
      final merged = await File(result.mergedPath!).readAsBytes();
      expect(merged, [...List<int>.filled(10, 1), ...List<int>.filled(20, 2)]);
    });

    test('fMP4 分片合并成 .mp4', () async {
      transport.playlists['https://a.com/v/index.m3u8'] = [
        '#EXTM3U',
        '#EXTINF:4.0,',
        'seg0.m4s',
      ].join('\n');
      transport.segments['https://a.com/v/seg0.m4s'] = [1, 2, 3];

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
      );

      expect(result.mergedPath, endsWith('merged.mp4'));
    });

    test('分片请求失败时返回失败结果而不是抛异常', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8');
      transport.failOn = 'https://a.com/v/0.ts';

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('boom'));
    });
  });

  group('master 列表选流', () {
    test('取 BANDWIDTH 最大的变体并递归下载', () async {
      transport.playlists['https://a.com/v/master.m3u8'] = [
        '#EXTM3U',
        '#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360',
        'low/index.m3u8',
        '#EXT-X-STREAM-INF:BANDWIDTH=2400000,RESOLUTION=1280x720',
        'high/index.m3u8',
      ].join('\n');
      givenPlaylist(
        url: 'https://a.com/v/high/index.m3u8',
        prefix: 'https://a.com/v/high/',
      );
      givenPlaylist(
        url: 'https://a.com/v/low/index.m3u8',
        prefix: 'https://a.com/v/low/',
      );

      final result = await downloader().download(
        url: 'https://a.com/v/master.m3u8',
        savePath: dir.path,
        title: '示例',
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(result.resolvedUrl, 'https://a.com/v/high/index.m3u8');
      expect(
        transport.byteRequests,
        everyElement(startsWith('https://a.com/v/high/')),
      );
    });

    test('解析不出变体时按普通列表处理', () async {
      transport.playlists['https://a.com/v/master.m3u8'] = [
        '#EXTM3U',
        '#EXT-X-STREAM-INF:BANDWIDTH=abc',
        'broken.ts',
      ].join('\n');

      final result = await downloader().download(
        url: 'https://a.com/v/master.m3u8',
        savePath: dir.path,
        title: '示例',
      );

      // 解析不出带宽 → 不换流，直接把 `broken.ts` 当分片下（传输层没准备它）。
      expect(result.success, isFalse);
    });
  });

  group('断点续传', () {
    test('skipSegments 里的分片不再发起请求', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8', count: 3);
      await _writeSegment(dir, 0, 10);
      await _writeSegment(dir, 2, 30);

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        skipSegments: const {0, 2},
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(transport.byteRequests, ['https://a.com/v/1.ts']);
      expect(result.downloadedSegments, 3, reason: '跳过的两片也算已完成');
    });

    test('skipSegments 指向的分片文件不在盘上时会重新下载', () async {
      // 用户删过下载目录、或换过保存路径时，记录还在但文件没了。只看记录就会
      // 跳过它，最后拼出一个中间缺一段的合并文件 —— 不报错，只是播到一半花屏。
      givenPlaylist(url: 'https://a.com/v/index.m3u8');

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        skipSegments: const {0},
      );

      expect(transport.byteRequests, contains('https://a.com/v/0.ts'));
      expect(result.downloadedSegments, 2);
    });

    test('已跳过的分片字节数从盘上数回来，进度不会缩水', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8');
      // 上一轮已经下好 0 号片。
      await _writeSegment(dir, 0, 10);

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        skipSegments: const {0},
      );

      expect(result.success, isTrue, reason: result.error ?? '');
      expect(result.downloadedBytes, 30, reason: '10 字节的旧片 + 20 字节的新片');
      expect(result.totalBytes, 30);
    });

    test('越界的 skipSegments 不计入已完成', () async {
      // 播放列表变短时（源换了、任务重下），库里可能留着越界的旧序号 —— 而对应
      // 的分片文件**还在盘上**（上一轮下的是更长的变体）。所以「文件在不在盘上」
      // 这条检查拦不住它，必须同时校验序号落在当前播放列表范围内，否则进度会
      // 虚高到 1.5（3/2）。
      givenPlaylist(url: 'https://a.com/v/index.m3u8', count: 2);
      await _writeSegment(dir, 0, 10);
      await _writeSegment(dir, 1, 20);
      await _writeSegment(dir, 2, 30, value: 3);

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        skipSegments: const {0, 1, 2},
      );

      expect(transport.byteRequests, isEmpty);
      expect(result.downloadedSegments, 2, reason: '播放列表只有 2 片，2 号不算');
      expect(result.progress, 1);
      expect(result.downloadedBytes, 30, reason: '越界分片的字节不算进来');
    });

    test('续传时合并文件包含跳过的分片', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8');
      await _writeSegment(dir, 0, 10);

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        skipSegments: const {0},
      );

      final merged = await File(result.mergedPath!).readAsBytes();
      expect(merged, [...List<int>.filled(10, 1), ...List<int>.filled(20, 2)]);
    });
  });

  group('合并', () {
    test('合并前少了分片就报错，不留半成品', () async {
      // 分片刚写完就被外部删掉（用户清理下载目录、杀毒软件误删）。用
      // onSegmentDone 制造这个场景：它在落盘之后、合并之前被调用。
      givenPlaylist(url: 'https://a.com/v/index.m3u8');

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        onSegmentDone: (seq, url, bytes) {
          if (seq == 0) File('${dir.path}/segment_000000.ts').deleteSync();
        },
      );

      expect(result.success, isFalse, reason: '缺片不能报成功');
      expect(result.error, contains('分片缺失'));
      final names = await _names(dir);
      expect(names, isNot(contains('merged.ts')), reason: '半成品不能留在盘上');
    });
  });

  group('取消', () {
    test('取消后不再请求后续分片，返回失败', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8', count: 3);
      final token = CancelToken();
      transport.cancelAfterFirst = token;

      final result = await downloader(maxConcurrency: 1).download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        cancelToken: token,
      );

      expect(result.success, isFalse);
      expect(result.error, '已取消');
      expect(transport.byteRequests, ['https://a.com/v/0.ts']);
    });

    test('已下载的分片文件保留下来（续传的锚点）', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8', count: 3);
      final token = CancelToken();
      transport.cancelAfterFirst = token;

      await downloader(maxConcurrency: 1).download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        cancelToken: token,
      );

      final names = await _names(dir);
      expect(names, contains('segment_000000.ts'));
      expect(names, isNot(contains('merged.ts')), reason: '没下完不该生成合并文件');
    });

    test('一开始就是取消状态时不发任何分片请求', () async {
      givenPlaylist(url: 'https://a.com/v/index.m3u8');
      final token = CancelToken()..cancel();

      final result = await downloader().download(
        url: 'https://a.com/v/index.m3u8',
        savePath: dir.path,
        title: '示例',
        cancelToken: token,
      );

      expect(result.success, isFalse);
      expect(transport.byteRequests, isEmpty);
    });
  });
}

Future<List<String>> _names(Directory dir) async => [
  for (final entity in dir.listSync())
    if (entity is File) entity.uri.pathSegments.last,
];

/// 预置一个「上一轮已经下好」的分片文件。
Future<void> _writeSegment(
  Directory dir,
  int seq,
  int length, {
  int value = 1,
}) async {
  final name = 'segment_${seq.toString().padLeft(6, '0')}.ts';
  await File('${dir.path}/$name').writeAsBytes(List<int>.filled(length, value));
}

/// 可注入的假传输层。
///
/// 分片续传、master 选流、取消、原子写这些逻辑一条都不该依赖真实网络，
/// 所以传输层做成可注入的 —— 否则这些分支永远只能靠人工碰运气验证。
class _Transport {
  final Map<String, String> playlists = {};
  final Map<String, List<int>> segments = {};
  final List<String> textRequests = [];
  final List<String> byteRequests = [];
  final List<Map<String, String>> headersSeen = [];

  /// 命中这个地址时抛异常，用来模拟分片下载失败。
  String? failOn;

  /// 每下完一片就取消一次，用来模拟「下到一半用户点了暂停」。
  CancelToken? cancelAfterFirst;

  var _byteCount = 0;

  Future<String> fetchText(Uri url, Map<String, String> headers) async {
    textRequests.add(url.toString());
    headersSeen.add(headers);
    final body = playlists[url.toString()];
    if (body == null) throw StateError('没有为 $url 准备播放列表');
    return body;
  }

  Future<List<int>> fetchBytes(Uri url, Map<String, String> headers) async {
    byteRequests.add(url.toString());
    headersSeen.add(headers);
    if (url.toString() == failOn) throw StateError('boom');
    final body = segments[url.toString()];
    if (body == null) throw StateError('没有为 $url 准备分片');
    _byteCount++;
    if (_byteCount == 1) cancelAfterFirst?.cancel();
    return body;
  }
}
