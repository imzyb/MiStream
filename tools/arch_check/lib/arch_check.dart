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
  ...await checkScriptEncoding(root),
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
    final lines = const LineSplitter().convert(content);
    for (final match in _directive.allMatches(content)) {
      final uri = match[2]!;
      if (!uri.startsWith('package:')) continue;

      final name = uri.substring('package:'.length).split('/').first;
      if (!forbidden.contains(name)) continue;

      final lineIdx = _lineOf(content, match.start) - 1;
      final line = lineIdx >= 0 && lineIdx < lines.length ? lines[lineIdx] : '';
      // 允许 `// ignore: layering -- 理由` 显式豁免
      if (line.contains('ignore:') && line.contains('layering')) continue;

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

/// 校验含非 ASCII 的 PowerShell 脚本都带 UTF-8 BOM。
///
/// Windows PowerShell 5.1 的 `-File` 对**没有 BOM** 的脚本按 ANSI 码页解码，
/// 不看文件里有什么内容。中文因此被拆成乱码，而且乱码还会把紧随其后的 ASCII
/// 字符（`$`、`"`）一起吃掉——脚本被悄悄改写成另一个程序，且改法随码页而变：
///
/// - 本机 ANSI=CP936 时 `tools/release_check.ps1` 仍能解析，但 `$files` 的赋值
///   整段被吞进字符串字面量，扫描恒为 0 个文件、合规门禁恒过；
/// - CI runner ANSI=CP1252 时同一份文件直接
///   `ParserError: The string is missing the terminator: "`，把 Release 打挂
///   （CI run 37029615096 第 11 步）。
///
/// 加 BOM 是唯一能让两种码页都读到正确文本的改法。纯 ASCII 的脚本不受影响，
/// 所以只约束含非 ASCII 的文件。
Future<List<Violation>> checkScriptEncoding(Directory root) async {
  const bom = [0xEF, 0xBB, 0xBF];
  final violations = <Violation>[];

  await for (final file in _filesWithExtension(root, const {'.ps1', '.psm1'})) {
    final bytes = await file.readAsBytes();
    if (!bytes.any((byte) => byte > 0x7F)) continue;

    final hasBom =
        bytes.length >= 3 &&
        bytes[0] == bom[0] &&
        bytes[1] == bom[1] &&
        bytes[2] == bom[2];
    if (hasBom) continue;

    violations.add(
      Violation(
        rule: 'ps1-bom',
        file: _relative(file.path, root),
        message:
            '含非 ASCII 的 PowerShell 脚本必须带 UTF-8 BOM：无 BOM 时 Windows PowerShell 5.1 按 ANSI 码页解码，中文会连带吃掉紧随其后的 ASCII 字符（美元符、引号），在 CP936 上静默失效、在 CP1252 上直接 ParserError',
      ),
    );
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

Stream<File> _filesWithExtension(Directory dir, Set<String> extensions) async* {
  if (!dir.existsSync()) return;

  await for (final entity in dir.list(followLinks: false)) {
    if (entity is Directory) {
      if (_isSkippedDirectory(p.basename(entity.path))) continue;
      yield* _filesWithExtension(entity, extensions);
      continue;
    }
    if (entity is! File) continue;
    if (extensions.any(entity.path.endsWith)) yield entity;
  }
}

bool _isSkippedDirectory(String segment) =>
    segment == '.dart_tool' ||
    segment == '.git' ||
    segment == 'build' ||
    segment == 'ephemeral' ||
    // 工具暂存目录：不在版本控制里（见 .gitignore），装的是排查问题时写的一次性
    // 探针脚本。它们**不是项目源码**，不该被分层纪律与 ignore 理由规则管——真
    // 按源码标准要求，一次探针就会把 M0 门禁顶红，而那和产品代码的健康度无关。
    // （`analyze_inproc.dart` 这类长期用的脚本也在这里，需要它时直接跑。）
    segment == '.workbuddy-ai' ||
    // drift schema 迁移验证代码（`melos run schema:update` 生成），
    // 与 `*.g.dart` 同样视为生成物，不参与分层纪律检查。
    segment == 'schema_versions.dart';

int _lineOf(String content, int offset) =>
    '\n'.allMatches(content.substring(0, offset)).length + 1;

String _relative(String path, Directory root) =>
    p.relative(path, from: root.path).replaceAll(r'\', '/');

String _sorted(Set<String> values) => (values.toList()..sort()).join(' ');
