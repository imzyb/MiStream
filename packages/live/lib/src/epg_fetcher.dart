import 'dart:convert';

import 'package:live/src/live_epg.dart';

/// 拉取 EPG 文本的传输层。可注入（同 `LiveContentFetcher` 的理由：真实网络
/// 在测试里不可控，沙箱还禁止本地回环）。
typedef EpgContentFetcher = Future<String> Function(String url);

/// 展开配置里的 `epg` 模板。
///
/// 真实配置里是 `http://epg.51zmt.top:8000/api/diyp/?ch={name}&date={date}`
/// 这种模板，不是可以直接请求的地址。
///
/// 两个占位符都要处理：`{name}` 是**频道名**（中文，必须 URL 编码，否则请求
/// 行里出现非 ASCII 字节），`{date}` 是 `YYYY-MM-DD`。
String expandEpgUrl(
  String template, {
  required String channelName,
  required DateTime date,
}) {
  final day =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return template
      .replaceAll('{name}', Uri.encodeComponent(channelName))
      .replaceAll('{date}', day);
}

/// 一个频道的 EPG 请求。
class EpgRequest {
  /// 构造请求。
  const EpgRequest({
    required this.channelId,
    required this.channelName,
    required this.url,
  });

  /// 频道 id（用于把结果对回频道）。
  final String channelId;

  /// 频道名（源站用它查节目单）。
  final String channelName;

  /// 已展开的 EPG 地址。
  final String url;
}

/// 源站加在标题尾巴上的标记。
///
/// 实测只有 `--免费使用` 一种。**只剥白名单里的词**，不按「最后一个 `--`」
/// 一刀切 —— 正常节目标题里也可能有 `--`（如「XX--特别篇」），切掉就是改坏
/// 数据。
final RegExp _trailingMarker = RegExp(r'\s*--\s*(免费使用|免费|试用)\s*$');

/// 去掉 EPG 标题的源站后缀。
String cleanEpgTitle(String raw) =>
    raw.trim().replaceFirst(_trailingMarker, '').trim();

/// 解析 112114 / 51zmt 风格的 EPG JSON 接口。
///
/// 实测响应（`http://epg.51zmt.top:8000/api/diyp/?ch=CCTV1&date=2026-10-01`）：
///
/// ```json
/// {
///   "channel_name": "CCTV-1综合",
///   "date": "2026-10-01",
///   "epg_data": [
///     {"start": "01:03", "end": "01:47", "title": "生活早参考-特别节目(生活圈)2026-268 --免费使用"}
///   ]
/// }
/// ```
///
/// 三个必须处理的坑（都是实测出来的，不是推测）：
///
/// 1. **`start` / `end` 只有当天的 `HH:mm`**，日期在顶层 `date` 字段里。
/// 2. **跨天节目**：实测末条是 `23:32 -> 01:11`，`end` 小于 `start` 时表示
///    次日。不处理的话时长是负数，`isAiring` 永远 false、`progress` 除负数。
/// 3. **标题带源站后缀**（`--免费使用`），照原样显示会很碍眼。
///
/// 注意 TVBox 配置里 `epg` 字段指向的接口**不一定是 JSON** —— 也有直接给
/// XMLTV 文件的。格式靠内容嗅探，见 [EpgFetcher]。
class EpgJsonParser {
  /// 构造解析器。
  const EpgJsonParser();

  /// 解析 [body]，对回 [channelId]。
  ///
  /// 返回 `null` 表示「这份响应根本不能用」（不是 JSON、缺 `date`、
  /// `epg_data` 不是数组）—— 与「解析成功但节目为空」区分开：前者是源站
  /// 问题，后者可能是当天真的没节目。
  LiveEpg? parse(
    String body, {
    required String channelId,
    String? fallbackName,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final rawDate = decoded['date'];
    final date = rawDate is String ? DateTime.tryParse(rawDate.trim()) : null;
    if (date == null) return null;

    final rawList = decoded['epg_data'];
    if (rawList is! List) return null;

    final programs = <EpgProgram>[];
    for (final item in rawList) {
      if (item is! Map) continue;

      final start = _parseClock(item['start'], date);
      if (start == null) continue;
      var end = _parseClock(item['end'], date);
      if (end == null) continue;
      // 跨天：见类文档第 2 点。
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));

      programs.add(
        EpgProgram(
          title: cleanEpgTitle('${item['title'] ?? ''}'),
          startTime: start.millisecondsSinceEpoch ~/ 1000,
          endTime: end.millisecondsSinceEpoch ~/ 1000,
        ),
      );
    }
    programs.sort((a, b) => a.startTime.compareTo(b.startTime));

    final name = decoded['channel_name'];
    return LiveEpg(
      channelId: channelId,
      channelName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : (fallbackName ?? channelId),
      programs: programs,
    );
  }

  /// 把 `HH:mm` 按 [date] 拼成时刻。
  ///
  /// `24:00` 是 EPG 接口里常见的「当天末尾」写法，交给 `DateTime` 自然进位。
  static DateTime? _parseClock(Object? value, DateTime date) {
    if (value is! String) return null;
    final parts = value.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 24 || minute < 0 || minute > 59) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(hours: hour, minutes: minute));
  }
}

