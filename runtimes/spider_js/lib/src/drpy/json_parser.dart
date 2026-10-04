/// drpy 宿主 API：JSONPath 解析（`jsonpath` / `pjfh` / `pj` / `pjfa`）。
///
/// 语义逐条对齐参考实现 `drpynode`：
///   - `libs_drpy/htmlParser.js` 的 `jsonpath.query(json, path)`
///     —— 实为 `JSONPath.JSONPath({path, json})`，**不带 `wrap`**，且
///     **总是返回数组**（`$.msg` 得到 `["ok"]`，不是 `"ok"`）
///   - `libs_drpy/htmlParser.js` 的 `Jsoup.pjfh / pj / pjfa`
///
/// 期望值不是推的：用 Node 加载参考实现的 `jsonpathplus.min.js`，逐字复刻
/// 这三个函数后实测产出，见 `test/json_parser_test.dart` 里各用例的注释。
/// 实测过程暴露出几条反直觉行为，均已照实现（不是照直觉）：
///
///   - `pjfh` 的 `queryResult[0] || ''` 会**吞掉假值**：`$.code` 命中数字 `0`
///     时返回的是空串 `''`，不是 `0`
///   - `pjfh` 的返回类型不是字符串：`$.data.total` 命中 `3` 返回数字 `3`，
///     命中数组就返回数组
///   - 负下标**不支持**：`$.data.list[-1]` 是空集，不是"最后一个"
///   - 越界下标同样返回空集
///   - `.length` 能取到字符串/数组的长度（JS 属性语义）
///
/// 支持的范围见 [jsonPathQuery] 的文档；超出范围的写法会**抛异常**而不是
/// 静默返回空集——静默给错结果比报错难查得多。
library;

import 'dart:convert';

import 'package:spider_js/src/drpy/crypto.dart' show joinUrl;

/// 用 [path] 查询 [root]，返回**所有**命中值。
///
/// 返回值恒为列表，与参考实现的 `jsonpath.query` 一致（它总是给数组）。
/// 空列表表示没有命中。
///
/// 支持的语法：
///
/// | 写法 | 含义 |
/// | --- | --- |
/// | `$` | 根 |
/// | `.name` / `['name']` / `["name"]` | 取成员 |
/// | `[0]` | 取下标（**不支持负下标**，与参考实现一致） |
/// | `[*]` / `.*` | 通配 |
/// | `..name` / `..*` | 递归下降 |
/// | `[0,2]` | 下标并集 |
/// | `[0:2]` | 切片（左闭右开） |
/// | `[?(@.k==1)]` | 过滤，支持 `==` `!=` `>` `>=` `<` `<=` `&&` `\|\|` `!` |
///
/// 超出范围的写法（如 `..[` 开头的递归过滤）抛 [FormatException]。
List<Object?> jsonPathQuery(Object? root, String path) {
  final steps = _parsePath(path);
  var current = <Object?>[root];
  for (final step in steps) {
    current = step(current);
  }
  return current;
}

/// drpy `pjfh(json, rule[, addUrl])` —— 解析 JSON 取单个值。
///
/// [json] 可以是 JSON 字符串或已解析的对象；字符串解析失败返回 `''`（参考
/// 实现就是 `log` 一句然后返回空串）。
///
/// 规则里可以用 `||` 串多条路径做**回退**，取第一个非假值：
/// `'$.missing||$.msg'` 会拿到 `msg`。
///
/// [addUrl] 为真时对命中的值做 URL 拼接（用 [baseUrl]）。参考实现里
/// `pj` 是 `new jsoup()`（**空 base**）再拼，实测对相对路径会给出
/// `/a.jpg` 这种没有 host 的伪绝对路径。兼容层照搬这个行为，不做「修正」——
/// 存量源里可能存在依赖该形态的字符串处理。
Object? pjfh(
  Object? json,
  String rule, {
  bool addUrl = false,
  String baseUrl = '',
}) {
  final root = _decodeJson(json);
  if (root == _absent || rule.isEmpty) return '';

  final normalized = rule.startsWith(r'$.') ? rule : r'$.' + rule;
  Object? ret = '';
  for (final path in normalized.split('||')) {
    final hits = jsonPathQuery(root, path);
    // 对应参考实现的 `queryResult[0] || ''`：空集与假值都落到空串。
    final first = hits.isEmpty ? null : hits.first;
    ret = _isJsFalsy(first) ? '' : first;
    // 对应 `if (addUrl && ret) ret = urljoin(MY_URL, ret)`：urljoin 内部会
    // 经 `new URL()` 把非字符串入参转成字符串，所以命中数字 `3` 时 `pj`
    // 返回的是**字符串** `'/3'`，而不是数字 `3`。
    if (addUrl && _isJsTruthy(ret)) {
      ret = joinUrl(baseUrl, _jsToString(ret));
    }
    if (_isJsTruthy(ret)) break;
  }
  return ret;
}

