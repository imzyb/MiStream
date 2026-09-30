import 'package:live/src/live_channel.dart';
import 'package:live/src/live_group.dart';

/// 直播源解析：m3u 与 txt 两种订阅格式。
///
/// 两种格式的真实形状（实测自 `live.zbds.top/tv/iptv4.txt` 与常见 IPTV m3u）：
///
/// **txt**
/// ```
/// 央视频道,#genre#                 ← 分组标记行（不是频道！）
/// CCTV1,http://a/cctv1.m3u8        ← 频道名,地址
/// CCTV1,http://b/cctv1.m3u8        ← 同名再出现一次 = 备用地址
/// 浙江经济生活,http://a/x.m3u8#http://b/y.m3u8   ← `#` 分隔多地址
/// ```
///
/// **m3u**（两种写法都要认）
/// ```
/// #EXTINF:-1 group-title="央视",CCTV-1综合      ← 标准：名字在**行末逗号之后**
/// http://a/cctv1.m3u8
/// ```
/// ```
/// #EXTINF:-1 tvg-name="CCTV1" group-title="央视",   ← 变体：名字独占一行
/// CCTV1
/// http://a/cctv1.m3u8
/// ```
class LiveParser {
  LiveParser();

  /// 解析直播源文本。格式由是否含 `#EXTINF` 自动判定。
  LiveParseResult parse(String content) {
    if (!content.contains('#EXTINF')) {
      return _parseTxt(content);
    }
    return _parseM3u(content);
  }

  // ---------------------------------------------------------------- m3u

  LiveParseResult _parseM3u(String content) {
    final channels = <LiveChannel>[];
    final channelByName = <String, LiveChannel>{};
    final groups = <LiveGroup>[];
    final groupMap = <String, LiveGroup>{};
    final seenUrls = <String>{};

    final lines = content.split('\n');
    var i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXTINF:')) {
        i++;
        continue;
      }

      final info = _parseExtInf(line);
      i++;

      // 名字优先取 `#EXTINF` 行**最后一个逗号之后**的内容（标准 m3u 写法）。
      // 为空有两种可能，用「下一行像不像地址」区分：
      //   1. 名字独占一行（另一种生成器写法）→ 消费它，再去读地址行；
      //   2. 根本没写名字、下一行直接就是地址（靠 tvg-name 取名）→ 这一行
      //      得留给 URL 用，不能当名字吃掉。
      // 不区分的话第 2 种会把地址当成频道名，然后找不到 URL 行，整个频道
      // 直接消失 —— 表现是「这个源导入后少了几个台」，极难往这里想。
      var name = info.inlineName;
      if (name.isEmpty) {
        final next = _nextContentLine(lines, i);
        if (next != null && !_looksLikeUrl(next.text)) {
          name = next.text;
          i = next.index + 1;
        }
      }
      if (name.isEmpty) name = info.tvgName;

      final urlLine = _nextContentLine(lines, i);
      if (urlLine == null) break;
      i = urlLine.index + 1;

      if (name.isEmpty) continue;

      for (final url in splitUrls(urlLine.text)) {
        if (!seenUrls.add(url)) continue;
        final group = _ensureGroup(info.group, groups, groupMap);
        _addChannel(
          channels: channels,
          channelByName: channelByName,
          name: name,
          url: url,
          logo: info.logo,
          groupId: group?.id,
        );
      }
    }

    return LiveParseResult(channels: channels, groups: groups);
  }

  /// 从 [from] 起找第一条「内容行」：非空、且不以 `#` 开头。
  ///
  /// 跳过 `#EXTVLCOPT` / `#EXTGRP` 这类附加指令与空行 —— 它们在真实 m3u 里
  /// 很常见，直接按行号推进会把它们当成频道名或地址。
  static ({int index, String text})? _nextContentLine(
    List<String> lines,
    int from,
  ) {
    for (var i = from; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.isEmpty || text.startsWith('#')) continue;
      return (index: i, text: text);
    }
    return null;
  }

  // ---------------------------------------------------------------- txt

  LiveParseResult _parseTxt(String content) {
    final channels = <LiveChannel>[];
    final channelByName = <String, LiveChannel>{};
    final groups = <LiveGroup>[];
    final groupMap = <String, LiveGroup>{};
    final seenUrls = <String>{};
    String? currentGroupId;

    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      // txt: 频道名,地址（地址可含多个，见 splitUrls）
      final comma = line.indexOf(',');
      if (comma <= 0) continue;
      final name = line.substring(0, comma).trim();
      final urlPart = line.substring(comma + 1).trim();
      if (name.isEmpty || urlPart.isEmpty) continue;

      // 分组标记行 `分组名,#genre#` —— 它是分组声明，不是频道。
      // 不识别的话会多出一个名叫「央视频道」、地址是 `#genre#` 的假频道，
      // 而真正的分组信息全丢。
      if (_isGenreMarker(urlPart)) {
        currentGroupId = _ensureGroup(name, groups, groupMap)?.id;
        continue;
      }

      for (final url in splitUrls(urlPart)) {
        if (!seenUrls.add(url)) continue;
        _addChannel(
          channels: channels,
          channelByName: channelByName,
          name: name,
          url: url,
          groupId: currentGroupId,
        );
      }
    }

    return LiveParseResult(channels: channels, groups: groups);
  }

  static bool _isGenreMarker(String urlPart) =>
      urlPart.toLowerCase() == '#genre#';

  static ({String inlineName, String tvgName, String? group, String? logo})
  _parseExtInf(String line) {
    final groupMatch = RegExp('group-title="([^"]*)"').firstMatch(line);
    final logoMatch = RegExp('tvg-logo="([^"]*)"').firstMatch(line);
    final nameMatch = RegExp('tvg-name="([^"]*)"').firstMatch(line);

    // 行末逗号之后就是频道名。取**最后一个**逗号：属性值里也可能带逗号
    // （例如 `tvg-name="A,B"`）。
    final comma = line.lastIndexOf(',');
    final inlineName = comma >= 0 ? line.substring(comma + 1).trim() : '';

    return (
      inlineName: inlineName,
      tvgName: nameMatch?.group(1)?.trim() ?? '',
      group: groupMatch?.group(1),
      logo: logoMatch?.group(1),
    );
  }
}

