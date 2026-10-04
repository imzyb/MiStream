import 'dart:io';

import 'package:quickjs_dist/quickjs_dist.dart';

const _usage = '''
用法：
  quickjs_dist install [--dest <目录>] [--vendor <目录>]
      把清单里的三个 DLL（校验 SHA256 后）装进目标目录，默认
      runtimes/spider_js/lib/src/engine。已存在且哈希匹配的直接复用。
  quickjs_dist verify [--dest <目录>]
      校验目标目录里的三个 DLL 是否与清单一致，不一致列出问题。
  quickjs_dist manifest
      打印当前清单的版本、平台与各文件哈希。

任何校验失败都退出码 1。清单见 tools/quickjs_dist/assets/quickjs.manifest.json。
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    stdout.write(_usage);
    exit(args.isEmpty ? 64 : 0);
  }

  final manifest = QuickjsManifest.fromJson(
    File.fromUri(
      Platform.script.resolve('../assets/quickjs.manifest.json'),
    ).readAsStringSync(),
  );
  final distribution = QuickjsDistribution(manifest: manifest);

  try {
    switch (args.first) {
      case 'install':
        await _install(distribution, args.skip(1).toList());
      case 'verify':
        await _verify(distribution, args.skip(1).toList());
      case 'manifest':
        _printManifest(manifest);
      default:
        stderr.writeln('未知命令「${args.first}」\n');
        stdout.write(_usage);
        exit(64);
    }
  } on QuickjsDistException catch (e) {
    stderr.writeln('quickjs 分发失败：$e');
    exit(1);
  }
}

Future<void> _install(
  QuickjsDistribution distribution,
  List<String> args,
) async {
  final repoRoot = Directory.fromUri(Platform.script.resolve('../../../'));
  final dest = Directory(_flag(args, 'dest') ?? _defaultEngineDir(repoRoot));
  final vendor = Directory(
    _flag(args, 'vendor') ??
        '${repoRoot.path}${Platform.pathSeparator}tools'
            '${Platform.pathSeparator}quickjs_dist'
            '${Platform.pathSeparator}vendor',
  );

  await distribution.install(vendor, dest);
  stdout.writeln(
    'QuickJS DLL 已就位（${distribution.manifest.platform} '
    '${distribution.manifest.version}）：${dest.path}',
  );
}

Future<void> _verify(
  QuickjsDistribution distribution,
  List<String> args,
) async {
  final repoRoot = Directory.fromUri(Platform.script.resolve('../../../'));
  final dest = Directory(_flag(args, 'dest') ?? _defaultEngineDir(repoRoot));
  final problems = await distribution.verify(dest);
  if (problems.isEmpty) {
    stdout.writeln('校验通过：${dest.path} 与清单一致');
    return;
  }
  stderr.writeln('校验失败：\n  ${problems.join('\n  ')}');
  exit(1);
}

void _printManifest(QuickjsManifest manifest) {
  stdout
    ..writeln('QuickJS DLL 清单：${manifest.version}（${manifest.platform}）')
    ..writeln('文件数：${manifest.files.length}');
  for (final entry in manifest.files.entries) {
    stdout.writeln('  ${entry.key}  ${entry.value}');
  }
}

String _defaultEngineDir(Directory repoRoot) {
  final sep = Platform.pathSeparator;
  final root = repoRoot.path;
  final trimmed = root.endsWith(sep)
      ? root.substring(0, root.length - 1)
      : root;
  return '$trimmed${sep}runtimes${sep}spider_js${sep}lib${sep}src${sep}engine';
}

String? _flag(List<String> args, String name) {
  final index = args.indexOf('--$name');
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}
