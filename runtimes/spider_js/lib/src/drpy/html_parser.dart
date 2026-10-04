/// drpy 宿主 API：伪 XPath HTML 解析器。
///
/// 规则形如 `选择器&&选择器&&…&&提取器`：`&&` 分段，最后一段是提取器
/// （`Text` / `Html` / 属性名），其余每段是一个选择器，逐级向下查找。
///
/// 选择器在标准 CSS 之上支持 drpy 的位置伪类——`:eq(n)`（n 可为负，-1 指
/// 最后一个）、`:first`、`:last`、`:gt(n)`、`:lt(n)`、`:contains(文本)`。
/// 这些不是 CSS，csslib 认不了，所以先从尾部摘出来单独处理，剩下的交给
/// `querySelectorAll`——真实源里 `div.item`、`[data-id=3]`、
/// `.a .b` 这类写法能用，靠的就是它。
///
/// docs/05-Spider引擎.md §2.2：「pdfh 的语义只能靠对齐真实源行为来确定。」
/// 因此每支持一种新写法，都要往 `test/compat/` 里补一条对应用例。
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:spider_js/src/drpy/crypto.dart' show joinUrl;

/// 位置伪类：作用在一组元素上的过滤动作。
typedef _Filter = List<dom.Element> Function(List<dom.Element>);

/// 匹配选择器尾部的一个位置伪类。
///
/// 两个分支：带参的 `:eq(1)` / `:contains(x)`，与无参的 `:first` / `:last`。
final RegExp _pseudo = RegExp(
  r'(?::(eq|gt|lt|contains)\(([^)]*)\)|:(first|last))$',
);

/// 拆规则，返回 (选择器链, 提取器)。
(List<String>, String) _parseRule(String rule) {
  final parts = rule.split('&&').map((s) => s.trim()).toList();
  return (parts.take(parts.length - 1).toList(), parts.last);
}

/// 把位置伪类从选择器尾部逐个剥离，返回 (纯 CSS 选择器, 过滤器链)。
///
/// 从尾部摘、往队首插，是为了让 `a:gt(0):lt(2)` 这种链按书写顺序生效。
(String, List<_Filter>) _stripPseudo(String selector) {
  var css = selector.trim();
  final filters = <_Filter>[];
  while (true) {
    final m = _pseudo.firstMatch(css);
    if (m == null) break;
    css = css.substring(0, m.start).trim();
    filters.insert(0, _filterFor(m));
  }
  return (css, filters);
}

/// 把一次伪类匹配翻译成过滤器。
_Filter _filterFor(RegExpMatch m) {
  switch (m.group(3)) {
    case 'first':
      return (els) => els.isEmpty ? els : <dom.Element>[els.first];
    case 'last':
      return (els) => els.isEmpty ? els : <dom.Element>[els.last];
  }

  final arg = m.group(2)!.trim();
  switch (m.group(1)) {
    case 'eq':
      final n = int.tryParse(arg);
      if (n == null) return (_) => const <dom.Element>[];
      return (els) {
        final i = n < 0 ? els.length + n : n;
        return i >= 0 && i < els.length
            ? <dom.Element>[els[i]]
            : const <dom.Element>[];
      };
    case 'gt':
      final n = int.tryParse(arg);
      if (n == null) return (_) => const <dom.Element>[];
      return (els) {
        final i = n < 0 ? els.length + n : n;
        return i + 1 >= els.length
            ? const <dom.Element>[]
            : els.sublist(i < 0 ? 0 : i + 1);
      };
    case 'lt':
      final n = int.tryParse(arg);
      if (n == null) return (_) => const <dom.Element>[];
      return (els) {
        final i = n < 0 ? els.length + n : n;
        return els.sublist(0, i.clamp(0, els.length));
      };
    case 'contains':
      final needle = _unquote(arg);
      return (els) => els.where((e) => e.text.contains(needle)).toList();
    default:
      return (els) => els;
  }
}