// -------------------------------------------------------------------- 共用
//
// 下面三个是 `LiveParser` 与 `LiveParseResult.merge` 共用的构件。放在库级
// 而不是类里，是为了让「单份解析」与「多份合并」走**同一套**分组去重与频道
// 合并规则 —— 两处各写一份，迟早会分叉成两种语义。

/// 取到（必要时新建）名为 [name] 的分组。
///
/// 分组 id 就用名字本身：`LiveGroup.id` 在解析层是「业务键」而不是数据库
/// 主键，用名字做键让 [LiveChannel.groupId] 在落库前就是可读的。
LiveGroup? _ensureGroup(
  String? name,
  List<LiveGroup> groups,
  Map<String, LiveGroup> groupMap,
) {
  if (name == null || name.isEmpty) return null;
  final existing = groupMap[name];
  if (existing != null) return existing;
  final group = LiveGroup(id: name, name: name, order: groupMap.length);
  groupMap[name] = group;
  groups.add(group);
  return group;
}

/// 同名频道再出现时并入备用地址（供换台时按序重试），而不是丢弃。
void _addChannel({
  required List<LiveChannel> channels,
  required Map<String, LiveChannel> channelByName,
  required String name,
  required String url,
  required String? groupId,
  String? logo,
}) {
  final existing = channelByName[name];
  if (existing != null) {
    final idx = channels.indexOf(existing);
    final merged = existing.copyWith(
      extraUrls: [...existing.extraUrls, url],
      // 后出现的分组信息不覆盖已有分组：同名频道跨分组时以第一次为准。
      groupId: existing.groupId ?? groupId,
      logo: existing.logo ?? logo,
    );
    channels[idx] = merged;
    channelByName[name] = merged;
    return;
  }
  final channel = LiveChannel(
    id: _generateId(url),
    name: name,
    url: url,
    logo: logo,
    groupId: groupId,
    isHd: name.contains('HD') || name.contains('\u9ad8\u6e05'),
  );
  channels.add(channel);
  channelByName[name] = channel;
}

String _generateId(String url) => url.hashCode.toRadixString(16);

/// 是否带 URL scheme（`http://` / `rtmp://` / `udp://` …）。
///
/// 单独暴露是因为「这条地址是不是绝对地址」在两个地方都要判：解析时挑出
/// 真地址（[_looksLikeUrl]），以及导入时决定要不要相对配置 URL 解析
/// （`resolveLiveUrl`）。两处各写一个正则迟早会不一致。
final RegExp _schemePattern = RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*://');

/// [value] 是否带 URL scheme。
bool hasUrlScheme(String value) => _schemePattern.hasMatch(value.trim());

