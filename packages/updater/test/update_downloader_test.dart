import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:updater/updater.dart';

import 'fakes.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mistream-updater-test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  String sha(List<int> bytes) => sha256.convert(bytes).toString();

  UpdateAsset assetOf(
    String url, {
    String? sha256,
    int? size,
    String fileName = 'update.zip',
  }) => UpdateAsset(
    url: url,
    sha256: sha256,
    size: size,
    fileName: fileName,
  );

  group('UpdateDownloader', () {
    test('正常下载：落盘、内容正确、不留下 .part', () async {
      final bytes = List<int>.generate(4096, (i) => i % 251);
      final fetcher = FakeFetcher.bytes(bytes);
      final file = await UpdateDownloader(fetcher: fetcher).download(
        asset: assetOf('https://example.com/update.zip'),
        dir: dir,
      );

      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), bytes);
      expect(File('${file.path}.part').existsSync(), isFalse);
      expect(fetcher.calls.single.toString(), 'https://example.com/update.zip');
    });

    test('分块流也能正确拼起来，进度回调最后一次是总量', () async {
      final chunks = [
        List<int>.filled(100, 1),
        List<int>.filled(200, 2),
        List<int>.filled(300, 3),
      ];
      final progress = <(int, int?)>[];
      final file =
          await UpdateDownloader(
            fetcher: FakeFetcher((_) async => chunkedOf(chunks)),
          ).download(
            asset: assetOf('https://example.com/a.zip', size: 600),
            dir: dir,
            onProgress: (received, total) => progress.add((received, total)),
          );

      expect(file.lengthSync(), 600);
      expect(progress.length, 3);
      expect(progress.last.$1, 600);
      expect(progress.last.$2, 600);
    });

    test('sha256 不符 → 抛异常，且 .part 与正式文件都不留', () async {
      final bytes = List<int>.filled(64, 7);
      final fetcher = FakeFetcher.bytes(bytes);
      await expectLater(
        UpdateDownloader(fetcher: fetcher).download(
          asset: assetOf(
            'https://example.com/a.zip',
            sha256: sha(List<int>.filled(64, 9)),
          ),
          dir: dir,
        ),
        throwsA(
          isA<UpdateDownloadException>().having(
            (e) => e.message,
            'message',
            contains('sha256'),
          ),
        ),
      );
      expect(File('${dir.path}/update.zip').existsSync(), isFalse);
      expect(File('${dir.path}/update.zip.part').existsSync(), isFalse);
    });

    test('size 不符 → 抛异常并清理（比 sha 更早报，信息更明确）', () async {
      final fetcher = FakeFetcher.bytes(List<int>.filled(10, 1));
      await expectLater(
        UpdateDownloader(fetcher: fetcher).download(
          asset: assetOf('https://example.com/a.zip', size: 999),
          dir: dir,
        ),
        throwsA(
          isA<UpdateDownloadException>().having(
            (e) => e.message,
            'message',
            contains('包大小不符'),
          ),
        ),
      );
      expect(File('${dir.path}/update.zip.part').existsSync(), isFalse);
    });

    test('HTTP 500 → retryable；404 → 不 retryable', () async {
      Future<UpdateDownloadException> run(int status) async {
        try {
          await UpdateDownloader(
            fetcher: FakeFetcher.bytes(const [], status: status),
          ).download(
            asset: assetOf('https://example.com/a.zip'),
            dir: dir,
          );
        } on UpdateDownloadException catch (e) {
          return e;
        }
        fail('应当抛异常');
      }

      expect((await run(500)).retryable, isTrue);
      expect((await run(429)).retryable, isTrue);
      expect((await run(404)).retryable, isFalse);
    });

    test('空响应 → 抛异常，不留 0 字节文件', () async {
      await expectLater(
        UpdateDownloader(
          fetcher: FakeFetcher.bytes(const []),
        ).download(
          asset: assetOf('https://example.com/a.zip'),
          dir: dir,
        ),
        throwsA(isA<UpdateDownloadException>()),
      );
      expect(File('${dir.path}/update.zip').existsSync(), isFalse);
    });

    test('同名文件已存在 → 被新内容替换', () async {
      final stale = File('${dir.path}/update.zip')
        ..writeAsBytesSync(List<int>.filled(3, 0));
      expect(stale.existsSync(), isTrue);

      final bytes = List<int>.filled(20, 5);
      await UpdateDownloader(
        fetcher: FakeFetcher.bytes(bytes),
      ).download(
        asset: assetOf('https://example.com/a.zip'),
        dir: dir,
      );
      expect(stale.readAsBytesSync(), bytes);
    });

    test('目录不存在时会自动创建', () async {
      final nested = Directory('${dir.path}/a/b/c');
      await UpdateDownloader(
        fetcher: FakeFetcher.bytes(List<int>.filled(4, 1)),
      ).download(
        asset: assetOf('https://example.com/a.zip'),
        dir: nested,
      );
      expect(File('${nested.path}/update.zip').existsSync(), isTrue);
    });
  });
}
