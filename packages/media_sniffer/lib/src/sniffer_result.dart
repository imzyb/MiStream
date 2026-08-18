class SnifferResult {
  final String url;
  final MediaType type;
  final Map<String, String> headers;
  final String? title;
  final int? duration;
  final String? referer;

  const SnifferResult({
    required this.url,
    required this.type,
    this.headers = const {},
    this.title,
    this.duration,
    this.referer,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnifferResult &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          type == other.type;

  @override
  int get hashCode => url.hashCode ^ type.hashCode;

  @override
  String toString() => 'SnifferResult(url: $url, type: $type)';
}

enum MediaType {
  hls('m3u8'),
  mp4('mp4'),
  mp3('mp3'),
  flv('flv'),
  other('other');

  const MediaType(this.extension);
  final String extension;

  static MediaType fromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('m3u8')) return MediaType.hls;
    if (lower.contains('.mp4') || lower.contains('mp4')) return MediaType.mp4;
    if (lower.contains('.mp3') || lower.contains('mp3')) return MediaType.mp3;
    if (lower.contains('.flv') || lower.contains('flv')) return MediaType.flv;
    return MediaType.other;
  }

  static MediaType fromMime(String mime) {
    final lower = mime.toLowerCase();
    if (lower.contains('mpegurl') || lower.contains('x-mpegurl'))
      return MediaType.hls;
    if (lower.contains('video/mp4')) return MediaType.mp4;
    if (lower.contains('audio/mpeg')) return MediaType.mp3;
    if (lower.contains('video/x-flv')) return MediaType.flv;
    return MediaType.other;
  }
}
