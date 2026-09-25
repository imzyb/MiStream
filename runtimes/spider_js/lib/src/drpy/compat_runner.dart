/// 兼容性测试集：`(HTML 快照, 规则, 期望输出)` 三元组运行器。
///
/// 这是 drpy 解析层（伪 XPath 的 `pdfh`/`pdfa`/`pd`/`pdfl`，JSON 的
/// `jsonpath`/`pjfh`/`pj`/`pjfa`）与编码层的回归测试套件。
/// 每条用例覆盖一个真实源中出现过的写法，确保改动不破坏已有兼容性。
///
/// docs/05-Spider引擎.md §2.2：「pdfh 的语义只能靠对齐真实源行为来确定。」
library;

import 'dart:convert';
import 'dart:io';

import 'package:spider_js/src/drpy/crypto.dart';
import 'package:spider_js/src/drpy/gbk.dart';
import 'package:spider_js/src/drpy/html_parser.dart';
import 'package:spider_js/src/drpy/json_parser.dart';
import 'package:spider_js/src/drpy/rsa.dart';

/// 一条兼容性测试用例。
class CompatCase {
  /// 构造测试用例。
  const CompatCase({
    required this.name,
    required this.method,
    required this.expected,
    this.html = '',
    this.rule = '',
    this.baseUrl,
    this.input,
    this.args,
  });

  /// 从 JSON map 解码。
  ///
  /// `html` / `rule` 对 HTML 解析类用例是必填的，但编码类用例（`gbkDecode`…）
  /// 用不上，所以从缺省空串起步；`input` 是编码类用例的入参。
  factory CompatCase.fromJson(Map<String, Object?> json) => CompatCase(
    name: json['name'] as String? ?? '',
    method: json['method'] as String? ?? 'pdfh',
    html: json['html'] as String? ?? '',
    rule: json['rule'] as String? ?? '',
    baseUrl: json['baseUrl'] as String?,
    input: json['input'],
    args: (json['args'] as List<Object?>?)?.cast<Object?>(),
    expected: json['expected']!,
  );

  /// 测试名称。
  final String name;

  /// 解析方法：pdfh / pdfa / pd / pdfl / gbkDecode / rsaX / aes。
  final String method;

  /// HTML 输入。
  final String html;

  /// 编码类用例的入参。
  ///
  /// 形态取决于方法：`gbkDecode` 接受字节数组（JSON 里是 `List<int>`）或
  /// 字符串（latin1 口径的字节串）。
  final Object? input;

  /// 位置参数形态用例的入参列表。
  ///
  /// `rsaX(mode, pub, encrypt, input, inBase64, key, outBase64)` 这类**纯位置
  /// 传参**的 API 用不上 `html`/`rule`/`input` 那套字段，单开一个列表更贴合
  /// 真实调用形态，也避免为一个 API 重复加七个命名参数。
  final List<Object?>? args;

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
        case 'jsonpath':
          // 位置参数：jsonObject, path。**总是返回数组**，命中不到就是空数组。
          final a = args ?? const <Object?>[];
          if (a.length < 2) {
            return (false, null, 'jsonpath 需要 2 个位置参数，实际 ${a.length} 个');
          }
          final result = jsonPathQuery(a[0], a[1].toString());
          final exp = expected as List<Object?>;
          if (_deepEquals(result, exp)) {
            return (true, result, null);
          }
          return (false, result, '期望 $exp，实际 $result');
        case 'pjfh':
          // `pjfh(html, parse)`：取单值，假值被 `|| ''` 吞掉。
          final result = pjfh(_decodeJsonLike(html), rule);
          if (_deepEquals(result, expected)) {
            return (true, result, null);
          }
          return (false, result, '期望 $expected，实际 $result');
        case 'pj':
          // `pj(html, parse)`：同 pjfh，但恒做 URL 拼接。
          final result = pj(
            _decodeJsonLike(html),
            rule,
            baseUrl: baseUrl ?? '',
          );
          if (_deepEquals(result, expected)) {
            return (true, result, null);
          }
          return (false, result, '期望 $expected，实际 $result');
        case 'pjfa':
          // `pjfa(html, parse)`：取数组。
          final result = pjfa(_decodeJsonLike(html), rule);
          if (_deepEquals(result, expected)) {
            return (true, result, null);
          }
          return (false, result, '期望 $expected，实际 $result');
        case 'gbkDecode':
          final result = gbkDecode(input ?? html);
          if (result == expected as String) {
            return (true, result, null);
          }
          return (false, result, '期望 "$expected"，实际 "$result"');
        case 'rsaX':
          // 位置参数：mode, pub, encrypt, input, inBase64, key, outBase64。
          final a = args ?? const <Object?>[];
          if (a.length < 7) {
            return (false, null, 'rsaX 需要 7 个位置参数，实际 ${a.length} 个');
          }
          final result = rsa(
            mode: a[0].toString(),
            pub: a[1] == true,
            encrypt: a[2] == true,
            input: a[3].toString(),
            inBase64: a[4] == true,
            key: a[5].toString(),
            outBase64: a[6] == true,
          );
          if (result == expected as String) {
            return (true, result, null);
          }
          return (false, result, '期望 "$expected"，实际 "$result"');
        case 'aes':
          // 位置参数：mode, encrypt, input, inBase64, key, iv, outBase64。
          final a = args ?? const <Object?>[];
          if (a.length < 7) {
            return (false, null, 'aes 需要 7 个位置参数，实际 ${a.length} 个');
          }
          final result = aes(
            mode: a[0].toString(),
            encrypt: a[1] == true,
            input: a[2].toString(),
            inBase64: a[3] == true,
            key: a[4].toString(),
            iv: a[5].toString(),
            outBase64: a[6] == true,
          );
          if (result == expected as String) {
            return (true, result, null);
          }
          return (false, result, '期望 "$expected"，实际 "$result"');
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

  /// 结构化比较：JSON 组的方法可能返回字符串、数字、数组或对象。
  ///
  /// `expected` 来自 JSON 文件，`result` 来自解析器，两者的数值类型可能不同
  /// （`3` 与 `3.0`），Dart 的 `==` 对此已经相等，所以只处理容器。
  static bool _deepEquals(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// 用例里的 `html` 字段对 JSON 组来说装的是 JSON 文本。
  ///
  /// 解析失败就原样返回——`pjfh` 自己也会做同样的处理（拿不到对象就给空串），
  /// 这样「JSON 文本非法」的用例也能照常覆盖。
  static Object? _decodeJsonLike(String html) {
    if (html.isEmpty) return '';
    try {
      return jsonDecode(html);
    } on FormatException {
      return html;
    }
  }

  /// 从 JSON 文件加载。
  static List<CompatCase> loadFromFile(String path) {
    final text = File(path).readAsStringSync();
    final list = jsonDecode(text) as List<Object?>;
    return list
        .map((e) => CompatCase.fromJson(e! as Map<String, Object?>))
        .toList();
  }

  /// 加载目录下全部 `*.json` 用例，按文件名排序以保证结果稳定。
  ///
  /// 用例按主题分文件（selector / index / url / extract / edge…），新增一种
  /// 真实源写法时往对应文件里追加即可，不必改任何 Dart 代码。
  static List<CompatCase> loadFromDirectory(String dir) {
    final files =
        Directory(dir)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    return <CompatCase>[
      for (final f in files) ...loadFromFile(f.path),
    ];
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
