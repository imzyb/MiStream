import 'dart:io';

import 'package:arch_check/arch_check.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// 拼接写法，避免这两个字面量被本工具自己的 ignore-reason 检查扫到。
const _badIgnore =
    '//'
    ' ignore: unused_field';
const _goodIgnore =
    '//'
    ' ignore: unused_field — 生成代码的占位字段';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mistream_arch_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<Directory> writePackage({
    required String name,
    required String pubspec,
    required Map<String, String> sources,
  }) async {
    final dir = Directory(p.join(root.path, 'packages', name));
    await Directory(p.join(dir.path, 'lib')).create(recursive: true);
    await File(p.join(dir.path, 'pubspec.yaml')).writeAsString(pubspec);
    for (final entry in sources.entries) {
      final file = File(p.join(dir.path, 'lib', entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
    return dir;
  }

  group('pure-dart', () {
    test('只用白名单内的库时通过', () async {
      final dir = await writePackage(
        name: 'core_domain',
        pubspec: 'name: core_domain\ndependencies:\n  meta: any\n',
        sources: {
          'core_domain.dart': '''
import 'dart:async';
import 'dart:convert';
import 'package:meta/meta.dart';
import 'package:core_domain/src/x.dart';
''',
        },
      );

      expect(await checkPureDartPackage(dir, root: root), isEmpty);
    });

    test('抓出 dart:io', () async {
      final dir = await writePackage(
        name: 'core_domain',
        pubspec: 'name: core_domain\n',
        sources: {'core_domain.dart': "import 'dart:io';\n"},
      );

      final violations = await checkPureDartPackage(dir, root: root);

      expect(violations, hasLength(1));
      expect(violations.single.rule, 'pure-dart');
      expect(violations.single.message, contains('dart:io'));
      expect(violations.single.line, 1);
    });

    test('抓出 Flutter 与其它 IO 包', () async {
      final dir = await writePackage(
        name: 'core_domain',
        pubspec: 'name: core_domain\n',
        sources: {
          'core_domain.dart': '''
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
''',
        },
      );

      expect(await checkPureDartPackage(dir, root: root), hasLength(3));
    });

    test('export 与 import 一视同仁', () async {
      final dir = await writePackage(
        name: 'core_domain',
        pubspec: 'name: core_domain\n',
        sources: {'core_domain.dart': "export 'dart:isolate';\n"},
      );

      expect(await checkPureDartPackage(dir, root: root), hasLength(1));
    });

    test('注释掉的 import 不算', () async {
      final dir = await writePackage(
        name: 'core_domain',
        pubspec: 'name: core_domain\n',
        sources: {'core_domain.dart': "// import 'dart:io';\n"},
      );

      expect(await checkPureDartPackage(dir, root: root), isEmpty);
    });

    test('抓出 pubspec 里的非法依赖', () async {
      final dir = await writePackage(
        name: 'core_domain',
        pubspec: '''
name: core_domain
dependencies:
  meta: any
  drift: ^2.0.0
''',
        sources: {'core_domain.dart': '// 空\n'},
      );

      final violations = await checkPureDartPackage(dir, root: root);

      expect(violations, hasLength(1));
      expect(violations.single.message, contains('drift'));
    });

    test('目录不存在时报错而不是静默通过', () async {
      final missing = Directory(p.join(root.path, 'packages', 'nope'));

      expect(await checkPureDartPackage(missing, root: root), hasLength(1));
    });
  });

  group('layering', () {
    test('抓出 Presentation 直连 Infrastructure', () async {
      final features = Directory(
        p.join(root.path, 'apps', 'mistream', 'lib', 'features'),
      );
      await features.create(recursive: true);
      await File(p.join(features.path, 'home_page.dart')).writeAsString('''
import 'package:flutter/material.dart';
import 'package:storage/storage.dart';
''');

      final violations = await checkForbiddenImports(
        features,
        root: root,
        forbidden: infrastructurePackages,
        pathContains: 'lib/features',
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, 'layering');
      expect(violations.single.message, contains('storage'));
    });

    test('目录不存在时安静通过', () async {
      final violations = await checkForbiddenImports(
        Directory(p.join(root.path, 'nope')),
        root: root,
        forbidden: infrastructurePackages,
        pathContains: 'lib/features',
      );

      expect(violations, isEmpty);
    });
  });

  group('ignore-reason', () {
    test('没写理由的 ignore 被抓', () async {
      await File(p.join(root.path, 'a.dart')).writeAsString('$_badIgnore\n');

      final violations = await checkIgnoreComments(root);

      expect(violations, hasLength(1));
      expect(violations.single.rule, 'ignore-reason');
    });

    test('写了理由就放行', () async {
      await File(p.join(root.path, 'a.dart')).writeAsString('$_goodIgnore\n');

      expect(await checkIgnoreComments(root), isEmpty);
    });

    test('ignore_for_file 同样受约束', () async {
      await File(p.join(root.path, 'a.dart')).writeAsString(
        '//'
        ' ignore_for_file: public_member_api_docs\n',
      );

      expect(await checkIgnoreComments(root), hasLength(1));
    });

    test('文档注释里举例用的 ignore 不算指令', () async {
      final file = File(p.join(root.path, 'a.dart'));
      await file.writeAsString('/// 这样写会被抓：$_badIgnore\n');

      expect(await checkIgnoreComments(root), isEmpty);
    });

    test('生成代码不参与检查', () async {
      await File(p.join(root.path, 'a.g.dart')).writeAsString('$_badIgnore\n');

      expect(await checkIgnoreComments(root), isEmpty);
    });
  });

  group('真实仓库', () {
    test('core_domain 确实是纯 Dart 包', () async {
      final repo = _findRepoRoot();
      final coreDomain = Directory(
        p.join(repo.path, 'packages', 'core_domain'),
      );

      final violations = await checkPureDartPackage(coreDomain, root: repo);

      expect(
        violations,
        isEmpty,
        reason: violations.map((v) => v.toString()).join('\n'),
      );
    });
  });
}

/// 从当前目录向上找到仓库根。
///
/// 判据是「同时有 pubspec.yaml 和 packages/core_domain」而不是某个单独的文件：
/// workspace 成员自己也有 pubspec.yaml，单看它会停在错误的一层。
Directory _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    final hasPubspec = File(p.join(dir.path, 'pubspec.yaml')).existsSync();
    final hasCoreDomain = Directory(
      p.join(dir.path, 'packages', 'core_domain'),
    ).existsSync();
    if (hasPubspec && hasCoreDomain) return dir;

    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('找不到仓库根（向上都没有 packages/core_domain）');
    }
    dir = parent;
  }
}
