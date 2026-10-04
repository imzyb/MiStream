/// 电子节目单（EPG）模型与 XMLTV 解析。
///
/// 两种数据源要分清楚，**它们格式完全不同**：
///
/// * **XMLTV** —— 一份 XML 覆盖全部频道，靠 `programme@channel` 属性分流。
///   解析在 [XmltvParser]，模型装配在 [LiveEpg.fromXmltv]。
/// * **112114 / 51zmt 的 JSON 接口** —— 一个频道一次请求，日期在顶层字段、
///   时间是当天 `HH:mm`。解析在 `epg_fetcher.dart` 的 `EpgJsonParser`。
///
/// 本文件刻意**不 import 任何东西**（连 `dart:convert` 都不用），因为
/// `epg_fetcher.dart` 要 import 它 —— 反过来引会成环。
class LiveEpg {
  /// 直接构造。
  const LiveEpg({
    required this.channelId,
    required this.channelName,
    required this.programs,
  });

  /// 从 XMLTV 文本里挑出属于本频道的节目。
  ///
  /// [channelId] 先按 XMLTV 的 `programme@channel` 原值匹配；匹配不上再拿
  /// [channelName] 去比 `<channel><display-name>`；仍匹配不上且整份 XMLTV
  /// **只含一个频道**时，认为没有歧义直接采用。
  ///
  /// 三档兜底是必要的：配置里的 `channelId` 是本项目自己生成的
  /// （`url.hashCode`），几乎不可能等于源站的 XMLTV 频道 id。
  factory LiveEpg.fromXmltv(String channelId, String channelName, String xml) {
    const parser = XmltvParser();
    final programs = _selectProgrammes(
      parser.parse(xml),
      displayNames: parser.parseDisplayNames(xml),
      channelId: channelId,
      channelName: channelName,
    );
    return LiveEpg(
      channelId: channelId,
      channelName: channelName,
      programs: programs,
    );
  }

  /// 频道ID。
  final String channelId;

  /// 频道名称。
  final String channelName;

  /// 节目列表。
  final List<EpgProgram> programs;

  /// 获取当前节目。
  EpgProgram? get currentProgram {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final program in programs) {
      if (program.startTime <= now && program.endTime > now) {
        return program;
      }
    }
    return null;
  }

  /// 获取下一个节目。
  EpgProgram? get nextProgram {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final program in programs) {
      if (program.startTime > now) {
        return program;
      }
    }
    return null;
  }

  @override
  String toString() => 'LiveEpg($channelName, ${programs.length} programs)';
}

/// 按频道挑节目。见 [LiveEpg.fromXmltv] 的三档兜底说明。
List<EpgProgram> _selectProgrammes(
  Map<String, List<EpgProgram>> grouped, {
  required Map<String, String> displayNames,
  required String channelId,
  required String channelName,
}) {
  if (grouped.isEmpty) return const [];

  final direct = grouped[channelId];
  if (direct != null) return direct;

  final wanted = channelName.trim().toLowerCase();
  if (wanted.isNotEmpty) {
    for (final entry in displayNames.entries) {
      if (entry.value.trim().toLowerCase() == wanted) {
        final programs = grouped[entry.key];
        if (programs != null) return programs;
      }
    }
  }

  if (grouped.length == 1) return grouped.values.first;
  return const [];
}

/// EPG节目。
class EpgProgram {
  /// 构造。
  const EpgProgram({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
  });

  /// 节目标题。
  final String title;

  /// 节目描述。
  final String? description;

  /// 开始时间（Unix时间戳，秒）。
  final int startTime;

  /// 结束时间（Unix时间戳，秒）。
  final int endTime;

  /// 节目时长（秒）。
  int get duration => endTime - startTime;

  /// 节目时长（分钟）。
  int get durationMinutes => duration ~/ 60;

  /// 是否正在播出。
  bool get isAiring {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return startTime <= now && endTime > now;
  }

