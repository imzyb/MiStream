/// 播放地址嗅探解析：把「网页播放页」解析成可直接喂给播放内核的媒体地址。
///
/// 采集站的 `vod_play_url` 有两类线路：
///
/// - **直链线路**（名字多带 `m3u8`）：URL 本身就是 `.m3u8` / `.mp4`，可直接播。
/// - **网页线路**（如 `share/xxxx`）：URL 指向一个播放页，真实流地址藏在页面
///   的 `<video src>`、内联 JS 变量或 base64 片段里，必须先取回页面再抽取。
///
/// 这个文件负责第二类。它刻意**不依赖 WebView**：绝大多数采集站的播放页把地址
/// 明文写在首屏 HTML 里，一次 GET + 正则就够；需要执行 JS 才能拿到地址的站点
/// 交给 [WebViewSniffer]（`webview_sniffer.dart`）的平台实现，不在本文件范围。
///
/// HTTP 访问通过 [SniffFetcher] 注入，因此整个解析链路可以在没有网络的环境下
/// 用假响应完整测试。
library;

import 'dart:convert';

import 'package:media_sniffer/src/sniffer_engine.dart';
import 'package:media_sniffer/src/sniffer_result.dart';
import 'package:media_sniffer/src/webview_sniffer.dart';

/// 一次 HTTP 响应，只保留嗅探需要的三样东西。
class SniffResponse {
  /// 构造响应。
  const SniffResponse({
    required this.statusCode,
    required this.body,
    this.contentType,
    this.finalUrl,
  });

  /// HTTP 状态码。
  final int statusCode;

  /// 响应体（已解码为文本）。
  final String body;

  /// `Content-Type` 头，判断「是不是直接就是媒体流」时用。
  final String? contentType;

  /// 跟随重定向后的最终地址；`null` 表示与请求地址相同。
  final String? finalUrl;

  /// 是否 2xx。
  bool get isOk => statusCode >= 200 && statusCode < 300;
}

/// 取回一个 URL 的抽象。
///
/// 生产实现用 `dart:io` 的 `HttpClient`（见 `HttpSniffFetcher`），测试注入假实现。
typedef SniffFetcher =
    Future<SniffResponse> Function(String url, Map<String, String> headers);

/// 嗅探解析结果。
class ResolvedMedia {
  /// 构造结果。
  const ResolvedMedia({
    required this.url,
    required this.type,
    this.headers = const {},
    this.viaSniffing = false,
  });

  /// 可直接播放的地址。
  final String url;

  /// 媒体类型。
  final MediaType type;

  /// 播放时需要一并下发的请求头（至少含 UA，网页线路还会带 Referer）。
  final Map<String, String> headers;

  /// 是否经过了页面嗅探（false 表示原地址本身就是直链）。
  final bool viaSniffing;

  @override
  String toString() => 'ResolvedMedia($url, $type, viaSniffing: $viaSniffing)';
}

/// 解析失败的原因。
enum SniffFailure {
  /// 页面取不回来（网络错误 / 非 2xx）。
  pageUnavailable,

  /// 页面取回了，但里面找不到任何媒体地址。
  noMatch,

  /// 候选地址都验证不通过。
  candidatesUnplayable,
}

/// 解析结果：成功给 [media]，失败给 [failure]。
///
/// 这里不用 `core_domain` 的 `Result`，因为 `media_sniffer` 要能被
/// 纯 Dart 工具单独引用；调用方（`PlayUseCase`）负责翻译成 `AppError`。
class SniffOutcome {
  /// 成功。
  const SniffOutcome.ok(ResolvedMedia this.media)
    : failure = null,
      detail = null;

  /// 失败。
  const SniffOutcome.err(SniffFailure this.failure, {this.detail})
    : media = null;

  /// 成功时的结果。
  final ResolvedMedia? media;

  /// 失败原因。
  final SniffFailure? failure;

  /// 失败的补充说明（诊断用）。
  final String? detail;

  /// 是否成功。
  bool get isOk => media != null;
}

/// 反盗链默认 UA。
///
/// 采集站的 CDN 普遍对非浏览器 UA 直接 403，这个值是「什么都不知道时」的最优猜。
const defaultSniffUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// 把播放地址解析为可播放的媒体地址。
class SnifferResolver {
  /// 以 [fetcher] 构造。
  ///
  /// [engine] 用于从页面文本里抽取候选地址，默认用一套内置规则。
  /// [verifyCandidates] 为真时会对候选地址发一次请求确认可达；关掉可以省一次
  /// 往返，但可能把 403 的地址交给播放器。
  SnifferResolver({
    required SniffFetcher fetcher,
    SnifferEngine? engine,
    this.verifyCandidates = true,
    this.verifyDirectMedia = false,
    this.maxCandidates = 5,
  }) : _fetch = fetcher,
       _engine = engine ?? SnifferEngine();

