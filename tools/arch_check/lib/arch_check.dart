/// 分层纪律的强制校验。
///
/// `docs/10-开发规范.md` §3.3 写了三条纪律，但写在文档里的纪律会漂移——尤其是
/// 「`core_domain` 不许 import Flutter/IO」这种：加一行 `import 'dart:io'` 只
/// 要一秒，而它一旦进去，这个包就再也无法在纯 Dart 环境下跑测试，也无法被
/// `runtimes/` 下的子进程复用。所以文档里那句「CI 中加自定义检查脚本强制」
/// 就是本文件。
library;

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// 一处违规。
@immutable
final class Violation {
  /// 构造一处违规。
  const Violation({
    required this.rule,
    required this.file,
    required this.message,
    this.line,
  });

  /// 规则名。
  final String rule;

  /// 相对仓库根的文件路径。
  final String file;

  /// 行号，从 1 开始；针对整个文件的违规为 `null`。
  final int? line;

  /// 说明。
  final String message;

  @override
  String toString() {
    final where = line == null ? file : '$file:$line';
    return '$where  [$rule] $message';
  }
}

/// `core_domain` 允许使用的 `dart:` 库。
///
/// 全是纯计算，不碰 IO、不碰平台、不碰 UI。`dart:io`、`dart:ui`、
/// `dart:ffi`、`dart:isolate` 都不在其中，这是刻意的。
const allowedDartLibraries = <String>{
  'async',
  'collection',
  'convert',
  'math',
  'typed_data',
};

/// `core_domain` 允许依赖的第三方包。
const allowedPackages = <String>{'meta'};

/// Presentation 层不得直接 import 的 Infrastructure 包（`docs/10` §3.3）。
///
/// UI 直连子进程管理或数据库，意味着「换个数据源」要改一堆 widget，
/// 而 widget 测试要先起一个数据库。必须经 Application 层。
const infrastructurePackages = <String>{
  'spider_host',
  'storage',
  'plugin_host',
};

final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+(['"])([^'"]+)\1''',
  multiLine: true,
);
final RegExp _ignoreComment = RegExp(
  r'//\s*ignore(?:_for_file)?:\s*(.*)$',
  multiLine: true,
);
final RegExp _reasonSeparator = RegExp(r'[—–]|\s-{1,2}\s|//');

/// 跑全部检查，返回所有违规。
Future<List<Violation>> runAllChecks(Directory root) async => [
  ...await checkPureDartPackage(
    Directory(p.join(root.path, 'packages', 'core_domain')),
    root: root,
  ),
  ...await checkForbiddenImports(
    Directory(p.join(root.path, 'apps', 'mistream', 'lib', 'features')),
    root: root,
    forbidden: infrastructurePackages,
    pathContains: p.join('lib', 'features'),
  ),
  ...await checkIgnoreComments(root),
];

/// 校验 [packageDir] 是纯 Dart 包：pubspec 依赖与源码 import 都在白名单内。
Future<List<Violation>> checkPureDartPackage(
  Directory packageDir, {
  required Directory root,
  Set<String> dartLibraries = allowedDartLibraries,
  Set<String> packages = allowedPackages,
}) async {
  if (!packageDir.existsSync()) {
    return [
      Violation(
        rule: 'pure-dart',
        file: _relative(packageDir.path, root),
        message: '目录不存在，无法校验',
      ),
    ];
  }

  final violations = <Violation>[
    ...await _checkPubspecDependencies(packageDir, root: root, allow: packages),
  ];

  final libDir = Directory(p.join(packageDir.path, 'lib'));
  await for (final file in _dartFiles(libDir)) {
    final content = await file.readAsString();
    for (final match in _directive.allMatches(content)) {
      final problem = _classify(
        match[2]!,
        dartLibraries: dartLibraries,
        packages: packages,
      );
      if (problem == null) continue;

      violations.add(
        Violation(
          rule: 'pure-dart',
          file: _relative(file.path, root),
          line: _lineOf(content, match.start),
          message: problem,
        ),
      );
    }
  }

  return violations;
}

/// 校验 [dir] 下的源码没有 import [forbidden] 里的包。
Future<List<Violation>> checkForbiddenImports(
  Directory dir, {
  required Directory root,
  required Set<String> forbidden,
  required String pathContains,
}) async {
  if (!dir.existsSync()) return const [];

  final violations = <Violation>[];
  await for (final file in _dartFiles(dir)) {
    final content = await file.readAsString();
    for (final match in _directive.allMatches(content)) {
      final uri = match[2]!;
      if (!uri.startsWith('package:')) continue;

      final name = uri.substring('package:'.length).split('/').first;
      if (!forbidden.contains(name)) continue;

      violations.add(
        Violation(
          rule: 'layering',
          file: _relative(file.path, root),
          line: _lineOf(content, match.start),
          message: 'Presentation 层不得直接依赖 $name，请经 Application 层',
        ),
      );
    }
  }
  return violations;
}

/// 校验每个 `// ignore:` 都写了理由（`docs/10-开发规范.md` §3.1）。
///
/// 无理由的 ignore 等于把一条规则永久关掉却不留线索，半年后没人知道还能不能
/// 打开。写一句为什么，成本一行，收益是这条 ignore 将来可以被清理。
///
/// 文档注释（`///`）整行跳过：在那里出现的 `// ignore:` 是在讲解规则，不是
/// 指令——本函数自己的文档就是头一个例子。字符串字面量里的同名文本仍会误判，
/// 那需要真正的语法分析，目前靠调用方拆开字面量规避。
Future<List<Violation>> checkIgnoreComments(Directory root) async {
  final violations = <Violation>[];

  await for (final file in _dartFiles(root)) {
    final lines = const LineSplitter().convert(await file.readAsString());
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('///')) continue;

      final match = _ignoreComment.firstMatch(lines[i]);
      if (match == null) continue;

      final tail = match[1]!.trim();
      if (_reasonSeparator.hasMatch(tail)) continue;

      violations.add(
        Violation(
          rule: 'ignore-reason',
          file: _relative(file.path, root),
          line: i + 1,
          message: 'ignore 必须写理由：`// ignore: $tail — 为什么`',
        ),
      );
    }
  }

  return violations;
}