  /// 进度百分比（0-100）。
  int get progress {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (!isAiring) return 0;
    final elapsed = now - startTime;
    return ((elapsed / duration) * 100).clamp(0, 100).toInt();
  }

  @override
  String toString() =>
      'EpgProgram(title: $title, start: $startTime, end: $endTime)';
}

/// XMLTV 解析器。
///
/// XMLTV 是**一份文件覆盖全部频道**的格式：
///
/// ```xml
/// <tv>
///   <channel id="cctv1"><display-name>CCTV-1</display-name></channel>
///   <programme channel="cctv1" start="20260101120000 +0800"
///              stop="20260101130000 +0800">
///     <title lang="zh">新闻30分</title>
///     <desc>午间新闻</desc>
///   </programme>
/// </tv>
/// ```
///
/// 两个必须做对的地方：
///
/// 1. **按 `programme@channel` 分组**。旧实现把所有 `programme` 不分频道地
///    堆进同一个列表，结果是「每个频道都显示全部频道的节目单」。
/// 2. **时间戳要处理时区后缀**。`20260101120000 +0800` 是「东八区 12:00」，
///    直接当本地时间解析会在非东八区机器上整体偏移。
///
/// 用正则而不是 `xml` 包：XMLTV 结构扁平、无嵌套、无命名空间，正则足够；
/// 少一个依赖，也避免解析失败时把整个导入拖挂。
class XmltvParser {
  /// 构造。
  const XmltvParser();

  static final RegExp _programme = RegExp(
    r'<programme\b([^>]*)>(.*?)</programme>',
    dotAll: true,
  );
  static final RegExp _channelTag = RegExp(
    r'<channel\b([^>]*)>(.*?)</channel>',
    dotAll: true,
  );
  static final RegExp _displayName = RegExp(
    r'<display-name\b[^>]*>(.*?)</display-name>',
    dotAll: true,
  );
  static final RegExp _attribute = RegExp(r'([\w:.-]+)\s*=\s*"([^"]*)"');
  static final RegExp _title = RegExp(
    r'<title\b[^>]*>(.*?)</title>',
    dotAll: true,
  );
  static final RegExp _desc = RegExp(
    r'<desc\b[^>]*>(.*?)</desc>',
    dotAll: true,
  );

  /// 解析整份 XMLTV，按 `programme@channel` 分组，组内按开始时间升序。
  ///
  /// 丢弃而不是猜测的三种情况：缺 `channel` 属性、`start`/`stop` 解析不出
  /// 时间、`<title>` 为空。宁可少一条节目，也不要一条时间错乱的节目。
  Map<String, List<EpgProgram>> parse(String xmltv) {
    final grouped = <String, List<EpgProgram>>{};
    for (final match in _programme.allMatches(xmltv)) {
      final attributes = _attributes(match.group(1) ?? '');
      final channel = attributes['channel']?.trim() ?? '';
      if (channel.isEmpty) continue;

      final start = parseXmltvTime(attributes['start'] ?? '');
      if (start == null) continue;
      final stop = parseXmltvTime(attributes['stop'] ?? '');
      if (stop == null) continue;

      final body = match.group(2) ?? '';
      final title = decodeXmlEntities(_firstGroup(_title, body) ?? '').trim();
      if (title.isEmpty) continue;
      final description = decodeXmlEntities(
        _firstGroup(_desc, body) ?? '',
      ).trim();

      (grouped[channel] ??= <EpgProgram>[]).add(
        EpgProgram(
          title: title,
          description: description.isEmpty ? null : description,
          startTime: start,
          endTime: stop,
        ),
      );
    }
    for (final programs in grouped.values) {
      programs.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return grouped;
  }

  /// 解析 `<channel id="...">` 的首个 `<display-name>`，得到 id → 频道名。
  ///
  /// 用于把配置里的频道名对到 XMLTV 的频道 id（见 [LiveEpg.fromXmltv]）。
  /// 只取**首个** display-name：多语言变体里第一个通常是主名。
  Map<String, String> parseDisplayNames(String xmltv) {
    final names = <String, String>{};
    for (final match in _channelTag.allMatches(xmltv)) {
      final id = _attributes(match.group(1) ?? '')['id']?.trim() ?? '';
      if (id.isEmpty) continue;
      for (final nameMatch in _displayName.allMatches(match.group(2) ?? '')) {
        final name = decodeXmlEntities(nameMatch.group(1) ?? '').trim();
        if (name.isNotEmpty) {
          names[id] = name;
          break;
        }
      }
    }
    return names;
  }

  /// 把 `key="value"` 串成小写键的映射（XMLTV 属性大小写不统一）。
  static Map<String, String> _attributes(String raw) {
    final result = <String, String>{};
    for (final match in _attribute.allMatches(raw)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        result[key.toLowerCase()] = value;
      }
    }
    return result;
  }

