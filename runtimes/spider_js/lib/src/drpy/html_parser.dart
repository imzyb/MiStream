/// drpy 宿主 API：伪 XPath HTML 解析器。
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

/// 解析规则字符串，返回 (selectors, extractor)。
/// selectors: 标签名/类名/id 链，extractor: Text 或属性名。
(List<String>, String) _parseRule(String rule) {
  final parts = rule.split('&&').map((s) => s.trim()).toList();
  final extractor = parts.last;
  final selectors = parts.take(parts.length - 1).toList();
  return (selectors, extractor);
}

/// 按选择器查找元素。
List<dom.Element> _query(dom.Element root, String selector) {
  if (selector.startsWith('.')) {
    return root.getElementsByClassName(selector.substring(1));
  }
  if (selector.startsWith('#')) {
    final el = root.querySelector('#${selector.substring(1)}');
    return el is dom.Element ? [el] : [];
  }
  // 标签名
  if (RegExp(r'^[a-zA-Z_][a-zA-Z0-9_-]*$').hasMatch(selector)) {
    return root.getElementsByTagName(selector);
  }
  return [];
}

/// 从元素提取属性值或文本。
String _extractAttr(dom.Element el, String attr) {
  if (attr == 'Text') return el.text.trim();
  final val = el.attributes[attr];
  if (val != null) return val;
  for (final entry in el.attributes.entries) {
    final k = entry.key as String;
    if (k.toLowerCase() == attr.toLowerCase()) return entry.value;
  }
  return '';
}

/// 伪 XPath 解析：返回第一个匹配结果。
String pdfh(String htmlInput, String rule) {
  final doc = html.parse(htmlInput);
  final root = doc.documentElement!;
  final (selectors, extractor) = _parseRule(rule);

  var current = <dom.Element>[root];
  for (final sel in selectors) {
    final next = <dom.Element>[];
    for (final el in current) {
      next.addAll(_query(el, sel));
    }
    current = next;
    if (current.isEmpty) return '';
  }

  if (current.isEmpty) return '';
  return _extractAttr(current.first, extractor);
}

/// 伪 XPath 解析：返回全部匹配结果。
List<String> pdfa(String htmlInput, String rule) {
  final doc = html.parse(htmlInput);
  final root = doc.documentElement!;
  final (selectors, extractor) = _parseRule(rule);

  var current = <dom.Element>[root];
  for (final sel in selectors) {
    final next = <dom.Element>[];
    for (final el in current) {
      next.addAll(_query(el, sel));
    }
    current = next;
    if (current.isEmpty) return [];
  }

  return current.map((el) => _extractAttr(el, extractor)).toList();
}

/// 伪 XPath 解析：返回第一个匹配文本（URL 解析暂不实现，保留参数接口）。
String pd(String htmlInput, String rule, String baseUrl) =>
    pdfh(htmlInput, rule);

/// 伪 XPath 解析：返回全部匹配文本列表。
List<String> pdfl(String htmlInput, String rule, String baseUrl) =>
    pdfa(htmlInput, rule);
