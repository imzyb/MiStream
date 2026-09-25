/// TVBox 配置的宽松 JSON 解析器与字段映射。
///
/// docs/05-Spider引擎.md §5.1-5.2。
library;

import 'dart:convert';

import 'package:core_config/src/config_models.dart';

/// 宽松 JSON 解析器。
///
/// 容忍：注释（// 行注释）、尾逗号、单引号。
class LooseJsonParser {
  /// 解析 [text] 为 JSON 对象。
  ///
  /// 先尝试标准 `jsonDecode`，失败后用宽松解析器重试。
  static Map<String, Object?>? parse(String text) {
    // 尝试标准解析
    try {
      final result = jsonDecode(text);
      if (result is Map<String, Object?>) return result;
      return null;
    } on FormatException {
      // 宽松解析
    }

    // 去注释
    var cleaned = _stripComments(text);
    // 尾逗号
    cleaned = _stripTrailingCommas(cleaned);
    // 单引号转双引号
    cleaned = _replaceSingleQuotes(cleaned);

    try {
      final result = jsonDecode(cleaned);
      if (result is Map<String, Object?>) return result;
    } on FormatException {
      return null;
    }
    return null;
  }

  static String _stripComments(String text) {
    final lines = text.split('\n');
    return lines
        .map((line) {
          final idx = line.indexOf('//');
          return idx >= 0 ? line.substring(0, idx) : line;
        })
        .join('\n');
  }

  static String _stripTrailingCommas(String text) {
    return text.replaceAllMapped(
      RegExp(r',\s*([}\]])'),
      (m) => m.group(1) ?? '',
    );
  }

  static String _replaceSingleQuotes(String text) {
    final buffer = StringBuffer();
    var inString = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '"' && (i == 0 || text[i - 1] != r'\')) {
        inString = !inString;
        buffer.write(ch);
      } else if (ch == "'" && !inString) {
        buffer.write('"');
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }
}

/// TVBox `spider` 字段里 URL 与 md5 的分隔符。
///
/// 生态的写法是**把 md5 拼在 URL 后面**（`<url>;md5;<hash>`），而不是另起一个
/// 键。实测 `qist/tvbox` 的 `xiaosa/api.json`：
///
/// ```jsonc
/// "spider": "./spider.jar;md5;af187c2a2be1bcbb5e183d77e740b21b"
/// ```
///
/// 只读 `spider_md5` 会让 md5 永远是 `null`，jar 校验形同虚设——
/// 2026-09-25 用真实源跑通链路时才发现（导入成功但 `spiderMd5: null`）。
const String kSpiderMd5Separator = ';md5;';

/// 拆开 `spider` 字段，得到 jar URL 与 md5。
///
/// [explicitMd5] 是配置里另写的 `spider_md5`（非标准写法，作为兜底）。
/// 内联的 `;md5;` 优先于它。
({String? url, String? md5}) parseSpiderField(
  String? raw, {
  String? explicitMd5,
}) {
  final fallbackMd5 = _trimToNull(explicitMd5);
  final value = _trimToNull(raw);
  if (value == null) return (url: null, md5: fallbackMd5);

  final at = value.indexOf(kSpiderMd5Separator);
  if (at < 0) return (url: value, md5: fallbackMd5);

  final url = _trimToNull(value.substring(0, at));
  final md5 = _trimToNull(value.substring(at + kSpiderMd5Separator.length));
  return (url: url, md5: md5 ?? fallbackMd5);
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// TVBox 配置解析器。
class ConfigParser {
  /// 从 JSON 文本解析为 [TvBoxConfig]。
  static TvBoxConfig? parse(String jsonText) {
    final raw = LooseJsonParser.parse(jsonText);
    if (raw == null) return null;

    final spider = parseSpiderField(
      raw['spider'] as String?,
      explicitMd5: raw['spider_md5'] as String?,
    );

    return TvBoxConfig(
      spider: spider.url,
      spiderMd5: spider.md5,
      sites: _parseSites(raw['sites']),
      lives: _parseLives(raw['lives']),
      parses: _parseParses(raw['parses']),
      rules: _parseRules(raw['rules']),
      flags: (raw['flags'] as List<Object?>?)?.cast<String>() ?? [],
      wallpaper: raw['wallpaper'] as String?,
      doh: (raw['doh'] as List<Object?>?)?.cast<String>() ?? [],
    );
  }

  static List<SiteConfig> _parseSites(Object? raw) {
    if (raw is! List<Object?>) return [];
    return raw.map((item) {
      final map = item is Map<String, Object?> ? item : <String, Object?>{};
      return SiteConfig(
        key: (map['key'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        type: _toIntOrZero(map['type']),
        api: (map['api'] as String?) ?? '',
        ext: _toStringOrJson(map['ext']),
        searchable: _toBool(map['searchable'], defaultValue: true),
        quickSearch: _toBool(map['quickSearch']),
        filterable: _toBool(map['filterable']),
        priority: _toIntOrZero(map['priority']),
      );
    }).toList();
  }

  static List<LiveConfig> _parseLives(Object? raw) {
    if (raw is! List<Object?>) return [];
    return raw.map((item) {
      final map = item is Map<String, Object?> ? item : <String, Object?>{};
      return LiveConfig(
        name: map['name'] as String?,
        url: map['url'] as String?,
        type: '${map['type'] ?? ''}',
      );
    }).toList();
  }

  static List<ParseConfig> _parseParses(Object? raw) {
    if (raw is! List<Object?>) return [];
    return raw.map((item) {
      final map = item is Map<String, Object?> ? item : <String, Object?>{};
      return ParseConfig(
        name: (map['name'] as String?) ?? '',
        type: _toIntOrZero(map['type']),
        url: (map['url'] as String?) ?? '',
        ext: _toStringOrJson(map['ext']),
        flags: (map['flags'] as List<Object?>?)?.cast<String>() ?? [],
      );
    }).toList();
  }

  static List<SniffRuleConfig> _parseRules(Object? raw) {
    if (raw is! List<Object?>) return [];
    return raw.map((item) {
      final map = item is Map<String, Object?> ? item : <String, Object?>{};
      return SniffRuleConfig(
        host: (map['host'] as String?) ?? '',
        regex: _toStringOrJson(map['regex']),
      );
    }).toList();
  }

  /// 将值转为 String：如果是 Map 则序列化为 JSON 字符串。
  static String? _toStringOrJson(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      try {
        return jsonEncode(value);
      } on Object {
        return value.toString();
      }
    }
    return value.toString();
  }

  /// 将值转为 int：支持 num 和 String 类型。
  static int _toIntOrZero(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// 将 TVBox 中常见的数字、字符串或布尔开关转为 bool。
  static bool _toBool(Object? value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case '1':
        case 'true':
        case 'yes':
        case 'on':
          return true;
        case '0':
        case 'false':
        case 'no':
        case 'off':
          return false;
      }
    }
    return defaultValue;
  }
}
