/// Conventional Commits 校验。
///
/// 规则来源：`docs/10-开发规范.md` §2。
///
/// 为什么自己写而不用 npm 的 commitlint：这个仓库是纯 Dart/Flutter，为了校验
/// 提交信息引入一整棵 node_modules（外加 package-lock、dependabot 的第二个
/// 生态、每个 CI job 里装 Node）不划算。而且 type/scope 白名单和「subject 用
/// 中文」这类项目约定本来就要自己配，用现成工具也省不掉。
library;

import 'dart:convert';

import 'package:meta/meta.dart';

/// 问题的严重程度。
enum CommitLintSeverity {
  /// 阻断提交。
  error,

  /// 只提示，不阻断。
  warning,
}

/// 一条校验结果。
@immutable
final class CommitLintIssue {
  /// 构造一条校验结果。
  const CommitLintIssue(this.severity, this.rule, this.message);

  /// 严重程度。
  final CommitLintSeverity severity;

  /// 规则名，出现在输出里方便对照文档。
  final String rule;

  /// 人读的说明。
  final String message;

  @override
  String toString() {
    final tag = severity == CommitLintSeverity.error ? 'error' : 'warn ';
    return '$tag  [$rule] $message';
  }
}

/// 提交信息校验器。
@immutable
final class CommitLinter {
  /// 构造一个校验器。
  const CommitLinter({
    this.types = defaultTypes,
    this.scopes = defaultScopes,
    this.maxSubjectLength = 50,
  });

  /// 允许的 type（`docs/10-开发规范.md` §2）。
  static const defaultTypes = <String>{
    'build',
    'chore',
    'ci',
    'docs',
    'feat',
    'fix',
    'perf',
    'refactor',
    'revert',
    'test',
  };

  /// 允许的 scope，对应架构里的模块（`docs/10-开发规范.md` §2）。
  static const defaultScopes = <String>{
    'ci',
    'config',
    'deps',
    'domain',
    'logging',
    'player',
    'plugin',
    'rpc',
    'sdk',
    'sniffer',
    'spider',
    'spider-js',
    'storage',
    'theme',
    'tools',
    'ui',
    'updater',
  };

  /// subject 的字符数上限。按字符（rune）计，中文一个字算一个。
  final int maxSubjectLength;

  /// 允许的 type 集合。
  final Set<String> types;

  /// 允许的 scope 集合。
  final Set<String> scopes;

  static final RegExp _header = RegExp(r'^(\w+)(?:\(([^()]*)\))?(!)?: (.*)$');
  static final RegExp _looseHeader = RegExp(r'^(\w+)(?:\([^()]*\))?(!)?:(.*)$');
  static final RegExp _scissors = RegExp(r'^#\s*-+\s*>8\s*-+');
  static final RegExp _generated = RegExp(
    '''^(Merge |Revert ")|^(fixup|squash|amend)!''',
  );
  static final RegExp _cjk = RegExp('[一-鿿]');

  /// 去掉注释行与 `--verbose` 附带的 diff，返回真正的提交信息。
  static String clean(String raw) {
    final kept = <String>[];
    for (final line in const LineSplitter().convert(raw)) {
      if (_scissors.hasMatch(line)) break;
      if (line.startsWith('#')) continue;
      kept.add(line);
    }
    return kept.join('\n').trim();
  }

  /// 这条信息是否为 git 自动生成、不该受规范约束。
  static bool isGenerated(String message) => _generated.hasMatch(message);

  /// 校验一条提交信息。返回空列表表示完全合规。
  List<CommitLintIssue> lint(String rawMessage) {
    final message = clean(rawMessage);
    final issues = <CommitLintIssue>[];

    if (message.isEmpty) {
      return const [
        CommitLintIssue(CommitLintSeverity.error, 'empty', '提交信息为空'),
      ];
    }

    // merge / revert / fixup 由 git 生成，改不了格式，也不该拦。
    if (isGenerated(message)) return const [];

    final lines = const LineSplitter().convert(message);
    final header = lines.first;

    final match = _header.firstMatch(header);
    if (match == null) {
      issues.add(
        CommitLintIssue(
          CommitLintSeverity.error,
          'header-format',
          _explainHeaderFailure(header),
        ),
      );
      return issues;
    }

    final type = match[1]!;
    final scope = match[2];
    final subject = match[4]!;

    if (!types.contains(type)) {
      issues.add(
        CommitLintIssue(
          CommitLintSeverity.error,
          'type-enum',
          'type「$type」不在白名单：${_sorted(types)}',
        ),
      );
    }

    if (scope != null) {
      if (scope.isEmpty) {
        issues.add(
          const CommitLintIssue(
            CommitLintSeverity.error,
            'scope-empty',
            'scope 括号为空。没有合适的 scope 就整个省略括号',
          ),
        );
      } else if (!scopes.contains(scope)) {
        issues.add(
          CommitLintIssue(
            CommitLintSeverity.error,
            'scope-enum',
            'scope「$scope」不在白名单：${_sorted(scopes)}。'
                '确实需要新 scope，请先改 docs/10-开发规范.md §2',
          ),
        );
      }
    }

    issues
      ..addAll(_lintSubject(subject))
      ..addAll(_lintBody(lines));

    return issues;
  }

  List<CommitLintIssue> _lintSubject(String subject) {
    final issues = <CommitLintIssue>[];

    if (subject.trim().isEmpty) {
      issues.add(
        const CommitLintIssue(
          CommitLintSeverity.error,
          'subject-empty',
          'subject 为空',
        ),
      );
      return issues;
    }

    if (subject != subject.trim()) {
      issues.add(
        const CommitLintIssue(
          CommitLintSeverity.error,
          'subject-whitespace',
          'subject 首尾有多余空白',
        ),
      );
    }

    final length = subject.runes.length;
    if (length > maxSubjectLength) {
      issues.add(
        CommitLintIssue(
          CommitLintSeverity.error,
          'subject-max-length',
          'subject 有 $length 字，上限 $maxSubjectLength。细节写进 body',
        ),
      );
    }

    if (subject.endsWith('.') || subject.endsWith('。')) {
      issues.add(
        const CommitLintIssue(
          CommitLintSeverity.error,
          'subject-full-stop',
          'subject 结尾不要句号',
        ),
      );
    }

    // 只警告不拦：偶尔出现的英文术语标题（如 `fix(deps): bump melos`）
    // 拦下来只会逼人写出更别扭的中文。
    if (!_cjk.hasMatch(subject)) {
      issues.add(
        const CommitLintIssue(
          CommitLintSeverity.warning,
          'subject-language',
          '本项目约定 subject 用中文（docs/10 §2）',
        ),
      );
    }

    return issues;
  }

  List<CommitLintIssue> _lintBody(List<String> lines) {
    if (lines.length < 2) return const [];

    if (lines[1].trim().isNotEmpty) {
      return const [
        CommitLintIssue(
          CommitLintSeverity.error,
          'body-leading-blank',
          'header 与 body 之间需要一个空行',
        ),
      ];
    }

    return const [];
  }

  String _explainHeaderFailure(String header) {
    final loose = _looseHeader.firstMatch(header);
    if (loose != null && !loose[3]!.startsWith(' ')) {
      return '冒号后面要有一个空格：`type(scope): subject`';
    }
    if (header.contains(':')) {
      return 'header 不符合 `type(scope): subject`，实际是「$header」';
    }
    return 'header 缺少 type 前缀，应为 `type(scope): subject`，实际是「$header」';
  }

  static String _sorted(Set<String> values) =>
      (values.toList()..sort()).join(' ');
}
