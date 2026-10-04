import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:quickjs_dist/quickjs_dist.dart';
import 'package:test/test.dart';

void main() {
  group('QuickjsManifest', () {
    test('解析合法清单', () {
      final manifest = QuickjsManifest.fromJson('''
        {
          "version": "v1",
          "platform": "windows-x64",
          "files": {
            "libquickjs.dll": {"sha256": "${'a' * 64}"}
          }
        }
      ''');
      expect(manifest.version, 'v1');
      expect(manifest.platform, 'windows-x64');
      expect(manifest.files, {'libquickjs.dll': 'a' * 64});
    });

    test('sha256 大写会被转小写', () {
      final manifest = QuickjsManifest.fromJson('''
        {
          "version": "v1",
          "platform": "windows-x64",
          "files": {"a.dll": {"sha256": "${'A' * 64}"}}
        }
      ''');
      expect(manifest.files['a.dll'], 'a' * 64);
    });

    test('sha256 非法时抛错', () {
      expect(
        () => QuickjsManifest.fromJson('''
          {
            "version": "v1",
            "platform": "windows-x64",
            "files": {"a.dll": {"sha256": "zzz"}}
          }
        '''),
        throwsA(isA<QuickjsDistException>()),
      );
    });

    test('缺 files 抛错', () {
      expect(
        () => QuickjsManifest.fromJson('{"version":"v1"}'),
        throwsA(isA<QuickjsDistException>()),
      );
    });
  });

  group('QuickjsDistribution.install', () {
    late Directory tmp;
    late Directory vendor;
    late Directory dest;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('quickjs_dist_test_');
      vendor = Directory('${tmp.path}/vendor')..createSync();
      dest = Directory('${tmp.path}/dest');
    });

    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on Object {
        // 删除失败（如 DLL 被占用）不影响断言。
      }
    });

    QuickjsDistribution makeDistribution(Map<String, String> files) {
      final manifest = QuickjsManifest.fromJson(
        jsonEncode({
          'version': 't',
          'platform': 'windows-x64',
          'files': {
            for (final e in files.entries) e.key: {'sha256': e.value},
          },
        }),
      );
      return QuickjsDistribution(manifest: manifest);
    }

    test('从 vendor 拷贝并校验', () async {
      final content = utf8.encode('hello dll');
      final hash = _sha256Hex(content);
      File('${vendor.path}/a.dll').writeAsBytesSync(content);
      final dist = makeDistribution({'a.dll': hash});

      await dist.install(vendor, dest);

      expect(File('${dest.path}/a.dll').readAsBytesSync(), content);
    });

    test('已存在且哈希匹配时复用，不改文件', () async {
      final content = utf8.encode('hello dll');
      final hash = _sha256Hex(content);
      File('${vendor.path}/a.dll').writeAsBytesSync(content);
      final dist = makeDistribution({'a.dll': hash});

      await dist.install(vendor, dest);
      final before = File('${dest.path}/a.dll').lastModifiedSync();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await dist.install(vendor, dest);
      expect(File('${dest.path}/a.dll').lastModifiedSync(), before);
    });

    test('vendor 缺文件抛错', () async {
      final dist = makeDistribution({'missing.dll': 'b' * 64});
      await expectLater(
        dist.install(vendor, dest),
        throwsA(isA<QuickjsDistException>()),
      );
    });

    test('vendor 哈希不符抛错且不落盘', () async {
      File('${vendor.path}/a.dll').writeAsBytesSync(utf8.encode('x'));
      final dist = makeDistribution({'a.dll': 'c' * 64});
      await expectLater(
        dist.install(vendor, dest),
        throwsA(isA<QuickjsDistException>()),
      );
      expect(File('${dest.path}/a.dll').existsSync(), isFalse);
      expect(File('${dest.path}/.a.dll.tmp').existsSync(), isFalse);
    });

    test('install 后 verify 无问题', () async {
      final content = utf8.encode('hello dll');
      final hash = _sha256Hex(content);
      File('${vendor.path}/a.dll').writeAsBytesSync(content);
      final dist = makeDistribution({'a.dll': hash});

      await dist.install(vendor, dest);
      expect(await dist.verify(dest), isEmpty);
    });

    test('verify 报告缺失与哈希不符', () async {
      final contentA = utf8.encode('dll a');
      final contentB = utf8.encode('dll b');
      final hashA = _sha256Hex(contentA);
      final hashB = _sha256Hex(contentB);
      File('${vendor.path}/a.dll').writeAsBytesSync(contentA);
      File('${vendor.path}/b.dll').writeAsBytesSync(contentB);
      final dist = makeDistribution({'a.dll': hashA, 'b.dll': hashB});

      await dist.install(vendor, dest);
      // 篡改 a.dll、删掉 b.dll，verify 应分别报「哈希不符」与「缺失」。
      File('${dest.path}/a.dll').writeAsBytesSync(utf8.encode('modified'));
      File('${dest.path}/b.dll').deleteSync();

      final problems = await dist.verify(dest);
      expect(problems.join('\n'), contains('a.dll'));
      expect(problems.join('\n'), contains('b.dll'));
    });

    test('空目录 verify 全部缺失', () async {
      final dist = makeDistribution({'a.dll': 'd' * 64});
      final problems = await dist.verify(dest);
      expect(problems, hasLength(1));
    });
  });
}

String _sha256Hex(List<int> bytes) {
  final digest = sha256.convert(bytes);
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
