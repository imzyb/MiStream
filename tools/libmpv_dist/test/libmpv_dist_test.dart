import 'dart:io';

import 'package:libmpv_dist/libmpv_dist.dart';
import 'package:test/test.dart';

void main() {
  group('LibmpvManifest.fromJson', () {
    test('解析合法清单', () {
      final manifest = LibmpvManifest.fromJson(_validManifestJson());
      expect(manifest.platform, 'windows-x64');
      expect(manifest.version, '2023-09-24');
      expect(manifest.sha256, hasLength(64));
      expect(manifest.dllSha256, hasLength(64));
      expect(manifest.url, endsWith(manifest.archive));
    });

    test('非对象 JSON 报错', () {
      expect(
        () => LibmpvManifest.fromJson('[1,2,3]'),
        throwsA(isA<LibmpvException>()),
      );
    });

    test('缺少字段报错', () {
      final json = _validManifestJson().replaceFirst('"dllSha256"', '"x"');
      expect(
        () => LibmpvManifest.fromJson(json),
        throwsA(isA<LibmpvException>()),
      );
    });

    test('sha256 不是 64 位十六进制报错', () {
      final json = _validManifestJson().replaceFirst(
        '"sha256":"${'a' * 64}"',
        '"sha256":"短哈希"',
      );
      expect(
        () => LibmpvManifest.fromJson(json),
        throwsA(isA<LibmpvException>()),
      );
    });

    test('url 不以归档名结尾报错', () {
      final json = _validManifestJson().replaceFirst(
        '"url":"https://example.com/releases/2023-09-24/mpv-dev.7z"',
        '"url":"https://example.com/other.zip"',
      );
      expect(
        () => LibmpvManifest.fromJson(json),
        throwsA(isA<LibmpvException>()),
      );
    });
  });

  group('LibmpvDistribution.install', () {
    test('首次安装：下载 → 校验 → 解包 → DLL 哈希一致', () async {
      final root = await Directory.systemTemp.createTemp('mistream_libmpv_');
      addTearDown(() => root.delete(recursive: true));

      final dest = Directory('${root.path}/dest');
      final cache = File('${root.path}/cache/fake.7z');

      // 造一个「归档」：内容就是 dll 本体，解包 = 拷贝自身。
      final fakeDllBytes = _fakeDllBytes();
      final dllSha = await _sha256OfBytes(fakeDllBytes);

      final manifest = _manifestWithHashes(
        archiveSha: await _sha256OfBytes(_fakeArchiveBytes(fakeDllBytes)),
        dllSha: dllSha,
      );

      var fetched = false;
      final distribution = LibmpvDistribution(
        manifest: manifest,
        fetch: (_) async {
          fetched = true;
          return _fakeArchiveBytes(fakeDllBytes);
        },
        extract: (archive, dir) async {
          await File('${dir.path}/${manifest.dll}').writeAsBytes(fakeDllBytes);
        },
      );

      final installed = await distribution.install(cache, dest);
      expect(fetched, isTrue);
      expect(installed.path, '${dest.path}/${manifest.dll}');
      expect(await installed.readAsBytes(), fakeDllBytes);
    });

    test('幂等：DLL 已存在且哈希一致时不重新下载', () async {
      final root = await Directory.systemTemp.createTemp('mistream_libmpv_');
      addTearDown(() => root.delete(recursive: true));

      final dest = Directory('${root.path}/dest');
      final cache = File('${root.path}/cache/fake.7z');

      final fakeDllBytes = _fakeDllBytes();
      final manifest = _manifestWithHashes(
        archiveSha: await _sha256OfBytes(_fakeArchiveBytes(fakeDllBytes)),
        dllSha: await _sha256OfBytes(fakeDllBytes),
      );

      await dest.create(recursive: true);
      await File('${dest.path}/${manifest.dll}').writeAsBytes(fakeDllBytes);

      var fetched = false;
      final distribution = LibmpvDistribution(
        manifest: manifest,
        fetch: (_) async {
          fetched = true;
          return _fakeArchiveBytes(fakeDllBytes);
        },
        extract: (archive, dir) async {},
      );

      final installed = await distribution.install(cache, dest);
      expect(fetched, isFalse, reason: '已安装且校验通过应直接复用');
      expect(installed.path, '${dest.path}/${manifest.dll}');
    });

    test('归档哈希不匹配报错，且不解包', () async {
      final root = await Directory.systemTemp.createTemp('mistream_libmpv_');
      addTearDown(() => root.delete(recursive: true));

      final dest = Directory('${root.path}/dest');
      final cache = File('${root.path}/cache/fake.7z');

      final fakeDllBytes = _fakeDllBytes();
      final manifest = _manifestWithHashes(
        archiveSha: 'a' * 64,
        dllSha: await _sha256OfBytes(fakeDllBytes),
      );

      var extracted = false;
      final distribution = LibmpvDistribution(
        manifest: manifest,
        fetch: (_) async => _fakeArchiveBytes(fakeDllBytes),
        extract: (archive, dir) async {
          extracted = true;
        },
      );

      expect(
        () => distribution.install(cache, dest),
        throwsA(isA<LibmpvException>()),
      );
      expect(extracted, isFalse);
    });

    test('解包后 DLL 哈希不匹配报错', () async {
      final root = await Directory.systemTemp.createTemp('mistream_libmpv_');
      addTearDown(() => root.delete(recursive: true));

      final dest = Directory('${root.path}/dest');
      final cache = File('${root.path}/cache/fake.7z');

      final fakeDllBytes = _fakeDllBytes();
      final manifest = _manifestWithHashes(
        archiveSha: await _sha256OfBytes(_fakeArchiveBytes(fakeDllBytes)),
        dllSha: 'b' * 64,
      );

      final distribution = LibmpvDistribution(
        manifest: manifest,
        fetch: (_) async => _fakeArchiveBytes(fakeDllBytes),
        extract: (archive, dir) async {
          await File('${dir.path}/${manifest.dll}').writeAsBytes(fakeDllBytes);
        },
      );

      expect(
        () => distribution.install(cache, dest),
        throwsA(isA<LibmpvException>()),
      );
    });
  });

  group('sha256Of', () {
    test('与已知哈希一致', () async {
      final file = await _tempFile('hello libmpv dist\n');
      expect(
        await sha256Of(file),
        await _sha256OfBytes('hello libmpv dist\n'.codeUnits),
      );
    });
  });
}