/// 拉取并解析频道的 EPG。
///
/// 与 `LiveImporter` 同一套约定：**传输层可注入**，**单个频道失败不冒泡**
/// （源站只收录了一部分频道是常态，拉不到的台不该让整批失败）。
///
/// 两个入口：
///
/// * [loadFor] —— 按配置里的 `epg` 模板为**一个频道**拉取。这是 app 实际用
///   的入口：节目单只在用户真的点进某个台时才需要，为几百个频道预拉一遍
///   既慢又不礼貌。
/// * [fetchAll] —— 批量拉取已展开好的地址（给未来的「预取整张表」用）。
class EpgFetcher {
  /// 构造。
  ///
  /// [fetcher] 是传输层；[templates] 是配置里的 `epg` 模板（含 `{name}` /
  /// `{date}` 占位符），可后续用 [updateTemplates] 更新；[parser] 默认
  /// [EpgJsonParser]。
  EpgFetcher({
    required EpgContentFetcher fetcher,
    List<String> templates = const [],
    EpgJsonParser? parser,
  }) : _fetcher = fetcher,
       _parser = parser ?? const EpgJsonParser() {
    updateTemplates(templates);
  }

  final EpgContentFetcher _fetcher;
  final EpgJsonParser _parser;

  /// 去重后的模板列表（保持配置里的先后顺序）。
  final List<String> _templates = [];

  /// 已拉到的节目单，按频道 id 缓存。
  final Map<String, LiveEpg> _cache = {};

  /// 配置里的 EPG 模板。空列表表示「这个配置没提供 EPG」。
  List<String> get templates => List.unmodifiable(_templates);

  /// 是否具备拉取条件。
  bool get hasTemplates => _templates.isNotEmpty;

  /// 更新模板（配置重新导入时调用）。
  ///
  /// 去重 + 丢弃空白项：真实配置里多个 `lives` 项常常写同一个 `epg`，不去重
  /// 会让每个频道重复请求同一个地址。
  void updateTemplates(List<String> templates) {
    _templates
      ..clear()
      ..addAll(
        templates.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet(),
      );
  }

  /// 为 [channelId] 拉取节目单。
  ///
  /// 依次尝试 [templates] 里的每个模板，取**第一个拿到节目的**；都拿不到时
  /// 返回 `null`。结果按 [channelId] 缓存，重复调用不再打网络。
  ///
  /// [date] 缺省为今天。
  Future<LiveEpg?> loadFor(
    String channelId,
    String channelName, {
    DateTime? date,
  }) async {
    final cached = _cache[channelId];
    if (cached != null) return cached;
    if (!hasTemplates || channelName.trim().isEmpty) return null;

    final day = date ?? DateTime.now();
    LiveEpg? firstParsed;
    for (final template in _templates) {
      try {
        final url = expandEpgUrl(
          template,
          channelName: channelName,
          date: day,
        );
        final body = await _fetcher(url);
        final epg = parseBody(
          body,
          channelId: channelId,
          channelName: channelName,
        );
        if (epg == null) continue;
        firstParsed ??= epg;
        if (epg.programs.isNotEmpty) {
          _cache[channelId] = epg;
          return epg;
        }
      } on Object {
        // 单个模板失败就试下一个，见类文档。
      }
    }
    // 所有模板都只有空节目单：仍然给一个结果（界面能显示「暂无节目单」），
    // 但**不进缓存** —— 换台回来时再试一次，源站补数据是常态。
    return firstParsed;
  }

  /// 按内容嗅探格式并解析。
  ///
  /// 配置里 `epg` 指向的既可能是 JSON 接口（112114 / 51zmt），也可能是
  /// XMLTV 文件。**先按看起来像的那个试，失败再试另一个** —— 比只看开头
  /// 一个字符更稳（有源站会在 XML 前面吐 BOM 或注释）。
  LiveEpg? parseBody(
    String body, {
    required String channelId,
    required String channelName,
  }) {
    final looksXml = body.trimLeft().startsWith('<');
    LiveEpg? tryJson() => _parser.parse(
      body,
      channelId: channelId,
      fallbackName: channelName,
    );
    LiveEpg? tryXmltv() {
      final epg = LiveEpg.fromXmltv(channelId, channelName, body);
      return epg.programs.isEmpty ? null : epg;
    }

    return looksXml ? (tryXmltv() ?? tryJson()) : (tryJson() ?? tryXmltv());
  }

  /// 批量拉取（串行，理由同 `LiveImporter`：顺序可预测、对源站客气）。
  ///
  /// 返回成功拉到的部分；[requests] 里失败或解析不了的频道不会出现在结果里。
  Future<Map<String, LiveEpg>> fetchAll(List<EpgRequest> requests) async {
    for (final request in requests) {
      try {
        final body = await _fetcher(request.url);
        final epg = parseBody(
          body,
          channelId: request.channelId,
          channelName: request.channelName,
        );
        if (epg != null) _cache[request.channelId] = epg;
      } on Object {
        // 单个频道拉不到就跳过，见类文档。
      }
    }
    return Map.unmodifiable(_cache);
  }

  /// 取缓存里的节目单。
  LiveEpg? getEpg(String channelId) => _cache[channelId];

  /// 清空缓存。
  void clearCache() => _cache.clear();
}
