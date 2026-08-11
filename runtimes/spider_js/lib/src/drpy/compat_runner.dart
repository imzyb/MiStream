/// 兼容性测试集：`(HTML 快照, 规则, 期望输出)` 三元组运行器。
///
/// 这是 drpy 伪 XPath 解析器（`pdfh`/`pdfa`/`pd`/`pdfl`）的回归测试套件。
/// 每条用例覆盖一个真实源中出现过的写法，确保改动不破坏已有兼容性。
///
/// docs/05-Spider引擎.md §2.2：「pdfh 的语义只能靠对齐真实源行为来确定。」
library;

import 'dart:convert';
import 'dart:io';

import 'package:spider_js/src/drpy/html_parser.dart';

/// 一条兼容性测试用例。
class CompatCase {
  /// 构造测试用例。
  const CompatCase({
    required this.name,
    required this.method,
    required this.html,
    required this.rule,
    required this.expected,
    this.baseUrl,
  });

  /// 从 JSON map 解码。
  factory CompatCase.fromJson(Map<String, Object?> json) => CompatCase(
    name: json['name'] as String? ?? '',
    method: json['method'] as String? ?? 'pdfh',
    html: json['html'] as String? ?? '',
    rule: json['rule'] as String? ?? '',
    baseUrl: json['baseUrl'] as String?,
    expected: json['expected']!,
  );

  /// 测试名称。
  final String name;

  /// 解析方法：pdfh / pdfa / pd / pdfl。
  final String method;

  /// HTML 输入。
  final String html;

  /// 伪 XPath 规则。
  final String rule;

  /// 基础 URL（pd/pdfl 用）。
  final String? baseUrl;

  /// 期望输出。
  final Object expected;

  /// 执行测试，返回 (通过, 实际输出, 错误信息)。
  (bool, Object?, String?) run() {
    try {
      switch (method) {
        case 'pdfh':
          final result = pdfh(html, rule);
          if (result == expected as String) {
            return (true, result, null);
          }
          return (false, result, '期望 "$expected"，实际 "$result"');
        case 'pdfa':
          final result = pdfa(html, rule);
          final exp = (expected as List<Object?>).cast<String>();
          if (_listEquals(result, exp)) {
            return (true, result, null);
          }
          return (false, result, '期望 $exp，实际 $result');
        case 'pd':
          final result = pd(html, rule, baseUrl ?? '');
          if (result == expected as String) {
            return (true, result, null);
          }
          return (false, result, '期望 "$expected"，实际 "$result"');
        case 'pdfl':
          final result = pdfl(html, rule, baseUrl ?? '');
          final exp = (expected as List<Object?>).cast<String>();
          if (_listEquals(result, exp)) {
            return (true, result, null);
          }
          return (false, result, '期望 $exp，实际 $result');
        default:
          return (false, null, '未知方法: $method');
      }
    } on Object catch (e, st) {
      return (false, null, '异常: $e\n$st');
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 从 JSON 文件加载。
  static List<CompatCase> loadFromFile(String path) {
    final text = File(path).readAsStringSync();
    final list = jsonDecode(text) as List<Object?>;
    return list
        .map((e) => CompatCase.fromJson(e! as Map<String, Object?>))
        .toList();
  }
}

/// 运行一组兼容性测试。
///
/// 返回 (通过数, 总用例数, 失败详情列表)。
(List<CompatCase>, int, int, List<String>) runCompatTests(
  List<CompatCase> cases,
) {
  final failures = <String>[];
  var passed = 0;

  for (final testCase in cases) {
    final (ok, actual, error) = testCase.run();
    if (ok) {
      passed++;
    } else {
      failures.add('${testCase.name}: $error');
    }
  }

  return (cases, passed, cases.length - passed, failures);
}
