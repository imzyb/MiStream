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

/// TVBox 配置解析器。
class ConfigParser {
  /// 从 JSON 文本解析为 [TvBoxConfig]。
  static TvBoxConfig? parse(String jsonText) {
    final raw = LooseJsonParser.parse(jsonText);
    if (raw == null) return null;

    return TvBoxConfig(
      spider: raw['spider'] as String?,
      spiderMd5: raw['spider_md5'] as String?,
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
        type: (map['type'] as num?)?.toInt() ?? 0,
        api: (map['api'] as String?) ?? '',
        ext: map['ext'] as String?,
        searchable: (map['searchable'] as num?)?.toInt() == 1,
        quickSearch: (map['quickSearch'] as num?)?.toInt() == 1,
        filterable: (map['filterable'] as num?)?.toInt() == 1,
        priority: (map['priority'] as num?)?.toInt() ?? 0,
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
        type: map['type'] as String?,
      );
    }).toList();
  }

  static List<ParseConfig> _parseParses(Object? raw) {
    if (raw is! List<Object?>) return [];
    return raw.map((item) {
      final map = item is Map<String, Object?> ? item : <String, Object?>{};
      return ParseConfig(
        name: (map['name'] as String?) ?? '',
        type: (map['type'] as num?)?.toInt() ?? 0,
        url: (map['url'] as String?) ?? '',
        ext: map['ext'] as String?,
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
        regex: map['regex'] as String?,
      );
    }).toList();
  }
}
