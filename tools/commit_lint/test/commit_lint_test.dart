import 'package:commit_lint/commit_lint.dart';
import 'package:test/test.dart';

void main() {
  const linter = CommitLinter();

  List<String> rulesOf(String message) =>
      linter.lint(message).map((issue) => issue.rule).toList();

  bool passes(String message) => linter.lint(message).isEmpty;

  group('合规样例', () {
    test('文档里的示例', () {
      expect(
        passes('''
feat(spider-js): 实现 pdfh 选择器的 &&Text 与 &&Html 语义

补齐 drpy 兼容层中最常用的两种取值方式，并加入 12 条回归用例。

Closes #45'''),
        isTrue,
      );
    });

    test('省略 scope', () {
      expect(passes('docs: 补充里程碑出口标准'), isTrue);
    });

    test('breaking change 标记', () {
      expect(passes('feat(rpc)!: 分帧改为长度前缀'), isTrue);
    });

    test('只有 header', () {
      expect(passes('chore(deps): 升级 melos'), isTrue);
    });
  });

  group('header 格式', () {
    test('缺 type 前缀', () {
      expect(rulesOf('随手改了点东西'), ['header-format']);
    });

    test('冒号后缺空格时给出针对性提示', () {
      final issues = linter.lint('feat(ui):加个按钮');

      expect(issues.single.rule, 'header-format');
      expect(issues.single.message, contains('空格'));
    });

    test('空提交信息', () {
      expect(rulesOf('   \n  '), ['empty']);
    });

    test('只有注释行也算空', () {
      expect(rulesOf('# 请输入提交信息\n# 以 # 开头的行会被忽略'), ['empty']);
    });
  });

  group('白名单', () {
    test('type 不在白名单', () {
      expect(rulesOf('update(ui): 改点东西'), ['type-enum']);
    });

    test('scope 不在白名单，提示去改文档', () {
      final issues = linter.lint('feat(奇怪的模块): 加功能');

      expect(issues.single.rule, 'scope-enum');
      expect(issues.single.message, contains('docs/10-开发规范.md'));
    });

    test('空括号要么填要么删', () {
      expect(rulesOf('feat(): 加功能'), ['scope-empty']);
    });
  });

  group('subject', () {
    test('超长', () {
      final long = 'feat(ui): ${'字' * 51}';

      expect(rulesOf(long), ['subject-max-length']);
    });

    test('刚好 50 字通过', () {
      expect(passes('feat(ui): ${'字' * 50}'), isTrue);
    });

    test('中英文都按字符数算，不按字节', () {
      // 50 个汉字若按 UTF-8 字节算是 150，会被误判超长。
      expect(passes('feat(ui): ${'字' * 50}'), isTrue);
      expect(rulesOf('feat(ui): ${'a' * 51}'), contains('subject-max-length'));
    });

    test('结尾句号', () {
      expect(rulesOf('feat(ui): 加个按钮。'), ['subject-full-stop']);
      expect(rulesOf('feat(ui): 加个按钮.'), ['subject-full-stop']);
    });

    test('英文 subject 只警告，不阻断', () {
      final issues = linter.lint('chore(deps): bump melos to 7.0.0');

      expect(issues.single.rule, 'subject-language');
      expect(issues.single.severity, CommitLintSeverity.warning);
    });
  });

  group('body', () {
    test('header 与 body 之间缺空行', () {
      expect(
        rulesOf('feat(ui): 加个按钮\n紧接着就写正文'),
        ['body-leading-blank'],
      );
    });
  });

  group('自动生成的信息直接放行', () {
    test('merge', () {
      expect(passes("Merge branch 'main' into feat/x"), isTrue);
    });

    test('revert', () {
      expect(passes('Revert "feat(ui): 加个按钮"'), isTrue);
    });

    test('fixup / squash', () {
      expect(passes('fixup! feat(ui): 加个按钮'), isTrue);
      expect(passes('squash! feat(ui): 加个按钮'), isTrue);
    });

    test('手写的 revert type 仍然要合规', () {
      expect(rulesOf('revert(ui): 撤销按钮改动.'), ['subject-full-stop']);
    });
  });

  group('clean', () {
    test('去掉注释行', () {
      expect(
        CommitLinter.clean('feat(ui): 加个按钮\n# 这行是注释'),
        'feat(ui): 加个按钮',
      );
    });

    test('切掉 --verbose 附带的 diff', () {
      const raw = '''
feat(ui): 加个按钮

# ------------------------ >8 ------------------------
diff --git a/x b/x
+这是 diff，不是提交信息''';

      expect(CommitLinter.clean(raw), 'feat(ui): 加个按钮');
    });
  });
}