/// drpy `pj(json, rule)` —— 同 [pjfh]，但总是做 URL 拼接。
Object? pj(Object? json, String rule, {String baseUrl = ''}) =>
    pjfh(json, rule, addUrl: true, baseUrl: baseUrl);

/// drpy `pjfa(json, rule)` —— 解析 JSON 取**数组**。
///
/// 命中恰好一项且该项本身是数组时返回该项（`$.data.list` 得到的就是那个
/// 列表），否则返回命中集合。没有命中返回空列表。
List<Object?> pjfa(Object? json, String rule) {
  final root = _decodeJson(json);
  if (root == _absent || rule.isEmpty) return const <Object?>[];

  final normalized = rule.startsWith(r'$.') ? rule : r'$.' + rule;
  final hits = jsonPathQuery(root, normalized);
  if (hits.length == 1 && hits.first is List) {
    return (hits.first! as List).cast<Object?>();
  }
  return hits;
}

// ---------------------------------------------------------------------------
// 路径解析
// ---------------------------------------------------------------------------

/// 一步求值：把当前节点集推进到下一批节点。
typedef _Step = List<Object?> Function(List<Object?> input);

/// 成员不存在。用哨兵而不是 `null`，因为 JSON 里 `null` 是合法值。
const Object _absent = _Absent();

/// 哨兵类型。
final class _Absent {
  /// 常量构造。
  const _Absent();
}

/// 把路径串解析成求值步骤序列。
List<_Step> _parsePath(String path) {
  if (path.isEmpty || path[0] != r'$') {
    throw FormatException('JSONPath 必须以 \$ 开头，实际是「$path」');
  }
  final steps = <_Step>[];
  var i = 1;
  while (i < path.length) {
    final ch = path[i];
    if (ch == '.') {
      final recursive = i + 1 < path.length && path[i + 1] == '.';
      i += recursive ? 2 : 1;
      if (i >= path.length) {
        throw FormatException('JSONPath 在「$path」的末尾缺少成员名');
      }
      if (path[i] == '*') {
        steps.add(recursive ? _recursive(null) : _wildcard());
        i++;
        continue;
      }
      if (path[i] == '[') {
        throw FormatException(
          'JSONPath「$path」里的 `..[` 递归过滤尚未支持；请改用 `..成员名`，或先取到数组再过滤',
        );
      }
      final name = _readBareName(path, i);
      steps.add(recursive ? _recursive(name) : _child(name));
      i += name.length;
      continue;
    }
    if (ch == '[') {
      final end = _findBracketEnd(path, i);
      steps.add(_parseBracket(path.substring(i + 1, end), path));
      i = end + 1;
      continue;
    }
    throw FormatException('JSONPath「$path」第 $i 个字符「$ch」无法解析');
  }
  return steps;
}

/// 读取点号后的裸成员名（到 `.` / `[` 或串尾为止）。
String _readBareName(String path, int start) {
  var i = start;
  while (i < path.length && path[i] != '.' && path[i] != '[') {
    i++;
  }
  if (i == start) {
    throw FormatException('JSONPath「$path」在位置 $start 处缺少成员名');
  }
  return path.substring(start, i);
}

