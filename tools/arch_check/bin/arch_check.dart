import 'dart:io';

import 'package:arch_check/arch_check.dart';

Future<void> main(List<String> args) async {
  final root = Directory(args.isEmpty ? Directory.current.path : args.first);

  if (!Directory('${root.path}/packages').existsSync()) {
    stderr.writeln('${root.path} 看起来不是 MiStream 仓库根');
    exit(64);
  }

  final violations = await runAllChecks(root);

  if (violations.isEmpty) {
    stdout.writeln('分层纪律检查通过');
    return;
  }

  stderr.writeln('分层纪律检查未通过，共 ${violations.length} 处：');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  stderr
    ..writeln()
    ..writeln('规则见 docs/10-开发规范.md §3.1 与 §3.3');
  exit(1);
}
