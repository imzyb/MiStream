import 'package:test/test.dart';
import 'package:live/live.dart';

void main() {
  group('LiveChannel', () {
    test('fromJson creates channel correctly', () {
      final json = {
        'id': 'ch1',
        'name': 'CCTV1',
        'url': 'http://example.com/live.m3u8',
        'logo': 'http://example.com/logo.png',
        'groupId': 'group1',
        'isHd': true,
      };
      final channel = LiveChannel.fromJson(json);
      expect(channel.id, 'ch1');
      expect(channel.name, 'CCTV1');
      expect(channel.url, 'http://example.com/live.m3u8');
      expect(channel.logo, 'http://example.com/logo.png');
      expect(channel.groupId, 'group1');
      expect(channel.isHd, true);
    });

    test('toJson roundtrip', () {
      const channel = LiveChannel(
        id: 'ch1',
        name: 'CCTV1',
        url: 'http://example.com/live.m3u8',
        isHd: true,
      );
      final json = channel.toJson();
      final restored = LiveChannel.fromJson(json);
      expect(restored.id, channel.id);
      expect(restored.name, channel.name);
      expect(restored.url, channel.url);
      expect(restored.isHd, channel.isHd);
    });

    test('copyWith creates new instance', () {
      const channel = LiveChannel(
        id: 'ch1',
        name: 'CCTV1',
        url: 'http://a.com',
      );
      final updated = channel.copyWith(name: 'CCTV2');
      expect(updated.name, 'CCTV2');
      expect(updated.id, 'ch1');
      expect(channel.name, 'CCTV1'); // original unchanged
    });

    test('equality by id and url', () {
      const c1 = LiveChannel(id: 'ch1', name: 'CCTV1', url: 'http://a.com');
      const c2 = LiveChannel(id: 'ch1', name: 'CCTV2', url: 'http://a.com');
      const c3 = LiveChannel(id: 'ch2', name: 'CCTV1', url: 'http://a.com');
      expect(c1, equals(c2));
      expect(c1 == c3, false);
    });
  });

  group('LiveGroup', () {
    test('fromJson creates group correctly', () {
      final json = {
        'id': 'g1',
        'name': '央视',
        'order': 1,
        'isFavorite': false,
      };
      final group = LiveGroup.fromJson(json);
      expect(group.id, 'g1');
      expect(group.name, '央视');
      expect(group.order, 1);
      expect(group.isFavorite, false);
    });

    test('toJson roundtrip', () {
      const group = LiveGroup(id: 'g1', name: '央视', order: 1);
      final json = group.toJson();
      final restored = LiveGroup.fromJson(json);
      expect(restored.id, group.id);
      expect(restored.name, group.name);
      expect(restored.order, group.order);
    });

    test('equality by id', () {
      const g1 = LiveGroup(id: 'g1', name: '央视');
      const g2 = LiveGroup(id: 'g1', name: '卫视');
      const g3 = LiveGroup(id: 'g2', name: '央视');
      expect(g1, equals(g2));
      expect(g1 == g3, false);
    });
  });

  group('LiveParser', () {
    late LiveParser parser;

    setUp(() {
      parser = LiveParser();
    });

    test('parses simple m3u playlist', () {
      final content = '''
#EXTM3U
#EXTINF:-1 tvg-name="CCTV1" group-title="央视" tvg-logo="http://logo.png",
CCTV1
http://example.com/cctv1.m3u8
#EXTINF:-1 tvg-name="CCTV2" group-title="央视",
CCTV2
http://example.com/cctv2.m3u8
#EXTINF:-1 tvg-name="湖南卫视" group-title="卫视",
湖南卫视
http://example.com/hunan.m3u8
''';
      final result = parser.parse(content);
      expect(result.channels.length, 3);
      expect(result.groups.length, 2);
      expect(result.channels[0].name, 'CCTV1');
      expect(result.channels[0].url, 'http://example.com/cctv1.m3u8');
      expect(result.channels[0].logo, 'http://logo.png');
    });

    test('deduplicates channels by url', () {
      final content = '''
#EXTM3U
#EXTINF:-1,
CCTV1
http://example.com/cctv1.m3u8
#EXTINF:-1,
CCTV1 Duplicate
http://example.com/cctv1.m3u8
''';
      final result = parser.parse(content);
      expect(result.channels.length, 1);
    });

    test('channelsByGroup groups correctly', () {
      final content = '''
#EXTM3U
#EXTINF:-1 group-title="央视",
CCTV1
http://example.com/cctv1.m3u8
#EXTINF:-1 group-title="卫视",
湖南卫视
http://example.com/hunan.m3u8
#EXTINF:-1 group-title="央视",
CCTV2
http://example.com/cctv2.m3u8
''';
      final result = parser.parse(content);
      final byGroup = result.channelsByGroup;
      expect(byGroup.length, 2);
    });
  });

  group('LiveEpg', () {
    test('currentProgram returns current show', () {
      final now = DateTime.now();
      final programs = [
        EpgProgram(
          title: 'Previous',
          startTime:
              now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/
              1000,
          endTime:
              now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000,
        ),
        EpgProgram(
          title: 'Current',
          startTime:
              now
                  .subtract(const Duration(minutes: 30))
                  .millisecondsSinceEpoch ~/
              1000,
          endTime:
              now.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/
              1000,
        ),
        EpgProgram(
          title: 'Next',
          startTime:
              now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          endTime:
              now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
        ),
      ];
      final epg = LiveEpg(
        channelId: 'ch1',
        channelName: 'CCTV1',
        programs: programs,
      );
      expect(epg.currentProgram?.title, 'Current');
      expect(epg.nextProgram?.title, 'Next');
    });

    test('isAiring returns true for current program', () {
      final now = DateTime.now();
      final program = EpgProgram(
        title: 'Current',
        startTime:
            now.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch ~/
            1000,
        endTime:
            now.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
      );
      expect(program.isAiring, true);
    });

    test('progress returns percentage for current program', () {
      final now = DateTime.now();
      final program = EpgProgram(
        title: 'Current',
        startTime:
            now.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch ~/
            1000,
        endTime:
            now.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
      );
      expect(program.progress, greaterThanOrEqualTo(40));
      expect(program.progress, lessThanOrEqualTo(60));
    });
  });

  group('InMemoryLiveRepository', () {
    late InMemoryLiveRepository repo;

    setUp(() {
      repo = InMemoryLiveRepository();
    });

    test('importM3u loads channels and groups', () async {
      final content = '''
#EXTM3U
#EXTINF:-1 group-title="央视",
CCTV1
http://example.com/cctv1.m3u8
#EXTINF:-1 group-title="卫视",
湖南卫视
http://example.com/hunan.m3u8
''';
      await repo.importM3u(content);
      final channels = await repo.getChannels();
      final groups = await repo.getGroups();
      expect(channels.length, 2);
      expect(groups.length, 2);
    });

    test('addFavorite and getFavorites', () async {
      final content = '''
#EXTM3U
#EXTINF:-1,
CCTV1
http://example.com/cctv1.m3u8
''';
      await repo.importM3u(content);
      final channels = await repo.getChannels();
      await repo.addFavorite(channels.first.id);
      final favorites = await repo.getFavorites();
      expect(favorites.length, 1);
      expect(favorites.first.name, 'CCTV1');
    });

    test('removeFavorite removes channel', () async {
      final content = '''
#EXTM3U
#EXTINF:-1,
CCTV1
http://example.com/cctv1.m3u8
''';
      await repo.importM3u(content);
      final channels = await repo.getChannels();
      await repo.addFavorite(channels.first.id);
      await repo.removeFavorite(channels.first.id);
      final favorites = await repo.getFavorites();
      expect(favorites.length, 0);
    });

    test('searchChannels finds by name', () async {
      final content = '''
#EXTM3U
#EXTINF:-1,
CCTV1
http://example.com/cctv1.m3u8
#EXTINF:-1,
湖南卫视
http://example.com/hunan.m3u8
''';
      await repo.importM3u(content);
      final results = await repo.searchChannels('CCTV');
      expect(results.length, 1);
      expect(results.first.name, 'CCTV1');
    });
  });
}