/// 找配对的 `]`，跳过引号内的内容与括号嵌套。
int _findBracketEnd(String path, int open) {
  var depth = 0;
  var i = open;
  String? quote;
  while (i < path.length) {
    final ch = path[i];
    if (quote != null) {
      if (ch == r'\') {
        i += 2;
        continue;
      }
      if (ch == quote) quote = null;
    } else if (ch == '"' || ch == "'") {
      quote = ch;
    } else if (ch == '[' || ch == '(') {
      depth++;
    } else if (ch == ']' || ch == ')') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  throw FormatException('JSONPath「$path」里的 `[` 没有配对的 `]`');
}

/// 解析 `[...]` 里的内容。
_Step _parseBracket(String inner, String path) {
  final body = inner.trim();
  if (body.isEmpty) throw FormatException('JSONPath「$path」里有空的 `[]`');

  if (body == '*') return _wildcard();

  if (body.startsWith('?')) {
    return _filter(_FilterParser(body.substring(1).trim(), path).parse());
  }

  if (body.startsWith('(')) {
    throw FormatException('JSONPath「$path」里的 `[(...)]` 语法无法识别');
  }

  // 引号成员名：['a'] / ["a"]
  final quoted = _tryUnquote(body);
  if (quoted != null) return _child(quoted);

  if (body.contains(':')) return _slice(body, path);
  if (body.contains(',')) return _union(body, path);

  final index = int.tryParse(body);
  if (index == null) {
    throw FormatException('JSONPath「$path」里的下标「$body」不是整数');
  }
  return _index(index);
}

/// 去掉整体包裹的引号；不是引号串返回 null。
String? _tryUnquote(String s) {
  if (s.length < 2) return null;
  final first = s[0];
  if (first != '"' && first != "'") return null;
  if (s[s.length - 1] != first) return null;
  return s.substring(1, s.length - 1).replaceAll(r'\' + first, first);
}

/// `[0:2]` 切片。左闭右开，缺省端点为整段。
_Step _slice(String body, String path) {
  final parts = body.split(':');
  if (parts.length > 3) {
    throw FormatException('JSONPath「$path」里的切片「[$body]」段数过多');
  }
  final start = parts[0].trim().isEmpty ? null : int.tryParse(parts[0].trim());
  final end = parts.length > 1 && parts[1].trim().isNotEmpty
      ? int.tryParse(parts[1].trim())
      : null;
  if (start == null && parts[0].trim().isNotEmpty) {
    throw FormatException('JSONPath「$path」切片的起点不是整数');
  }
  if (end == null && parts.length > 1 && parts[1].trim().isNotEmpty) {
    throw FormatException('JSONPath「$path」切片的终点不是整数');
  }
  return (input) {
    final out = <Object?>[];
    for (final node in input) {
      if (node is! List) continue;
      final from = (start ?? 0).clamp(0, node.length);
      final to = (end ?? node.length).clamp(from, node.length);
      out.addAll(node.sublist(from, to));
    }
    return out;
  };
}

/// `[0,2]` 下标并集。
_Step _union(String body, String path) {
  final indices = <int>[];
  for (final raw in body.split(',')) {
    final index = int.tryParse(raw.trim());
    if (index == null) {
      throw FormatException('JSONPath「$path」里的并集项「${raw.trim()}」不是整数');
    }
    indices.add(index);
  }
  return (input) {
    final out = <Object?>[];
    for (final node in input) {
      if (node is! List) continue;
      for (final index in indices) {
        if (index >= 0 && index < node.length) out.add(node[index]);
      }
    }
    return out;
  };
}

// ---------------------------------------------------------------------------
// 各步求值
// ---------------------------------------------------------------------------

/// 取成员。
_Step _child(String name) => (input) {
  final out = <Object?>[];
  for (final node in input) {
    final value = _readMember(node, name);
    if (value != _absent) out.add(value);
  }
  return out;
};

/// 取当前节点的全部子值。
_Step _wildcard() => (input) {
  final out = <Object?>[];
  for (final node in input) {
    out.addAll(_childValues(node));
  }
  return out;
};

/// 递归下降。[name] 为 null 表示 `..*`（收全部后代）。
///
/// 顺序与参考实现一致：**先输出一个节点的全部子值，再逐个下钻**。这个顺序
/// 是实测出来的——既不是纯 BFS 也不是纯 DFS，见 `$..*` 的用例。
_Step _recursive(String? name) => (input) {
  final out = <Object?>[];
  for (final node in input) {
    _descend(node, name, out);
  }
  return out;
};

/// 递归下降的递归体。
void _descend(Object? node, String? name, List<Object?> out) {
  final children = _childEntries(node);
  for (final entry in children) {
    if (name == null || entry.key == name) out.add(entry.value);
  }
  for (final entry in children) {
    _descend(entry.value, name, out);
  }
}

/// 取下标。负下标与越界都**不命中**（与参考实现一致）。
_Step _index(int index) => (input) {
  final out = <Object?>[];
  for (final node in input) {
    if (node is List && index >= 0 && index < node.length) {
      out.add(node[index]);
    }
  }
  return out;
};

/// 过滤。
_Step _filter(_FilterNode expr) => (input) {
  final out = <Object?>[];
  for (final node in input) {
    for (final value in _childValues(node)) {
      if (expr.eval(value)) out.add(value);
    }
  }
  return out;
};

/// 读一个成员。`length` 在字符串/数组上按 JS 属性语义返回长度。
Object? _readMember(Object? node, String name) {
  if (node is Map) {
    return node.containsKey(name) ? node[name] : _absent;
  }
  if (name == 'length') {
    if (node is String) return node.length;
    if (node is List) return node.length;
  }
  return _absent;
}

/// 取一个节点的子值：对象取值、数组取元素。
List<Object?> _childValues(Object? node) =>
    _childEntries(node).map((e) => e.value).toList();

/// 取一个节点的 (键, 值) 对。对象给成员名，数组给下标字符串。
List<MapEntry<String, Object?>> _childEntries(Object? node) {
  if (node is Map) {
    return node.entries
        .map((e) => MapEntry<String, Object?>(e.key.toString(), e.value))
        .toList();
  }
  if (node is List) {
    return <MapEntry<String, Object?>>[
      for (var i = 0; i < node.length; i++)
        MapEntry<String, Object?>(i.toString(), node[i]),
    ];
  }
  return const <MapEntry<String, Object?>>[];
}

// ---------------------------------------------------------------------------
// 过滤表达式
// ---------------------------------------------------------------------------

/// 过滤表达式的节点。
sealed class _FilterNode {
  /// 供子类写 `const` 构造用。
  const _FilterNode();

  /// 在当前节点上求值。
  bool eval(Object? node);
}

/// `a || b`
final class _OrNode extends _FilterNode {
  /// 构造。
  const _OrNode(this.left, this.right);

  /// 左。
  final _FilterNode left;

  /// 右。
  final _FilterNode right;

  @override
  bool eval(Object? node) => left.eval(node) || right.eval(node);
}

/// `a && b`
final class _AndNode extends _FilterNode {
  /// 构造。
  const _AndNode(this.left, this.right);

  /// 左。
  final _FilterNode left;

  /// 右。
  final _FilterNode right;

  @override
  bool eval(Object? node) => left.eval(node) && right.eval(node);
}

/// `!a`
final class _NotNode extends _FilterNode {
  /// 构造。
  const _NotNode(this.inner);

  /// 被取反的表达式。
  final _FilterNode inner;

  @override
  bool eval(Object? node) => !inner.eval(node);
}

/// 裸操作数，按 JS 真值语义判真假。
final class _TruthyNode extends _FilterNode {
  /// 构造。
  const _TruthyNode(this.operand);

  /// 操作数。
  final _Operand operand;

  @override
  bool eval(Object? node) => _isJsTruthy(operand.resolve(node));
}

/// 比较。
final class _CompareNode extends _FilterNode {
  /// 构造。
  const _CompareNode(this.left, this.op, this.right);

  /// 左操作数。
  final _Operand left;

  /// 比较符。
  final String op;

  /// 右操作数。
  final _Operand right;

  @override
  bool eval(Object? node) {
    final a = left.resolve(node);
    final b = right.resolve(node);
    switch (op) {
      case '==':
        return _looseEquals(a, b);
      case '!=':
        return !_looseEquals(a, b);
    }
    final na = _toNumber(a);
    final nb = _toNumber(b);
    if (na == null || nb == null) return false;
    switch (op) {
      case '>':
        return na > nb;
      case '>=':
        return na >= nb;
      case '<':
        return na < nb;
      case '<=':
        return na <= nb;
    }
    return false;
  }
}

/// 过滤表达式里的一个操作数：`@.a.b` / `$.x.y` / 字面量。
final class _Operand {
  /// 成员路径操作数。[fromRoot] 为真时从根（`$`）起算，否则从当前节点起算。
  const _Operand({required this.fromRoot, required this.names})
    : literal = _absent;

  /// 字面量操作数。
  const _Operand.literal(this.literal)
    : fromRoot = false,
      names = const <String>[];

  /// 从根（`$`）起算；否则从当前节点（`@`）起算。
  final bool fromRoot;

  /// 成员路径。
  final List<String> names;

  /// 字面量值；不是字面量时为 [_absent]。
  final Object? literal;

  /// 在 [node] 上求值。
  Object? resolve(Object? node) {
    if (literal != _absent) return literal;
    var current = node;
    for (final name in names) {
      current = _readMember(current, name);
      if (current == _absent) return null;
    }
    return current;
  }
}

/// 过滤表达式解析器。
class _FilterParser {
  /// 构造。
  _FilterParser(this.source, this.path);

  /// 待解析文本。
  final String source;

  /// 原始路径，仅用于报错。
  final String path;

  int _pos = 0;

  /// 解析入口。
  _FilterNode parse() {
    _skipSpaces();
    if (_peek() == '(' && _isWrappedWhole()) _pos++;
    final node = _parseOr();
    _skipSpaces();
    if (_pos < source.length && _peek() == ')' && _isWrappedWhole()) _pos++;
    _skipSpaces();
    if (_pos < source.length) {
      throw FormatException(
        'JSONPath「$path」过滤表达式在「${source.substring(_pos)}」处无法解析',
      );
    }
    return node;
  }

  /// 整个表达式是否被一对括号包裹。
  bool _isWrappedWhole() {
    var depth = 0;
    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0 && i < source.length - 1) return false;
      }
    }
    return depth == 0 && source.startsWith('(') && source.endsWith(')');
  }

  _FilterNode _parseOr() {
    var left = _parseAnd();
    while (true) {
      _skipSpaces();
      if (_startsWith('||')) {
        _pos += 2;
        left = _OrNode(left, _parseAnd());
      } else {
        return left;
      }
    }
  }

  _FilterNode _parseAnd() {
    var left = _parseUnary();
    while (true) {
      _skipSpaces();
      if (_startsWith('&&')) {
        _pos += 2;
        left = _AndNode(left, _parseUnary());
      } else {
        return left;
      }
    }
  }

  _FilterNode _parseUnary() {
    _skipSpaces();
    if (_peek() == '!') {
      _pos++;
      return _NotNode(_parseUnary());
    }
    if (_peek() == '(') {
      _pos++;
      final inner = _parseOr();
      _skipSpaces();
      if (_peek() != ')') {
        throw FormatException('JSONPath「$path」过滤表达式缺少 `)`');
      }
      _pos++;
      return inner;
    }
    final left = _parseOperand();
    _skipSpaces();
    final op = _tryReadOperator();
    if (op == null) return _TruthyNode(left);
    _skipSpaces();
    return _CompareNode(left, op, _parseOperand());
  }

  /// 尝试读比较符；读不到返回 null。
  String? _tryReadOperator() {
    for (final op in const <String>['==', '!=', '>=', '<=', '>', '<', '=']) {
      if (_startsWith(op)) {
        _pos += op.length;
        return op == '=' ? '==' : op;
      }
    }
    return null;
  }

  _Operand _parseOperand() {
    _skipSpaces();
    final ch = _peek();
    if (ch == '@' || ch == r'$') {
      _pos++;
      final names = <String>[];
      while (_pos < source.length) {
        if (_peek() == '.') {
          _pos++;
          names.add(_readName());
        } else if (_peek() == '[') {
          _pos++;
          final end = _findBracketEnd(source, _pos - 1);
          final name = _tryUnquote(source.substring(_pos, end).trim());
          if (name == null) {
            throw FormatException('JSONPath「$path」过滤表达式的 `[]` 里只支持引号成员名');
          }
          names.add(name);
          _pos = end + 1;
        } else {
          break;
        }
      }
      return _Operand(fromRoot: ch == r'$', names: names);
    }
    return _Operand.literal(_parseLiteral());
  }

  String _readName() {
    final start = _pos;
    while (_pos < source.length && !'. [,]()!<>=&|'.contains(source[_pos])) {
      _pos++;
    }
    if (_pos == start) {
      throw FormatException('JSONPath「$path」过滤表达式缺少成员名');
    }
    return source.substring(start, _pos);
  }

  Object? _parseLiteral() {
    final ch = _peek();
    if (ch == '"' || ch == "'") {
      _pos++;
      final buffer = StringBuffer();
      while (_pos < source.length && source[_pos] != ch) {
        if (source[_pos] == r'\') _pos++;
        buffer.write(source[_pos]);
        _pos++;
      }
      if (_pos >= source.length) {
        throw FormatException('JSONPath「$path」过滤表达式的字符串没有闭合');
      }
      _pos++;
      return buffer.toString();
    }
    final start = _pos;
    while (_pos < source.length && !' ,)]&|'.contains(source[_pos])) {
      _pos++;
    }
    final token = source.substring(start, _pos);
    if (token == 'true') return true;
    if (token == 'false') return false;
    if (token == 'null') return null;
    final number = num.tryParse(token);
    if (number != null) return number;
    throw FormatException('JSONPath「$path」过滤表达式里的字面量「$token」无法识别');
  }

  String? _peek() => _pos < source.length ? source[_pos] : null;

  bool _startsWith(String s) => source.startsWith(s, _pos);

  void _skipSpaces() {
    while (_pos < source.length && source[_pos] == ' ') {
      _pos++;
    }
  }
}

