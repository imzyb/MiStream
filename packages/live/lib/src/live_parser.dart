import 'package:live/src/live_channel.dart';
import 'package:live/src/live_group.dart';

class LiveParser {
  LiveParseResult parse(String content) {
    final channels = <LiveChannel>[];
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
            final url = lines[i].trim();
            if (url.isNotEmpty &&
                !url.startsWith('#') &&
                !seenUrls.contains(url)) {
              seenUrls.add(url);

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

              channels.add(
                LiveChannel(
                  id: _generateId(url),
                  name: nameLine,
                  url: url,
                  logo: info['logo'],
                  groupId: group?.id,
                  isHd:
                      nameLine.contains('HD') ||
                      nameLine.contains('\u9ad8\u6e05'),
                ),
              );
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
