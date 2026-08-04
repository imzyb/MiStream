/// 日志脱敏。
///
/// `docs/10-开发规范.md` §10 把它列为硬要求，因为泄漏路径太顺手了：源返回的
/// 播放地址常常带 `?token=`，而排错时第一反应就是把整条 URL 打进日志，再连同
/// 「复制诊断信息」贴进 issue。
library;

import 'package:meta/meta.dart';

/// 把敏感信息从日志内容里抹掉。
///
/// 三个入口分别对应三种形态：结构化字段（[redactMap]）、URL（[redactUrl]）、
/// 自由文本（[redactText]）。全部幂等——重复脱敏不会把 `***` 越打越多。
///
/// **没有「关闭」模式**，这是刻意的：`LogRecord.toJson` 强制要求传入一个
/// [Redactor]，于是「忘了脱敏」在类型层面就写不出来。
@immutable
final class Redactor {
  /// 构造一个脱敏器。
  ///
  /// 自定义词表请传入**归一化后**的键（小写、去掉 `-` `_` 与空格），
  /// 见 [normalizeKey]。
  const Redactor({
    Set<String> urlSensitiveKeys = defaultUrlSensitiveKeys,
    Set<String> fieldSensitiveKeys = defaultFieldSensitiveKeys,
    this.mask = '***',
  }) : _urlKeys = urlSensitiveKeys,
       _fieldKeys = fieldSensitiveKeys;

  /// URL query 与自由文本里的敏感键。
  ///
  /// 比 [defaultFieldSensitiveKeys] 多一个裸 `key`：出现在 query string 里的
  /// `key=` 几乎一定是 API key。
  static const defaultUrlSensitiveKeys = <String>{
    'accesskey',
    'accesstoken',
    'apikey',
    'appkey',
    'auth',
    'authorization',
    'authtoken',
    'clientsecret',
    'cookie',
    'credential',
    'credentials',
    'idtoken',
    'key',
    'pass',
    'passwd',
    'password',
    'privatekey',
    'pwd',
    'refreshtoken',
    'secret',
    'secretkey',
    'session',
    'sessionid',
    'setcookie',
    'sid',
    'sig',
    'sign',
    'signature',
    'ticket',
    'token',
    'xapikey',
  };

  /// 结构化字段（`detail` map）里的敏感键。
  ///
  /// **不含**裸 `key`：TVBox 配置里的 `key` 是站点标识（`{"key":"csp_XXX"}`），
  /// 打掉它诊断信息就没法看了。真正的密钥字段都带前缀，已在表里。
  static const defaultFieldSensitiveKeys = <String>{
    'accesskey',
    'accesstoken',
    'apikey',
    'appkey',
    'auth',
    'authorization',
    'authtoken',
    'clientsecret',
    'cookie',
    'credential',
    'credentials',
    'idtoken',
    'pass',
    'passwd',
    'password',
    'privatekey',
    'proxyauthorization',
    'pwd',
    'refreshtoken',
    'secret',
    'secretkey',
    'session',
    'sessionid',
    'setcookie',
    'sid',
    'sig',
    'sign',
    'signature',
    'ticket',
    'token',
    'xapikey',
  };

  /// 打码后填入的占位符。
  final String mask;

  final Set<String> _urlKeys;
  final Set<String> _fieldKeys;

