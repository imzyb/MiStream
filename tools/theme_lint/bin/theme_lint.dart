import 'dart:convert';
import 'dart:io';

import 'package:theme_engine/theme_engine.dart';
import 'package:theme_lint/theme_lint.dart';

const _usage = '''
用法：
  theme_lint <theme.json>          校验一个主题包清单
  theme_lint -                     从 stdin 读
  theme_lint --base dark <file>    指定叠加的基准主题（默认按 brightness 推断）
  theme_lint --ratios <file>       额外打印每对前景/背景的实测比值

即 docs/06-插件系统.md §9 里提到的 `mistream theme lint`。
存在 error 时以退出码 1 结束；warning / info 只打印。
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage);
    exit(args.isEmpty ? 64 : 0);
  }

  final showRatios = args.contains('--ratios');
  final base = _parseBase(args);
  final source = args.where((a) => !a.startsWith('--')).toList();
  if (source.isEmpty) {
    stderr.writeln('缺少输入文件。\n');
    stderr.write(_usage);
    exit(64);
  }
  if (source.length > 1) {
    stderr.writeln('一次只能校验一个文件（收到 ${source.length} 个）');
    exit(64);
  }

  final text = source.single == '-'
      ? await stdin.transform(utf8.decoder).join()
      : _readFile(source.single);
  final label = source.single == '-' ? '<stdin>' : source.single;

  final report = const ThemeLinter().lint(text, base: base);
  _print(label, report, showRatios: showRatios);

  exit(report.hasError ? 1 : 0);
}

/// 命令行给的 `--base` 优先，其次看包自己声明的 `brightness`（在 [ThemeLinter]
/// 里推断）。这里只处理显式指定的情况。
AppTheme? _parseBase(List<String> args) {
  final i = args.indexOf('--base');
  if (i < 0) return null;
  if (i + 1 >= args.length) {
    stderr.writeln('--base 需要一个参数（dark / light / oled）');
    exit(64);
  }
  final name = args[i + 1];
  final theme = AppTheme.builtInsMap[name];
  if (theme == null) {
    stderr.writeln(
      '未知的基准主题 "$name"，可选：${AppTheme.builtInsMap.keys.join(' / ')}',
    );
    exit(64);
  }
  return theme;
}

String _readFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('文件不存在：$path');
    exit(66);
  }
  return file.readAsStringSync();
}

void _print(String label, LintReport report, {required bool showRatios}) {
  // 问题按级别从重到轻排，作者最先看到的就是最该改的。
  const order = [LintSeverity.error, LintSeverity.warning, LintSeverity.info];
  const mark = {
    LintSeverity.error: '错误',
    LintSeverity.warning: '警告',
    LintSeverity.info: '提示',
  };

  final out = report.hasError ? stderr : stdout;

  for (final severity in order) {
    for (final issue in report.where(severity)) {
      out.writeln('[${mark[severity]}] ${issue.message}');
      if (issue.hint != null) out.writeln('         ${issue.hint}');
    }
  }

  if (showRatios && report.ratios.isNotEmpty) {
    out.writeln();
    out.writeln('对比度实测（门槛：正文 4.5，UI 组件 3.0）：');
    final names = report.ratios.keys.toList()..sort();
    for (final name in names) {
      out.writeln(
        '  ${report.ratios[name]!.toStringAsFixed(2).padLeft(6)}  $name',
      );
    }
  }

  out.writeln();
  if (report.hasError) {
    out.writeln('$label：存在 error，装上会被拒绝加载');
  } else {
    final warns = report.where(LintSeverity.warning).length;
    out.writeln(
      '$label：通过${warns == 0 ? '' : '（$warns 条警告）'}'
      '，生效主题 id=${report.theme?.id}',
    );
  }
}
