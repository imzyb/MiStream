class SnifferRule {
  const SnifferRule({
    required this.name,
    required this.urlPattern,
    this.contentPattern,
    this.headers = const {},
    this.enabled = true,
    this.priority = 100,
  });

  factory SnifferRule.fromJson(Map<String, dynamic> json) {
    return SnifferRule(
      name: json['name'] as String? ?? '',
      urlPattern: json['urlPattern'] as String? ?? '',
      contentPattern: json['contentPattern'] as String?,
      headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 100,
    );
  }
  final String name;
  final String urlPattern;
  final String? contentPattern;
  final Map<String, String> headers;
  final bool enabled;
  final int priority;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'urlPattern': urlPattern,
      if (contentPattern != null) 'contentPattern': contentPattern,
      if (headers.isNotEmpty) 'headers': headers,
      'enabled': enabled,
      'priority': priority,
    };
  }

  bool matchesUrl(String url) {
    if (!enabled) return false;
    try {
      final regex = RegExp(urlPattern);
      return regex.hasMatch(url);
    } catch (_) {
      return false;
    }
  }

  bool matchesContent(String content) {
    if (contentPattern == null) return true;
    try {
      final regex = RegExp(contentPattern!);
      return regex.hasMatch(content);
    } catch (_) {
      return false;
    }
  }

  static const List<SnifferRule> defaults = [
    SnifferRule(name: 'HLS', urlPattern: r'\.m3u8(\?.*)?$', priority: 10),
    SnifferRule(name: 'MP4', urlPattern: r'\.mp4(\?.*)?$', priority: 20),
    SnifferRule(name: 'FLV', urlPattern: r'\.flv(\?.*)?$', priority: 30),
    SnifferRule(name: 'M3U', urlPattern: r'\.m3u(\?.*)?$', priority: 40),
    SnifferRule(name: 'TS', urlPattern: r'\.ts(\?.*)?$', priority: 50),
    SnifferRule(name: 'MKV', urlPattern: r'\.mkv(\?.*)?$', priority: 60),
    SnifferRule(name: 'AVI', urlPattern: r'\.avi(\?.*)?$', priority: 70),
    SnifferRule(
      name: 'M3U8 Playlist',
      urlPattern: r'playlist\.m3u8',
      contentPattern: '#EXTM3U',
      priority: 5,
    ),
    SnifferRule(
      name: 'API Video URL',
      urlPattern: '/api/.*video',
      priority: 80,
    ),
  ];
}
