import 'package:media_sniffer/src/sniffer_result.dart';

class MediaDetector {
  static final List<RegExp> _htmlMediaPatterns = [
    RegExp(r'<video[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false),
    RegExp(r'<source[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false),
    RegExp(r'<audio[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false),
    RegExp(r'<iframe[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false),
  ];

  static final List<RegExp> _jsMediaPatterns = [
    RegExp(
      r'(?:src|url|file)\s*[=:]\s*["\x27]([^"\x27]*\.m3u8[^"\x27]*)["\x27]',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:src|url|file)\s*[=:]\s*["\x27]([^"\x27]*\.mp4[^"\x27]*)["\x27]',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:src|url|file)\s*[=:]\s*["\x27]([^"\x27]*\.flv[^"\x27]*)["\x27]',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:src|url|file)\s*[=:]\s*["\x27]([^"\x27]*\.mp3[^"\x27]*)["\x27]',
      caseSensitive: false,
    ),
  ];

  List<SnifferResult> detectFromHtml(String html, {String? referer}) {
    final results = <SnifferResult>[];
    final seen = <String>{};

    for (final pattern in _htmlMediaPatterns) {
      for (final match in pattern.allMatches(html)) {
        final url = match.group(1);
        if (url != null && !seen.contains(url)) {
          seen.add(url);
          results.add(
            SnifferResult(
              url: url,
              type: MediaType.fromUrl(url),
              referer: referer,
            ),
          );
        }
      }
    }

    return results;
  }

  List<SnifferResult> detectFromJs(String js, {String? referer}) {
    final results = <SnifferResult>[];
    final seen = <String>{};

    for (final pattern in _jsMediaPatterns) {
      for (final match in pattern.allMatches(js)) {
        final url = match.group(1);
        if (url != null && !seen.contains(url)) {
          seen.add(url);
          results.add(
            SnifferResult(
              url: url,
              type: MediaType.fromUrl(url),
              referer: referer,
            ),
          );
        }
      }
    }

    return results;
  }

  List<String> parseM3u8(String content, {String? baseUrl}) {
    final segments = <String>[];
    final baseUri = baseUrl != null ? Uri.parse(baseUrl) : null;

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (baseUri != null && !trimmed.startsWith('http')) {
        segments.add(baseUri.resolve(trimmed).toString());
      } else {
        segments.add(trimmed);
      }
    }

    return segments;
  }

  bool isMasterPlaylist(String content) {
    return content.contains('#EXT-X-STREAM-INF');
  }

  List<M3u8StreamInfo> parseMasterPlaylist(String content) {
    final streams = <M3u8StreamInfo>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final info = _parseStreamInfo(line);
        if (i + 1 < lines.length) {
          final url = lines[i + 1].trim();
          if (url.isNotEmpty && !url.startsWith('#')) {
            streams.add(
              M3u8StreamInfo(
                url: url,
                bandwidth: (info['bandwidth'] as int?) ?? 0,
                resolution: (info['resolution'] as String?) ?? '',
                codecs: (info['codecs'] as String?) ?? '',
              ),
            );
          }
        }
      }
    }

    return streams;
  }

  Map<String, dynamic> _parseStreamInfo(String line) {
    final result = <String, dynamic>{};

    final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
    if (bandwidthMatch != null) {
      result['bandwidth'] = int.parse(bandwidthMatch.group(1)!);
    }

    final resolutionMatch = RegExp(r'RESOLUTION=([^\s,]+)').firstMatch(line);
    if (resolutionMatch != null) {
      result['resolution'] = resolutionMatch.group(1);
    }

    final codecsMatch = RegExp('CODECS="([^"]+)"').firstMatch(line);
    if (codecsMatch != null) {
      result['codecs'] = codecsMatch.group(1);
    }

    return result;
  }
}

class M3u8StreamInfo {
  const M3u8StreamInfo({
    required this.url,
    required this.bandwidth,
    required this.resolution,
    required this.codecs,
  });
  final String url;
  final int bandwidth;
  final String resolution;
  final String codecs;

  @override
  String toString() =>
      'M3u8StreamInfo(url: $url, bandwidth: $bandwidth, resolution: $resolution)';
}