  final SniffFetcher _fetch;
  final SnifferEngine _engine;

  /// 是否验证候选地址可达。
  final bool verifyCandidates;

  /// 是否连「本来就是直链」的地址也验证一次。
  ///
  /// 默认关闭：多数流服务器只回应播放器的 range 请求，我们的探测请求反而会被
  /// 拒，开着会把能播的源判死。调用方在「有多条线路可退」时可以打开它，用一次
  /// 往返换取「这条线是死的」这个确定信息。
  final bool verifyDirectMedia;

  /// 最多验证多少个候选地址。
  final int maxCandidates;

  /// 页面里明文写着的媒体地址。
  ///
  /// 覆盖三种常见写法：裸 URL、JS 里被转义成 `\/` 的 URL、以及
  /// `"url":"..."` 这类 JSON 字段。为避免把 `.ts` 分片当成主地址，只认
  /// `m3u8` / `mp4` / `flv`。
  ///
  /// 路径部分刻意**允许**反斜杠：JS 字面量里整条路径都写成 `a\/b\/c.m3u8`，
  /// 把 `\` 排除掉会导致只匹配到开头的 `\/\/` 就断掉。引号、空白与尖括号仍然
  /// 排除，因此不会跨越字面量边界；反斜杠在 [_normalizeUrl] 里统一还原。
  static final _mediaUrlPattern = RegExp(
    r'''https?:(?:\\?/){2}[^\s"'<>]+?\.(?:m3u8|mp4|flv)(?:\?[^\s"'<>]*)?''',
    caseSensitive: false,
  );

  /// 相对路径写法的媒体地址，如 `/20230125/xxx/index.m3u8`。
  static final _relativeMediaPattern = RegExp(
    r'''["'(](/[^\s"'<>()]+?\.(?:m3u8|mp4|flv)(?:\?[^\s"'<>()]*)?)["')]''',
    caseSensitive: false,
  );

  /// 解析 [url]。
  ///
  /// [referer] 是取页面与后续播放都要带的来源页，一般传站点 API 的域名根。
  /// [extraHeaders] 会合并进请求与结果（同名以 [extraHeaders] 为准）。
  Future<SniffOutcome> resolve(
    String url, {
    String? referer,
    Map<String, String> extraHeaders = const {},
  }) async {
    final headers = <String, String>{
      'User-Agent': defaultSniffUserAgent,
      if (referer case final String r) 'Referer': r,
      ...extraHeaders,
    };

    // 直链快路径：地址后缀就是媒体格式时不必取页面。
    if (looksLikeDirectMedia(url)) {
      if (!verifyDirectMedia) {
        return SniffOutcome.ok(
          ResolvedMedia(
            url: url,
            type: MediaType.fromUrl(url),
            headers: headers,
          ),
        );
      }
      final probe = await _safeFetch(url, headers);
      if (probe == null || !probe.isOk) {
        return SniffOutcome.err(
          SniffFailure.pageUnavailable,
          detail: probe == null ? '请求失败' : 'HTTP ${probe.statusCode}',
        );
      }
      return SniffOutcome.ok(
        ResolvedMedia(
          url: probe.finalUrl ?? url,
          type: _typeFromResponse(probe, fallbackUrl: url),
          headers: headers,
        ),
      );
    }

    final page = await _safeFetch(url, headers);
    if (page == null || !page.isOk) {
      return SniffOutcome.err(
        SniffFailure.pageUnavailable,
        detail: page == null ? '请求失败' : 'HTTP ${page.statusCode}',
      );
    }

    // 有些「网页线路」其实直接返回了 m3u8 正文（Content-Type 不一定对），
    // 这种情况地址本身就能播，不用再找候选。
    if (_isPlaylistBody(page.body) || _isMediaContentType(page.contentType)) {
      return SniffOutcome.ok(
        ResolvedMedia(
          url: page.finalUrl ?? url,
          type: _typeFromResponse(page, fallbackUrl: url),
          headers: headers,
        ),
      );
    }

    final baseUrl = page.finalUrl ?? url;
    final candidates = extractCandidates(page.body, baseUrl: baseUrl);
    if (candidates.isEmpty) {
      return const SniffOutcome.err(SniffFailure.noMatch);
    }

    if (!verifyCandidates) {
      final first = candidates.first;
      return SniffOutcome.ok(
        ResolvedMedia(
          url: first,
          type: MediaType.fromUrl(first),
          headers: {...headers, 'Referer': baseUrl},
          viaSniffing: true,
        ),
      );
    }

    // 带上页面自身作为 Referer 去验证：网页线路的流地址几乎都按播放页鉴权。
    final playHeaders = {...headers, 'Referer': baseUrl};
    for (final candidate in candidates.take(maxCandidates)) {
      final probe = await _safeFetch(candidate, playHeaders);
      if (probe != null && probe.isOk) {
        return SniffOutcome.ok(
          ResolvedMedia(
            url: probe.finalUrl ?? candidate,
            type: _typeFromResponse(probe, fallbackUrl: candidate),
            headers: playHeaders,
            viaSniffing: true,
          ),
        );
      }
    }

    return SniffOutcome.err(
      SniffFailure.candidatesUnplayable,
      detail: '${candidates.length} 个候选地址均不可达',
    );
  }