Future<List<Violation>> _checkPubspecDependencies(
  Directory packageDir, {
  required Directory root,
  required Set<String> allow,
}) async {
  final pubspec = File(p.join(packageDir.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    return [
      Violation(
        rule: 'pure-dart',
        file: _relative(packageDir.path, root),
        message: '缺少 pubspec.yaml',
      ),
    ];
  }

  final doc = loadYaml(await pubspec.readAsString());
  final deps = doc is YamlMap ? doc['dependencies'] : null;
  if (deps is! YamlMap) return const [];

  return [
    for (final name in deps.keys.cast<String>())
      if (!allow.contains(name))
        Violation(
          rule: 'pure-dart',
          file: _relative(pubspec.path, root),
          message: '依赖「$name」不在白名单 ${_sorted(allow)}',
        ),
  ];
}

String? _classify(
  String uri, {
  required Set<String> dartLibraries,
  required Set<String> packages,
}) {
  if (uri.startsWith('dart:')) {
    final name = uri.substring('dart:'.length).split('/').first;
    if (dartLibraries.contains(name)) return null;
    return 'dart:$name 不在白名单 ${_sorted(dartLibraries)}';
  }

  if (uri.startsWith('package:')) {
    final name = uri.substring('package:'.length).split('/').first;
    // 包内自引用（package:core_domain/...）不算外部依赖。
    if (packages.contains(name) || name == 'core_domain') return null;
    return 'package:$name 不在白名单 ${_sorted(packages)}';
  }

  return null;
}

Stream<File> _dartFiles(Directory dir) async* {
  if (!dir.existsSync()) return;

  // 手工递归而不是 list(recursive: true)：后者会先钻进 .git 与 .dart_tool
  // 把成千上万个文件列出来再过滤，在这个仓库上慢得能感觉到。
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is Directory) {
      if (_isSkippedDirectory(p.basename(entity.path))) continue;
      yield* _dartFiles(entity);
      continue;
    }
    if (entity is! File) continue;

    final path = entity.path;
    if (!path.endsWith('.dart')) continue;
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;

    yield entity;
  }
}

bool _isSkippedDirectory(String segment) =>
    segment == '.dart_tool' ||
    segment == '.git' ||
    segment == 'build' ||
    segment == 'ephemeral' ||
    // drift schema 迁移验证代码（`melos run schema:update` 生成），
    // 与 `*.g.dart` 同样视为生成物，不参与分层纪律检查。
    segment == 'schema_versions.dart';

int _lineOf(String content, int offset) =>
    '\n'.allMatches(content.substring(0, offset)).length + 1;

String _relative(String path, Directory root) =>
    p.relative(path, from: root.path).replaceAll(r'\', '/');

String _sorted(Set<String> values) => (values.toList()..sort()).join(' ');