  static String? _firstGroup(RegExp pattern, String input) =>
      pattern.firstMatch(input)?.group(1);
}

/// 解析 XMLTV 时间戳，返回 **Unix 秒**。
///
/// 格式是 `YYYYMMDDhhmmss`，可跟一个时区后缀（` +0800` / ` -0500`）。
///
/// 解析不出来返回 `null` 而**不是 0**：0 是 1970-01-01，会让 `isAiring` 恒
/// false、`progress` 算出负数区间，比直接丢一条节目更难排查。
int? parseXmltvTime(String raw) {
  final value = raw.trim();
  if (value.length < 14) return null;

  final digits = value.substring(0, 14);
  for (var i = 0; i < 14; i++) {
    final code = digits.codeUnitAt(i);
    if (code < 0x30 || code > 0x39) return null;
  }

  final year = int.parse(digits.substring(0, 4));
  final month = int.parse(digits.substring(4, 6));
  final day = int.parse(digits.substring(6, 8));
  final hour = int.parse(digits.substring(8, 10));
  final minute = int.parse(digits.substring(10, 12));
  final second = int.parse(digits.substring(12, 14));
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  // 24:00:00 是合法的「当天末尾」写法，交给 DateTime 自然进位。
  if (hour > 24 || minute > 59 || second > 59) return null;

  final rest = value.substring(14).trim();
  if (rest.isEmpty) {
    // 没有时区后缀 → 按本地时间解释（XMLTV 规范允许省略）。
    return DateTime(
          year,
          month,
          day,
          hour,
          minute,
          second,
        ).millisecondsSinceEpoch ~/
        1000;
  }

  final offset = _timezoneOffset(rest);
  if (offset == null) return null;
  return DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
      ).subtract(offset).millisecondsSinceEpoch ~/
      1000;
}

/// 解析 `+0800` / `-05:00` 形式的时区后缀。
Duration? _timezoneOffset(String rest) {
  final match = RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(rest);
  if (match == null) return null;
  final hours = int.parse(match.group(2)!);
  final minutes = int.parse(match.group(3)!);
  if (hours > 23 || minutes > 59) return null;
  final duration = Duration(hours: hours, minutes: minutes);
  return match.group(1) == '-' ? -duration : duration;
}

final RegExp _entityPattern = RegExp(r'&(#x?[0-9A-Fa-f]+|[A-Za-z]+);');

const Map<String, String> _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00a0',
};

/// 还原 XML 实体。
///
/// XMLTV 里标题/简介含 `&amp;` `&lt;` 很常见，不还原的话界面上直接显示
/// `&amp;`。无法识别的实体**原样保留**，不猜、不吞。
String decodeXmlEntities(String raw) =>
    raw.replaceAllMapped(_entityPattern, (match) {
      final body = match.group(1)!;
      if (body.startsWith('#')) {
        final isHex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
        final code = int.tryParse(
          body.substring(isHex ? 2 : 1),
          radix: isHex ? 16 : 10,
        );
        if (code == null || code < 0 || code > 0x10FFFF) {
          return match.group(0)!;
        }
        return String.fromCharCode(code);
      }
      return _namedEntities[body.toLowerCase()] ?? match.group(0)!;
    });