  /// 从页面文本里抽取媒体地址候选，按「更可能是主地址」排序。
  ///
  /// 顺序上 HLS 优先于 MP4：采集站的 m3u8 才是能拖进度的完整片源，页面里出现
  /// 的 mp4 常常是预告片或广告。
  List<String> extractCandidates(String body, {String? baseUrl}) {
    final base = baseUrl == null ? null : Uri.tryParse(baseUrl);
    final seen = <String>{};
    final out = <String>[];

    void add(String raw) {
      final normalized = _normalizeUrl(raw, base);
      if (normalized == null) return;
      if (seen.add(normalized)) out.add(normalized);
    }

    for (final m in _mediaUrlPattern.allMatches(body)) {
      add(m.group(0)!);
    }
    for (final m in _relativeMediaPattern.allMatches(body)) {
      add(m.group(1)!);
    }
    // base64 内联：部分播放页把地址塞进 `"url":"aHR0cHM6..."`。
    for (final decoded in _decodeBase64Blobs(body)) {
      for (final m in _mediaUrlPattern.allMatches(decoded)) {
        add(m.group(0)!);
      }
    }
    // 兜底走通用嗅探引擎（`<video src>`、`file: "..."` 等写法）。
    for (final r in _engine.sniffHtml(body)) {
      add(r.url);
    }

    out.sort((a, b) {
      final rank = _candidateRank(a).compareTo(_candidateRank(b));
      return rank;
    });
    return out;
  }

  static int _candidateRank(String url) {
    switch (MediaType.fromUrl(url)) {
      case MediaType.hls:
        return 0;
      case MediaType.mp4:
        return 1;
      case MediaType.flv:
        return 2;
      case MediaType.mp3:
        return 3;
      case MediaType.other:
        return 4;
    }
  }

  /// URL 后缀是否直接就是媒体格式。
  static bool looksLikeDirectMedia(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.m3u8') ||
        path.endsWith('.mp4') ||
        path.endsWith('.flv') ||
        path.endsWith('.mkv') ||
        path.endsWith('.mp3');
  }

  Future<SniffResponse?> _safeFetch(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      return await _fetch(url, headers);
    } on Object {
      return null;
    }
  }

  static bool _isPlaylistBody(String body) =>
      body.trimLeft().startsWith('#EXTM3U');

  static bool _isMediaContentType(String? contentType) {
    if (contentType == null) return false;
    final t = contentType.toLowerCase();
    return t.contains('mpegurl') ||
        t.contains('video/') ||
        t.contains('application/octet-stream');
  }

  static MediaType _typeFromResponse(
    SniffResponse resp, {
    required String fallbackUrl,
  }) {
    if (_isPlaylistBody(resp.body)) return MediaType.hls;
    final ct = resp.contentType;
    if (ct != null) {
      final byMime = MediaType.fromMime(ct);
      if (byMime != MediaType.other) return byMime;
    }
    return MediaType.fromUrl(resp.finalUrl ?? fallbackUrl);
  }

  /// 把 JS 转义、协议相对、相对路径统一成绝对 URL；不合法返回 `null`。
  static String? _normalizeUrl(String raw, Uri? base) {
    var s = raw.trim().replaceAll(r'\/', '/').replaceAll('&amp;', '&');
    if (s.isEmpty) return null;
    if (s.startsWith('//')) {
      s = '${base?.scheme ?? 'https'}:$s';
    }
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return Uri.tryParse(s)?.toString();
    }
    if (base == null) return null;
    return base.resolve(s).toString();
  }

  /// 抽出页面里长度足够的 base64 片段并尝试解码。
  ///
  /// 只看 60 字符以上的块：更短的多是 CSS 里的小图或哈希，解出来全是噪声。
  static Iterable<String> _decodeBase64Blobs(String body) {
    final blobs = RegExp('[A-Za-z0-9+/=]{60,}').allMatches(body);
    return blobs
        .map((m) {
          try {
            final bytes = base64.decode(m.group(0)!);
            return utf8.decode(bytes, allowMalformed: true);
          } on Object {
            return '';
          }
        })
        .where((s) => s.contains('http'));
  }
}
