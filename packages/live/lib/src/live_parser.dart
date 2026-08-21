import 'package:live/src/live_channel.dart';
import 'package:live/src/live_group.dart';

class LiveParser {
  LiveParseResult parse(String content) {
    // txt 无 #EXTINF 时按 “频道名,url” 每行解析
    if (!content.contains('#EXTINF')) {
      return _parseTxt(content);
    }

    final channels = <LiveChannel>[];
    final channelByName = <String, LiveChannel>{};
    final groups = <LiveGroup>[];
    final groupMap = <String, LiveGroup>{};
    final seenUrls = <String>{};

    final lines = content.split('\n');
    var i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.isEmpty || !line.startsWith('#EXTINF:')) {
        i++;
        continue;
      }

      final info = _parseExtInf(line);
      i++;

      if (i < lines.length) {
        final nameLine = lines[i].trim();
        if (nameLine.isNotEmpty && !nameLine.startsWith('#')) {
          i++;
          if (i < lines.length) {
            final rawUrl = lines[i].trim();
            final urls = _splitUrls(rawUrl);
            for (final url in urls) {
              if (url.isEmpty || url.startsWith('#') || !seenUrls.add(url)) {
                continue;
              }

              LiveGroup? group;
              final groupName = info['group'];
              if (groupName != null && groupName.isNotEmpty) {
                if (!groupMap.containsKey(groupName)) {
                  group = LiveGroup(
                    id: groupName,
                    name: groupName,
                    order: groupMap.length,
                  );
                  groupMap[groupName] = group;
                  groups.add(group);
                } else {
                  group = groupMap[groupName];
                }
              }

              final existing = channelByName[nameLine];
              if (existing != null) {
                // 同名频道：把新地址加入备用列表，供重试
                final idx = channels.indexOf(existing);
                channels[idx] = existing.copyWith(
                  extraUrls: [...existing.extraUrls, url],
                );
                channelByName[nameLine] = channels[idx];
              } else {
                final ch = LiveChannel(
                  id: _generateId(url),
                  name: nameLine,
                  url: url,
                  logo: info['logo'],
                  groupId: group?.id,
                  isHd:
                      nameLine.contains('HD') ||
                      nameLine.contains('\u9ad8\u6e05'),
                );
                channels.add(ch);
                channelByName[nameLine] = ch;
              }
            }
          }
        }
      }

      i++;
    }

    return LiveParseResult(
      channels: channels,
      groups: groups,
    );
  }

  LiveParseResult _parseTxt(String content) {
    final channels = <LiveChannel>[];
    final channelByName = <String, LiveChannel>{};
    final seenUrls = <String>{};
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      // txt: 频道名,url 或 频道名,url1|url2
      final comma = line.indexOf(',');
      if (comma <= 0) continue;
      final name = line.substring(0, comma).trim();
      final urlPart = line.substring(comma + 1).trim();
      if (name.isEmpty || urlPart.isEmpty) continue;
      final urls = _splitUrls(urlPart);
      for (final url in urls) {
        if (!seenUrls.add(url)) continue;
        final existing = channelByName[name];
        if (existing != null) {
          final idx = channels.indexOf(existing);
          channels[idx] = existing.copyWith(
            extraUrls: [...existing.extraUrls, url],
          );
          channelByName[name] = channels[idx];
        } else {
          final ch = LiveChannel(id: _generateId(url), name: name, url: url);
          channels.add(ch);
          channelByName[name] = ch;
        }
      }
    }
    return LiveParseResult(channels: channels, groups: const []);
  }

  List<String> _splitUrls(String raw) {
    // 常见分隔：逗号、分号、竖线、空格
    if (raw.contains(','))
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    if (raw.contains('|'))
      return raw
          .split('|')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    if (raw.contains(';'))
      return raw
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    return [raw.trim()];
  }

  Map<String, String?> _parseExtInf(String line) {
    final result = <String, String?>{
      'name': null,
      'group': null,
      'logo': null,
    };

    final groupMatch = RegExp('group-title="([^"]*)"').firstMatch(line);
    if (groupMatch != null) {
      result['group'] = groupMatch.group(1);
    }

    final logoMatch = RegExp('tvg-logo="([^"]*)"').firstMatch(line);
    if (logoMatch != null) {
      result['logo'] = logoMatch.group(1);
    }

    return result;
  }

  String _generateId(String url) {
    return url.hashCode.toRadixString(16);
  }
}

class LiveParseResult {
  const LiveParseResult({
    required this.channels,
    required this.groups,
  });
  final List<LiveChannel> channels;
  final List<LiveGroup> groups;

  Map<LiveGroup, List<LiveChannel>> get channelsByGroup {
    final result = <LiveGroup, List<LiveChannel>>{};
    for (final channel in channels) {
      final group = groups.where((g) => g.id == channel.groupId).firstOrNull;
      if (group != null) {
        result.putIfAbsent(group, () => []).add(channel);
      }
    }
    return result;
  }

  List<LiveChannel> get favoriteChannels {
    return channels.where((c) => c.groupId == null).toList();
  }
}
