import 'package:test/test.dart';
import 'package:media_sniffer/media_sniffer.dart';

void main() {
  group('MediaType', () {
    test('fromUrl detects m3u8', () {
      expect(
        MediaType.fromUrl('https://example.com/video.m3u8'),
        MediaType.hls,
      );
      expect(
        MediaType.fromUrl('https://example.com/video.m3u8?token=abc'),
        MediaType.hls,
      );
    });

    test('fromUrl detects mp4', () {
      expect(MediaType.fromUrl('https://example.com/video.mp4'), MediaType.mp4);
    });

    test('fromUrl detects mp3', () {
      expect(MediaType.fromUrl('https://example.com/audio.mp3'), MediaType.mp3);
    });

    test('fromUrl detects flv', () {
      expect(MediaType.fromUrl('https://example.com/video.flv'), MediaType.flv);
    });

    test('fromUrl returns other for unknown', () {
      expect(
        MediaType.fromUrl('https://example.com/video.xyz'),
        MediaType.other,
      );
    });

    test('fromMime detects hls', () {
      expect(MediaType.fromMime('application/x-mpegURL'), MediaType.hls);
      expect(
        MediaType.fromMime('application/vnd.apple.mpegurl'),
        MediaType.hls,
      );
    });

    test('fromMime detects mp4', () {
      expect(MediaType.fromMime('video/mp4'), MediaType.mp4);
    });

    test('fromMime detects mp3', () {
      expect(MediaType.fromMime('audio/mpeg'), MediaType.mp3);
    });
  });

  group('SnifferRule', () {
    test('matchesUrl returns true for matching pattern', () {
      const rule = SnifferRule(name: 'HLS', urlPattern: r'\.m3u8');
      expect(rule.matchesUrl('https://example.com/video.m3u8'), true);
      expect(rule.matchesUrl('https://example.com/video.mp4'), false);
    });

    test('matchesUrl returns false when disabled', () {
      const rule = SnifferRule(
        name: 'HLS',
        urlPattern: r'\.m3u8',
        enabled: false,
      );
      expect(rule.matchesUrl('https://example.com/video.m3u8'), false);
    });

    test('matchesContent returns true when no pattern', () {
      const rule = SnifferRule(name: 'HLS', urlPattern: r'\.m3u8');
      expect(rule.matchesContent('any content'), true);
    });

    test('matchesContent returns true for matching pattern', () {
      const rule = SnifferRule(
        name: 'HLS',
        urlPattern: r'\.m3u8',
        contentPattern: r'#EXTM3U',
      );
      expect(rule.matchesContent('#EXTM3U\n#EXTINF:10'), true);
      expect(rule.matchesContent('no match'), false);
    });

    test('toJson/fromJson roundtrip', () {
      const rule = SnifferRule(
        name: 'Test',
        urlPattern: r'\.test',
        priority: 50,
      );
      final json = rule.toJson();
      final restored = SnifferRule.fromJson(json);
      expect(restored.name, rule.name);
      expect(restored.urlPattern, rule.urlPattern);
      expect(restored.priority, rule.priority);
    });

    test('defaults list has 9 rules', () {
      expect(SnifferRule.defaults.length, 9);
    });
  });

  group('SnifferResult', () {
    test('equality by url and type', () {
      const r1 = SnifferResult(url: 'http://a.com/v.m3u8', type: MediaType.hls);
      const r2 = SnifferResult(url: 'http://a.com/v.m3u8', type: MediaType.hls);
      const r3 = SnifferResult(url: 'http://a.com/v.mp4', type: MediaType.mp4);
      expect(r1, equals(r2));
      expect(r1 == r3, false);
    });

    test('hashCode matches equality', () {
      const r1 = SnifferResult(url: 'http://a.com/v.m3u8', type: MediaType.hls);
      const r2 = SnifferResult(url: 'http://a.com/v.m3u8', type: MediaType.hls);
      expect(r1.hashCode, r2.hashCode);
    });
  });

  group('MediaDetector', () {
    late MediaDetector detector;

    setUp(() {
      detector = MediaDetector();
    });

    test('detectFromHtml extracts video src', () {
      final html = '<video src="https://example.com/video.mp4"></video>';
      final results = detector.detectFromHtml(html);
      expect(results.length, 1);
      expect(results.first.url, 'https://example.com/video.mp4');
      expect(results.first.type, MediaType.mp4);
    });

    test('detectFromHtml extracts source src', () {
      final html = '<source src="https://example.com/video.m3u8">';
      final results = detector.detectFromHtml(html);
      expect(results.length, 1);
      expect(results.first.url, 'https://example.com/video.m3u8');
      expect(results.first.type, MediaType.hls);
    });

    test('detectFromJs extracts m3u8 url', () {
      final js = 'var url = "https://example.com/video.m3u8";';
      final results = detector.detectFromJs(js);
      expect(results.length, 1);
      expect(results.first.url, 'https://example.com/video.m3u8');
      expect(results.first.type, MediaType.hls);
    });

    test('detectFromJs extracts mp4 url', () {
      final js = "file: 'https://example.com/video.mp4'";
      final results = detector.detectFromJs(js);
      expect(results.length, 1);
      expect(results.first.url, 'https://example.com/video.mp4');
    });

    test('detectFromHtml deduplicates urls', () {
      final html = '''
        <video src="https://example.com/video.mp4"></video>
        <source src="https://example.com/video.mp4">
      ''';
      final results = detector.detectFromHtml(html);
      expect(results.length, 1);
    });

    test('parseM3u8 extracts segment urls', () {
      final content = '''
#EXTM3U
#EXTINF:10.0,
segment001.ts
#EXTINF:10.0,
segment002.ts
#EXTINF:10.0,
segment003.ts
''';
      final segments = detector.parseM3u8(content);
      expect(segments.length, 3);
      expect(segments[0], 'segment001.ts');
      expect(segments[1], 'segment002.ts');
      expect(segments[2], 'segment003.ts');
    });

    test('parseM3u8 with baseUrl resolves relative urls', () {
      final content = '''
#EXTM3U
segment001.ts
segment002.ts
''';
      final segments = detector.parseM3u8(
        content,
        baseUrl: 'https://example.com/path/to/playlist.m3u8',
      );
      expect(segments.length, 2);
      expect(segments[0], 'https://example.com/path/to/segment001.ts');
      expect(segments[1], 'https://example.com/path/to/segment002.ts');
    });

    test('isMasterPlaylist returns true for master playlist', () {
      final content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720
low/medium.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080
high/high.m3u8
''';
      expect(detector.isMasterPlaylist(content), true);
    });

    test('isMasterPlaylist returns false for media playlist', () {
      final content = '''
#EXTM3U
#EXTINF:10.0,
segment001.ts
''';
      expect(detector.isMasterPlaylist(content), false);
    });

    test('parseMasterPlaylist extracts streams', () {
      final content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720,CODECS="avc1.64001f,mp4a.40.2"
low/medium.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
high/high.m3u8
''';
      final streams = detector.parseMasterPlaylist(content);
      expect(streams.length, 2);
      expect(streams[0].bandwidth, 1000000);
      expect(streams[0].resolution, '1280x720');
      expect(streams[0].codecs, 'avc1.64001f,mp4a.40.2');
      expect(streams[1].bandwidth, 2000000);
    });
  });

  group('SnifferEngine', () {
    late SnifferEngine engine;

    setUp(() {
      engine = SnifferEngine();
    });

    test('sniffHtml detects video sources', () {
      final html = '<video src="https://example.com/video.mp4"></video>';
      final results = engine.sniffHtml(html);
      // May find multiple results due to rule matching
      expect(results.length, greaterThanOrEqualTo(1));
      expect(
        results.any((r) => r.url == 'https://example.com/video.mp4'),
        true,
      );
    });

    test('sniffJs detects m3u8 urls', () {
      final js = 'src: "https://example.com/video.m3u8"';
      final results = engine.sniffJs(js);
      // May find multiple results due to rule matching
      expect(results.length, greaterThanOrEqualTo(1));
      expect(
        results.any((r) => r.url == 'https://example.com/video.m3u8'),
        true,
      );
    });

    test('addRule adds custom rule', () {
      final rule = SnifferRule(name: 'Custom', urlPattern: r'\.custom');
      engine.addRule(rule);
      expect(engine.rules.length, SnifferRule.defaults.length + 1);
    });

    test('removeRule removes rule by name', () {
      engine.removeRule('HLS');
      expect(engine.rules.length, SnifferRule.defaults.length - 1);
    });

    test('resetRules restores defaults', () {
      engine.addRule(SnifferRule(name: 'Custom', urlPattern: r'\.custom'));
      engine.resetRules();
      expect(engine.rules.length, SnifferRule.defaults.length);
    });

    test('parseM3u8 returns M3u8ParseResult', () {
      final content = '''
#EXTM3U
#EXTINF:10.0,
segment001.ts
#EXTINF:10.0,
segment002.ts
''';
      final result = engine.parseM3u8(content);
      expect(result.isMaster, false);
      expect(result.segments.length, 2);
    });

    test('parseM3u8 handles master playlist', () {
      final content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000000
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000000
high.m3u8
''';
      final result = engine.parseM3u8(content);
      expect(result.isMaster, true);
      expect(result.streams.length, 2);
      expect(result.bestStream?.bandwidth, 2000000);
      expect(result.worstStream?.bandwidth, 1000000);
    });
  });
}