  /// 归一化一个键名：转小写，去掉 `-`、`_` 与空格。
  ///
  /// 于是 `API_KEY`、`api-key`、`apiKey` 都归到 `apikey`，词表只需维护一份。
  static String normalizeKey(String key) {
    final buffer = StringBuffer();
    for (final unit in key.toLowerCase().codeUnits) {
      // '-' | '_' | ' '
      if (unit == 0x2D || unit == 0x5F || unit == 0x20) continue;
      buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  // 形如 scheme://rest，rest 一直吃到空白或引号为止。
  static final RegExp _urlPattern = RegExp(
    r'''[a-zA-Z][a-zA-Z0-9+.\-]*://[^\s"'<>\\]+''',
  );

  // 自由文本里的 key=value / key:value。值不跨越 & ; , 与引号。
  static final RegExp _keyValuePattern = RegExp(
    r'''([A-Za-z_][A-Za-z0-9_\-]*)(\s*[=:]\s*)([^\s&;,"']+)''',
  );

  // 头部风格：值可以带空格，一直吃到行尾（或 & 与引号），整段打掉。
  static final RegExp _headerPattern = RegExp(
    '''((?:proxy-)?authorization|set-cookie|cookie|x-api-key)'''
    r'''(\s*[:=]\s*)([^\r\n&"]+)''',
    caseSensitive: false,
  );

  /// 该键是否属于 URL / 文本敏感词。
  bool isUrlSensitive(String key) => _urlKeys.contains(normalizeKey(key));

  /// 该键是否属于结构化字段敏感词。
  bool isFieldSensitive(String key) => _fieldKeys.contains(normalizeKey(key));

  /// 脱敏一条 URL：打掉敏感 query 参数、userInfo 与 fragment 里的键值对。
  ///
  /// 不含敏感参数的 URL 原样返回（不重新编码），日志里的地址才能直接复制去用。
  String redactUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return _redactKeyValues(url);

    var result = uri;

    if (uri.userInfo.isNotEmpty) {
      result = result.replace(userInfo: mask);
    }

    // 先让 Uri 自己解码一遍参数表：解得出来，就说明下面逐段解 key 也不会抛。
    if (uri.hasQuery && uri.queryParametersAll.keys.any(isUrlSensitive)) {
      result = result.replace(query: _redactQuery(uri.query));
    }

    // OAuth 隐式流会把 access_token 放在 fragment 里。
    if (uri.hasFragment && uri.fragment.isNotEmpty) {
      final redacted = _redactKeyValues(uri.fragment);
      if (redacted != uri.fragment) {
        result = result.replace(fragment: redacted);
      }
    }

    return result.toString();
  }

  /// 只把敏感参数的值换成 [mask]，其余片段逐字保留。
  ///
  /// 不走 `Uri.replace(queryParameters:)`：那条路会拿 [Uri.encodeQueryComponent]
  /// 重编码整个 query，掩码里的 `*` 会变成 `%2A`，没命中的参数也会被顺手改写
  /// 一遍——日志里的地址就不能直接复制去用了，而这正是上面那句注释的承诺。
  ///
  /// 同一个敏感参数重复出现时只留第一条：留几条 `***` 都不增加信息量。判重
  /// 按字面键名，`API-KEY` 与 `apiKey` 算两个参数——它们在 query 里本就是两个。
  String _redactQuery(String query) {
    final kept = <String>[];
    final masked = <String>{};

    for (final part in query.split('&')) {
      final separator = part.indexOf('=');
      if (separator < 0) {
        kept.add(part);
        continue;
      }

      final rawKey = part.substring(0, separator);
      final key = Uri.decodeQueryComponent(rawKey);
      if (!isUrlSensitive(key)) {
        kept.add(part);
      } else if (masked.add(key)) {
        kept.add('$rawKey=$mask');
      }
    }

    return kept.join('&');
  }

  /// 脱敏一段自由文本：先处理头部，再处理其中的 URL，最后兜底扫键值对。
  String redactText(String text) {
    if (text.isEmpty) return text;

    var result = text.replaceAllMapped(
      _headerPattern,
      (match) => '${match[1]}${match[2]}$mask',
    );
    result = result.replaceAllMapped(
      _urlPattern,
      (match) => redactUrl(match[0]!),
    );
    return _redactKeyValues(result);
  }

  /// 递归脱敏任意值。
  ///
  /// 不认识的类型原样返回——序列化时由 sink 的 `toEncodable` 兜底，不在这里
  /// 悄悄 `toString()` 丢失结构。
  Object? redactValue(Object? value) => switch (value) {
    final String text => redactText(text),
    final Uri uri => redactUrl(uri.toString()),
    final Map<String, Object?> map => redactMap(map),
    final Map<Object?, Object?> map => redactMap(
      map.map((key, value) => MapEntry('$key', value)),
    ),
    final Iterable<Object?> items => items.map(redactValue).toList(),
    _ => value,
  };

  /// 脱敏一个结构化 map：敏感键整值打掉，其余递归处理。
  Map<String, Object?> redactMap(Map<String, Object?> map) => {
    for (final entry in map.entries)
      entry.key: isFieldSensitive(entry.key) ? mask : redactValue(entry.value),
  };

  String _redactKeyValues(String text) => text.replaceAllMapped(
    _keyValuePattern,
    (match) =>
        isUrlSensitive(match[1]!) ? '${match[1]}${match[2]}$mask' : match[0]!,
  );
}
