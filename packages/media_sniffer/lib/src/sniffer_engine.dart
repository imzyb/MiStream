import 'package:media_sniffer/src/media_detector.dart';
import 'package:media_sniffer/src/sniffer_result.dart';
import 'package:media_sniffer/src/sniffer_rule.dart';

class SnifferEngine {
  SnifferEngine({
    MediaDetector? detector,
    List<SnifferRule>? rules,
  }) : _detector = detector ?? MediaDetector(),
       _rules = rules ?? List.of(SnifferRule.defaults);
  final MediaDetector _detector;
  final List<SnifferRule> _rules;

  List<SnifferRule> get rules => List.unmodifiable(_rules);

  void addRule(SnifferRule rule) {
    _rules.add(rule);
    _rules.sort((a, b) => a.priority.compareTo(b.priority));
  }

  void removeRule(String name) {
    _rules.removeWhere((r) => r.name == name);
  }

  void resetRules() {
    _rules
      ..clear()
      ..addAll(SnifferRule.defaults);
  }

  List<SnifferResult> sniffHtml(String html, {String? referer}) {
    final results = <SnifferResult>[];
    final seen = <String>{};

    final detected = _detector.detectFromHtml(html, referer: referer);
    for (final item in detected) {
      if (!seen.contains(item.url)) {
        seen.add(item.url);
        results.add(item);
      }
    }

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      for (final match in RegExp(rule.urlPattern).allMatches(html)) {
        final url = match.group(0);
        if (url != null && !seen.contains(url) && rule.matchesContent(html)) {
          seen.add(url);
          results.add(
            SnifferResult(
              url: url,
              type: MediaType.fromUrl(url),
              headers: rule.headers,
              referer: referer,
            ),
          );
        }
      }
    }

    return results;
  }

  List<SnifferResult> sniffJs(String js, {String? referer}) {
    final results = <SnifferResult>[];
    final seen = <String>{};

    final detected = _detector.detectFromJs(js, referer: referer);
    for (final item in detected) {
      if (!seen.contains(item.url)) {
        seen.add(item.url);
        results.add(item);
      }
    }

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      for (final match in RegExp(rule.urlPattern).allMatches(js)) {
        final url = match.group(0);
        if (url != null && !seen.contains(url)) {
          seen.add(url);
          results.add(
            SnifferResult(
              url: url,
              type: MediaType.fromUrl(url),
              headers: rule.headers,
              referer: referer,
            ),
          );
        }
      }
    }

    return results;
  }

  M3u8ParseResult parseM3u8(String content, {String? baseUrl}) {
    if (_detector.isMasterPlaylist(content)) {
      final streams = _detector.parseMasterPlaylist(content);
      return M3u8ParseResult(
        isMaster: true,
        streams: streams,
      );
    } else {
      final segments = _detector.parseM3u8(content, baseUrl: baseUrl);
      return M3u8ParseResult(
        isMaster: false,
        segments: segments,
      );
    }
  }
}

class M3u8ParseResult {
  const M3u8ParseResult({
    required this.isMaster,
    this.streams = const [],
    this.segments = const [],
  });
  final bool isMaster;
  final List<M3u8StreamInfo> streams;
  final List<String> segments;

  M3u8StreamInfo? get bestStream {
    if (streams.isEmpty) return null;
    return streams.reduce((a, b) => a.bandwidth > b.bandwidth ? a : b);
  }

  M3u8StreamInfo? get worstStream {
    if (streams.isEmpty) return null;
    return streams.reduce((a, b) => a.bandwidth < b.bandwidth ? a : b);
  }
}
