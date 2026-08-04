import 'dart:io';

import 'package:commit_lint/commit_lint.dart';

const _usage = '''
用法：
  commit_lint <file>            校验文件内容（.githooks/commit-msg 用法）
  commit_lint -                 从 stdin 读
  commit_lint --message <text>  直接校验一段文本
  commit_lint --range <range>   校验 git 区间内每条提交（CI 用法）

任一条存在 error 即以退出码 1 结束；warning 只打印。
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    stdout.write(_usage);
    exit(args.isEmpty ? 64 : 0);
  }

  const linter = CommitLinter();
  final failed = switch (args.first) {
    '--range' => await _lintRange(linter, _requireValue(args, '--range')),
    '--message' => _report(linter, _requireValue(args, '--message')),
    '-' => _report(linter, await _readStdin()),
    _ => _report(linter, await File(args.first).readAsString()),
  };

  exit(failed ? 1 : 0);
}

String _requireValue(List<String> args, String flag) {
  if (args.length < 2) {
    stderr.writeln('$flag 需要一个参数');
    exit(64);
  }
  return args[1];
}

Future<String> _readStdin() async {
  final buffer = StringBuffer();
  await for (final chunk in stdin) {
    buffer.write(String.fromCharCodes(chunk));
  }
  return buffer.toString();
}

/// 校验一条信息，返回是否存在 error。
bool _report(CommitLinter linter, String message, {String? label}) {
  final issues = linter.lint(message);
  if (issues.isEmpty) return false;

  final header = CommitLinter.clean(message).split('\n').firstOrNull ?? '';
  final where = label == null ? '' : ' ($label)';
  stderr.writeln('提交信息不合规$where：$header');
  for (final issue in issues) {
    stderr.writeln('  $issue');
  }

  final failed = issues.any(
    (issue) => issue.severity == CommitLintSeverity.error,
  );
  if (failed) {
    stderr.writeln('  规范见 docs/10-开发规范.md §2');
  }
  stderr.writeln();
  return failed;
}

Future<bool> _lintRange(CommitLinter linter, String range) async {
  final log = await Process.run('git', ['log', '--format=%H', range]);
  if (log.exitCode != 0) {
    stderr.writeln('git log $range 失败：${log.stderr}');
    exit(1);
  }

  final shas = (log.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (shas.isEmpty) {
    stdout.writeln('区间 $range 内没有提交，跳过');
    return false;
  }

  var failed = false;
  for (final sha in shas) {
    final show = await Process.run('git', ['log', '-1', '--format=%B', sha]);
    if (show.exitCode != 0) {
      stderr.writeln('读取 $sha 失败：${show.stderr}');
      failed = true;
      continue;
    }
    if (_report(linter, show.stdout as String, label: sha.substring(0, 8))) {
      failed = true;
    }
  }

  if (!failed) {
    stdout.writeln('${shas.length} 条提交信息全部合规');
  }
  return failed;
}