/// 去掉伪类实参外面的引号：`:contains('片名')` 与 `:contains(片名)` 等价。
String _unquote(String s) {
  if (s.length >= 2 &&
      ((s.startsWith("'") && s.endsWith("'")) ||
          (s.startsWith('"') && s.endsWith('"')))) {
    return s.substring(1, s.length - 1);
  }
  return s;
}

/// 用一个选择器把当前元素集推进一级。
List<dom.Element> _step(List<dom.Element> current, String selector) {
  final (css, filters) = _stripPseudo(selector);

  final next = <dom.Element>[];
  for (final el in current) {
    next.addAll(_cssQuery(el, css));
  }

  // 位置伪类作用在**合并后**的集合上——cheerio / jQuery 就是这个语义。
  // 逐元素各取各的话，`.list&&a:eq(1)` 在页面有多个 .list 时会返回多条，
  // 而真实源写这条规则时要的是「所有 a 里的第 2 个」。
  var result = next;
  for (final f in filters) {
    result = f(result);
  }
  return result;
}

/// 执行一个纯 CSS 选择器。
List<dom.Element> _cssQuery(dom.Element root, String css) {
  // 选择器只有伪类（如 `:eq(1)`）时，这一级不缩小范围，交给过滤器处理。
  if (css.isEmpty) return <dom.Element>[root];
  try {
    return root.querySelectorAll(css);
  } on Object {
    // 手写规则里出现 csslib 认不了的写法是常态，不能把整个引擎带崩。
    return const <dom.Element>[];
  }
}

/// 按规则选出元素集，并把提取器一并带回。
(List<dom.Element>, String) _select(String htmlInput, String rule) {
  final (selectors, extractor) = _parseRule(rule);
  final root = html.parse(htmlInput).documentElement;
  if (root == null) return (const <dom.Element>[], extractor);

  var current = <dom.Element>[root];
  for (final sel in selectors) {
    current = _step(current, sel);
    if (current.isEmpty) break;
  }
  return (current, extractor);
}

/// 从元素取出提取器指定的值。
String _extract(dom.Element el, String extractor) {
  switch (extractor) {
    case 'Text' || 'text':
      return el.text.trim();
    case 'Html' || 'html':
      return el.innerHtml;
  }

  final val = el.attributes[extractor];
  if (val != null) return val;
  // HTML 属性名大小写不敏感，而真实源里 `data-Src` 这类写法都有。
  for (final entry in el.attributes.entries) {
    if ('${entry.key}'.toLowerCase() == extractor.toLowerCase()) {
      return entry.value;
    }
  }
  return '';
}

/// 把相对地址按 [baseUrl] 补成绝对地址。
///
/// 空值与空 base 原样返回；已是绝对地址的由 [joinUrl] 直接放行。
String _resolve(String value, String baseUrl) {
  if (value.isEmpty || baseUrl.isEmpty) return value;
  try {
    return joinUrl(baseUrl, value);
  } on Object {
    // base 或值畸形时，返回原值比抛异常有用——源作者能从结果里看出问题。
    return value;
  }
}

/// 伪 XPath 解析：返回第一个匹配结果。
String pdfh(String htmlInput, String rule) {
  final (els, extractor) = _select(htmlInput, rule);
  return els.isEmpty ? '' : _extract(els.first, extractor);
}

/// 伪 XPath 解析：返回全部匹配结果。
List<String> pdfa(String htmlInput, String rule) {
  final (els, extractor) = _select(htmlInput, rule);
  return els.map((el) => _extract(el, extractor)).toList();
}

/// 同 [pdfh]，但把结果按 [baseUrl] 补成绝对地址。
///
/// drpy 源正是靠它把 `/vod/1.html` 拼成可请求的完整地址。
String pd(String htmlInput, String rule, String baseUrl) =>
    _resolve(pdfh(htmlInput, rule), baseUrl);

/// 同 [pdfa]，但把每一项都按 [baseUrl] 补成绝对地址。
List<String> pdfl(String htmlInput, String rule, String baseUrl) =>
    pdfa(htmlInput, rule).map((v) => _resolve(v, baseUrl)).toList();