String _validManifestJson() =>
    '{"platform":"windows-x64",'
    '"version":"2023-09-24",'
    '"archive":"mpv-dev.7z",'
    '"url":"https://example.com/releases/2023-09-24/mpv-dev.7z",'
    '"sha256":"${'a' * 64}",'
    '"dllSha256":"${'b' * 64}",'
    '"dll":"libmpv-2.dll"}';

LibmpvManifest _manifestWithHashes({
  required String archiveSha,
  required String dllSha,
}) {
  return LibmpvManifest(
    platform: 'windows-x64',
    version: '2023-09-24',
    archive: 'fake.7z',
    url: 'https://example.com/releases/2023-09-24/fake.7z',
    sha256: archiveSha,
    dllSha256: dllSha,
    dll: 'libmpv-2.dll',
  );
}

List<int> _fakeArchiveBytes(List<int> dllBytes) => [...dllBytes, 0xEE, 0xFF];

List<int> _fakeDllBytes() => List<int>.generate(64, (i) => i * 7 & 0xFF);

Future<File> _tempFile(String content) async {
  final dir = await Directory.systemTemp.createTemp('mistream_libmpv_sha_');
  final file = File('${dir.path}/data.bin');
  await file.writeAsBytes(content.codeUnits);
  return file;
}

Future<String> _sha256OfBytes(List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('mistream_libmpv_sha_');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/blob.bin');
  await file.writeAsBytes(bytes);
  return sha256Of(file);
}