/// 把一个「地址字段」拆成多条地址。
///
/// 实测自真实直播源（`live.zbds.top/tv/iptv4.txt`），分隔符的可靠性不一样：
///
/// - **`#` 与 `|` 是格式约定**，确定是分隔符：`url1#url2#url3`。尾随的 `#`
///   也常见（`url#`），拆出来的空段丢弃。
/// - **`,` 与 `;` 有歧义**：`;` 既做过分隔符（`url1;url2`），也出现在 URL
///   自身里（HTML 实体 `&amp;` 的结尾）；`,` 常作为 URL 后的尾随字符出现。
///
/// 所以对 `,` / `;` 用「**拆开后每一段都得像地址**才拆」的判据：只要有一段
/// 不像，就说明它是 URL 内部字符，整段保留。
///
/// 这个判据不是洁癖 —— 旧实现无条件按 `,` `|` `;` 拆，把
/// `...&amp;amp;tpid=1516989100` 拆成了 4 段垃圾地址，比不拆更糟。
List<String> splitUrls(String raw) {
  // 尾随的分隔符是格式产物（`url,` / `url#`），先剥掉 —— 留着会被当成 URL
  // 的一部分，得到一条永远播不了的地址。
  // 刻意**不剥 `;`**：`&amp;` 这类 HTML 实体以分号结尾，剥了会改坏 URL。
  final trimmed = raw.trim().replaceAll(RegExp(r'[,|#\s]+$'), '');
  if (trimmed.isEmpty) return const [];

  // 硬分隔符（格式约定）：拆开后只保留像地址的段。
  final hard = _splitAndKeepUrls(trimmed, RegExp(r'[#|\s]+'));
  if (hard.length > 1) return hard;

  // 软分隔符（有歧义）：**每一段都得像地址**才拆，否则整段保留。
  final parts = trimmed
      .split(RegExp(r'[,;]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.length > 1 && parts.every(_looksLikeUrl)) return parts;

  return _looksLikeUrl(trimmed) ? [trimmed] : const [];
}

/// 按 [separator] 拆开后**只保留像地址的段**。
List<String> _splitAndKeepUrls(String raw, RegExp separator) =>
    raw.split(separator).map((s) => s.trim()).where(_looksLikeUrl).toList();

/// 是否像一个播放地址。
///
/// 判据是**带 scheme**（`http://` / `https://` / `rtmp://` / `rtsp://` /
/// `udp://` / `rtp://` / `file://` …），或绝对路径（`/live/x.m3u8`）。
/// 不含 `://` 的碎片（`amp`、`tpid=...`）一律不算。
bool _looksLikeUrl(String value) {
  final s = value.trim();
  if (s.isEmpty) return false;
  return hasUrlScheme(s) || s.startsWith('/');
}

/// 解析结果。
class LiveParseResult {
  const LiveParseResult({
    required this.channels,
    required this.groups,
  });

  /// 频道。
  final List<LiveChannel> channels;

  /// 分组。
  final List<LiveGroup> groups;

  /// 「未分组」桶的固定 id。
  ///
  /// 没有分组信息的频道（txt 源常见、m3u 里也可能有）归到这里，而不是被
  /// 静默丢掉 —— 丢掉会让分组视图的总数与「全部」对不上，用户以为导入漏了。
  static const ungroupedId = '__ungrouped__';

  /// 未分组桶。
  static const ungroupedGroup = LiveGroup(
    id: ungroupedId,
    name: '未分组',
    order: 1 << 20,
  );

  /// 按分组归类的频道。**含未分组桶**，因此各桶频道数之和 == [channels] 长度。
  Map<LiveGroup, List<LiveChannel>> get channelsByGroup {
    final result = <LiveGroup, List<LiveChannel>>{};
    final byId = {for (final g in groups) g.id: g};
    for (final channel in channels) {
      final group = channel.groupId == null
          ? ungroupedGroup
          : (byId[channel.groupId] ?? ungroupedGroup);
      result.putIfAbsent(group, () => []).add(channel);
    }
    // 保持稳定顺序：先按分组 order，未分组永远排最后。
    final ordered = result.keys.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return {for (final g in ordered) g: result[g]!};
  }

  /// 没有归入任何已声明分组的频道。
  ///
  /// ⚠️ 这个方法**不是**「收藏」—— 旧版本把它命名为 `favoriteChannels`，
  /// 但实现是「groupId 为空」，与收藏毫无关系。收藏在
  /// [LiveRepository.getFavorites]，且是用户行为，不该由解析结果表达。
  List<LiveChannel> get ungroupedChannels =>
      channels.where((c) => c.groupId == null).toList();

  /// 把多份解析结果合并成一份。
  ///
  /// 真实 TVBox 配置的 `lives` 是**一组**订阅源（实测常见 2～16 个），每个
  /// 源各有一份频道表。要显示成一个列表就得合并，而合并规则必须与单份解析
  /// 内完全一致，否则同一个源单独导入和一起导入会得到不同的频道数。
  ///
  /// 规则：
  /// - **分组按名字去重**，顺序按首次出现重排。各源自己的 `order` 值域互不
  ///   相干（都是从 0 数起），直接保留会让分组顺序看起来是随机的。
  /// - **同名频道合并**：备用地址追加，主地址取首次出现的那个。
  /// - **同地址去重**：多个源收同一个流很常见。
  static LiveParseResult merge(List<LiveParseResult> results) {
    final channels = <LiveChannel>[];
    final channelByName = <String, LiveChannel>{};
    final groups = <LiveGroup>[];
    final groupMap = <String, LiveGroup>{};
    final seenUrls = <String>{};

    for (final result in results) {
      // 先把该结果声明的分组登记进合并表：这样 `groupId` 才一定能被
      // [channelsByGroup] 解析到，不会掉进未分组桶。
      for (final group in result.groups) {
        _ensureGroup(group.name, groups, groupMap);
      }
      for (final channel in result.channels) {
        for (final url in channel.allUrls) {
          if (!seenUrls.add(url)) continue;
          _addChannel(
            channels: channels,
            channelByName: channelByName,
            name: channel.name,
            url: url,
            groupId: channel.groupId,
            logo: channel.logo,
          );
        }
      }
    }

    return LiveParseResult(channels: channels, groups: groups);
  }
}