// ---------------------------------------------------------------------------
// JS 语义小工具
// ---------------------------------------------------------------------------

/// JS 假值：`false` / `0` / `''` / `null` / `undefined` / `NaN`。
bool _isJsFalsy(Object? value) {
  if (value == null) return true;
  if (value is bool) return !value;
  if (value is num) return value == 0 || value.isNaN;
  if (value is String) return value.isEmpty;
  return false;
}

/// JS 真值。注意空数组与空对象在 JS 里是**真**。
bool _isJsTruthy(Object? value) => !_isJsFalsy(value);

/// JS 宽松相等（`==`）。
bool _looseEquals(Object? a, Object? b) {
  if (a == null || b == null) return a == null && b == null;
  if (a is num && b is num) return a == b;
  if (a is bool || b is bool) return _isJsTruthy(a) == _isJsTruthy(b);
  if (a is String && b is String) return a == b;
  final na = _toNumber(a);
  final nb = _toNumber(b);
  if (na != null && nb != null) return na == nb;
  return a.toString() == b.toString();
}

/// 尽量转成数字；转不了返回 null。
num? _toNumber(Object? value) {
  if (value is num) return value;
  if (value is bool) return value ? 1 : 0;
  if (value is String) return num.tryParse(value.trim());
  return null;
}

/// JS `String(value)` 的口径。
///
/// 只在 `pjfh` 的 addUrl 分支用得到——参考实现里 `urljoin` 会把非字符串
/// 入参经 `new URL()` 强制转成字符串。
String _jsToString(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value;
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return _jsNumberToString(value);
  if (value is List) return value.map(_jsToString).join(',');
  if (value is Map) return '[object Object]';
  return value.toString();
}

/// JS 数字转字符串：`3.0` 在 JS 里是 `'3'`，Dart 默认给 `'3.0'`。
String _jsNumberToString(num value) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value.isNegative ? '-Infinity' : 'Infinity';
  // JS 在 1e21 以上改用指数写法，这里只处理常规区间。
  if (value.abs() < 1e21 && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

/// JSON 字符串或已解析对象 → 对象；解析失败给 [_absent]。
Object? _decodeJson(Object? json) {
  if (json is! String) return json ?? _absent;
  try {
    return jsonDecode(json);
  } on FormatException {
    return _absent;
  }
}
