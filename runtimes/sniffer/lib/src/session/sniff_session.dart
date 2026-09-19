/// 嗅探会话：驱动内核加载页面、监听网络、命中媒体流。
///
/// 整个流程对应 ADR-005 与 `docs/05-Spider引擎.md` §6：
///
/// ```text
/// 启动内核 → 连 CDP → Network/Page.enable → Page.navigate
///   → 监听 Network.responseReceived / requestWillBeSent
///   → 按扩展名 / Content-Type / 配置规则匹配
///   → 命中即返回 URL + 该请求的完整 header
///   → 超时或加载完成仍无命中 → 失败
/// ```
///
/// 这一层刻意不碰进程与传输：内核由 [SnifferKernelProcess] 给，CDP 由
/// [CdpClient] 给。这样嗅探**策略**（什么算命中、何时放弃）可以脱离浏览器
/// 与网络被完整测试——上一版把所有东西揉进一个类，结果一个方法都没写完。
library;

import 'dart:async';

import 'package:media_sniffer/media_sniffer.dart';
import 'package:sniffer/src/cdp/cdp_client.dart';
import 'package:sniffer/src/kernel/kernel_process.dart';

/// 嗅探失败的原因，对应 `docs/08-RPC协议.md` §7.5 的错误码。
///
/// **为什么不复用 `media_sniffer` 的 `CdpSniffFailure`**：那个枚举描述的是
/// 「HTTP 抓取」阶段的失败（`pageUnavailable` / `noMatch` /
/// `candidatesUnplayable`），而 RPC §7.5 规定的是**嗅探层**要上报给 UI 的
/// 四类结果，包含「组件缺失」和「超时」这两个 HTTP 路径上不存在的状态。
/// 两套枚举服务于不同层面，强行合并会让 `SNIFFER_UNAVAILABLE` 无处安放。
///
/// 因此这里刻意用 `Cdp` 前缀区分，避免与 `media_sniffer` 的同名概念混淆。
enum CdpSniffFailure {
  /// 嗅探组件缺失（`-32300`）。
  unavailable('SNIFFER_UNAVAILABLE', -32300),

  /// 超时未命中（`-32301`）。
  timeout('SNIFF_TIMEOUT', -32301),

  /// 页面加载完成但无媒体流（`-32302`）。
  noMatch('SNIFF_NO_MATCH', -32302),

  /// 页面加载失败（`-32303`）。
  pageError('SNIFF_PAGE_ERROR', -32303);

  const CdpSniffFailure(this.constant, this.code);

  /// 错误码常量名。
  final String constant;

  /// RPC 错误码。
  final int code;
}

/// 一次 CDP 嗅探的结果。
class CdpSniffOutcome {
  /// 构造结果。
  const CdpSniffOutcome._({
    required this.media,
    required this.failure,
    required this.detail,
    this.kernelLabel,
  });

  /// 命中。
  factory CdpSniffOutcome.hit(SnifferResult media, {String? kernelLabel}) =>
      CdpSniffOutcome._(
        media: media,
        failure: null,
        detail: null,
        kernelLabel: kernelLabel,
      );

  /// 未命中。
  factory CdpSniffOutcome.miss(CdpSniffFailure failure, String detail) =>
      CdpSniffOutcome._(media: null, failure: failure, detail: detail);

  /// 命中的媒体，未命中为 null。
  final SnifferResult? media;

  /// 失败原因，命中为 null。
  final CdpSniffFailure? failure;

  /// 人类可读的补充说明。
  final String? detail;

  /// 使用的内核展示名。
  final String? kernelLabel;

  /// 是否命中。
  bool get isHit => media != null;

  /// 命中地址，未命中为 null。
  String? get url => media?.url;

  @override
  String toString() => isHit
      ? 'CdpSniffOutcome.hit(${media!.url})'
      : 'CdpSniffOutcome.miss(${failure!.constant}: $detail)';
}

/// 嗅探会话。
class SniffSession {
  /// 构造会话。
  ///
  /// [detector] 与 [rules] 复用 `media_sniffer` 的实现，而不是在这里重写
  /// 一套匹配逻辑——嗅探的**判定标准**只有一份，WebView 版与 CDP 版必须一致，
  /// 否则同一个源在不同嗅探路径下结果会不同。
  SniffSession({
    MediaDetector? detector,
    List<SnifferRule>? rules,
    this.totalTimeout = const Duration(seconds: 20),
  }) : _detector = detector ?? MediaDetector(),
       _rules = rules ?? List.of(SnifferRule.defaults);

  /// 总超时。ADR-005 规定默认 20s。
  final Duration totalTimeout;

  final MediaDetector _detector;
  final List<SnifferRule> _rules;

  /// 在 [client] 上嗅探 [url]。
  ///
  /// [client] 必须是已连接的浏览器级 CDP 客户端。
  Future<CdpSniffOutcome> sniff(
    CdpClient client,
    String url, {
    Map<String, String>? headers,
    String? kernelLabel,
  }) async {
    final hits = <SnifferResult>[];
    final hitSignal = Completer<SnifferResult>();

    // 先起监听再导航。CDP 事件只推一次，反过来的话首个请求必然漏掉。
    final sub = client.events.listen((event) {
      final hit = _matchEvent(event);
      if (hit == null) return;
      hits.add(hit);
      if (!hitSignal.isCompleted) hitSignal.complete(hit);
    });

    var loadFinished = false;
    final loadSignal = Completer<void>();
    final loadSub = client.events.listen((event) {
      if (event.method == 'Page.loadEventFired' && !loadSignal.isCompleted) {
        loadFinished = true;
        loadSignal.complete();
      }
    });
    try {
      await client.send('Network.enable');
      await client.send('Page.enable');

      if (headers != null && headers.isNotEmpty) {
        await client.send(
          'Network.setExtraHTTPHeaders',
          params: {'headers': headers},
        );
      }

      final nav = await client.send('Page.navigate', params: {'url': url});
      final navError = nav['errorText'];
      if (navError is String && navError.isNotEmpty) {
        return CdpSniffOutcome.miss(
          CdpSniffFailure.pageError,
          '页面加载失败: $navError',
        );
      }

      // 命中优先于一切：ADR-005 说嗅探是最后手段，一旦拿到地址就该尽快返回，
      // 没必要等整页加载完。
      final winner =
          await Future.any<SnifferResult?>([
            hitSignal.future,
            // 兜底：加载完成后再给一小段缓冲，等 XHR/fetch 触发的媒体请求。
            loadSignal.future
                .then((_) => Future<void>.delayed(const Duration(seconds: 2)))
                .then((_) => hits.isEmpty ? null : hits.first),
          ]).timeout(
            totalTimeout,
            onTimeout: () => null,
          );

      if (winner != null) {
        return CdpSniffOutcome.hit(winner, kernelLabel: kernelLabel);
      }

      // 事件流没命中、页面也已经加载完，最后取一次 DOM 兜底。
      // 覆盖「媒体地址静态写在 <video src> 里、且该请求没触发 responseReceived」
      // 的情况（例如走 blob: 或由脚本 setAttribute 注入）。
      if (loadFinished) {
        final fromHtml = await _detectInPage(client);
        if (fromHtml != null) {
          return CdpSniffOutcome.hit(fromHtml, kernelLabel: kernelLabel);
        }
        return CdpSniffOutcome.miss(
          CdpSniffFailure.noMatch,
          '页面加载完成但未发现媒体流',
        );
      }

      return CdpSniffOutcome.miss(
        CdpSniffFailure.timeout,
        '等待 ${totalTimeout.inSeconds}s 未命中',
      );
    } on CdpTimeoutException catch (e) {
      return CdpSniffOutcome.miss(CdpSniffFailure.timeout, e.toString());
    } on KernelLaunchException catch (e) {
      return CdpSniffOutcome.miss(CdpSniffFailure.unavailable, e.toString());
    } on Object catch (e) {
      return CdpSniffOutcome.miss(CdpSniffFailure.pageError, e.toString());
    } finally {
      await sub.cancel();
      await loadSub.cancel();
    }
  }

  /// 取当前页面的 HTML 并做静态提取。
  ///
  /// 取 DOM 而不是 `Page.getResourceContent`：前者拿的是**脚本执行后**的
  /// 结果，正是我们需要的那份；后者拿的是原始响应体，对 SPA 没用。
  Future<SnifferResult?> _detectInPage(CdpClient client) async {
    try {
      final result = await client.send(
        'Runtime.evaluate',
        params: {
          'expression': 'document.documentElement.outerHTML',
          'returnByValue': true,
        },
      );
      final value = (result['result'] as Map<String, Object?>?)?['value'];
      if (value is! String || value.isEmpty) return null;
      return detectInHtml(value);
    } on Object {
      // 兜底手段失败不该改变结论：返回 null 让调用方报「无命中」。
      return null;
    }
  }

  /// 判定一个 CDP 事件是否命中媒体流，命中则构造结果。
  ///
  /// 只看两个事件：
  /// - `Network.responseReceived` 拿得到 Content-Type，判定最准
  /// - `Network.requestWillBeSent` 抓那些不给 Content-Type 或只经 XHR 的请求
  SnifferResult? _matchEvent(CdpEvent event) {
    switch (event.method) {
      case 'Network.responseReceived':
        final resp = event.params['response'];
        if (resp is! Map<String, Object?>) return null;
        final url = resp['url']?.toString();
        if (url == null || url.isEmpty) return null;

        final mime = resp['mimeType']?.toString() ?? '';
        if (!_isMediaMime(mime) && !_isMediaUrl(url)) return null;
        if (_isExcluded(url)) return null;

        return SnifferResult(
          url: url,
          // Content-Type 比扩展名可靠（很多流地址没有扩展名），优先用它。
          type: _isMediaMime(mime)
              ? MediaType.fromMime(mime)
              : MediaType.fromUrl(url),
          headers: _headersOf(resp['headers']),
        );

      case 'Network.requestWillBeSent':
        final req = event.params['request'];
        if (req is! Map<String, Object?>) return null;
        final url = req['url']?.toString();
        if (url == null || url.isEmpty) return null;
        if (!_isMediaUrl(url)) return null;
        if (_isExcluded(url)) return null;

        return SnifferResult(
          url: url,
          type: MediaType.fromUrl(url),
          headers: _headersOf(req['headers']),
        );

      default:
        return null;
    }
  }

  bool _isMediaMime(String mime) {
    final lower = mime.toLowerCase();
    return lower.startsWith('video/') ||
        lower.startsWith('audio/') ||
        lower.contains('mpegurl') ||
        lower.contains('vnd.apple.mpegurl') ||
        lower.contains('dash+xml') ||
        lower.contains('x-flv') ||
        lower.contains('octet-stream');
  }

  bool _isMediaUrl(String url) {
    final lower = url.toLowerCase();
    // `.ts` 单独判：分片地址很常见，但也是很多静态资源的扩展名，
    // 所以只在 URL 路径末段匹配，避免把 `foo.ts` 类型的脚本误判。
    if (lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('.flv') ||
        lower.contains('.mkv') ||
        lower.contains('.avi') ||
        lower.contains('.m3u')) {
      return true;
    }
    return _rules.any((r) => r.enabled && _safeMatches(r, url));
  }

  /// 页面里静态写死的媒体地址（`<video src>`、`<source>` 等）。
  ///
  /// 走 CDP 的场景通常是「地址藏在 JS 执行后的请求里」，但页面同时有静态
  /// 标签也很常见。复用 [MediaDetector] 而不是在事件流里再写一遍正则——
  /// 静态页的判定标准与 `media_sniffer` 必须完全一致，否则同一个页面走
  /// HTTP 路径和走 CDP 路径会得出不同结果。
  ///
  /// 结果只用于**页面加载完成后**的兜底，不抢在事件流前面返回：网络事件
  /// 带 Content-Type 与真实 header，比 HTML 里的字符串可靠。
  SnifferResult? detectInHtml(String html, {String? referer}) {
    final found = _detector.detectFromHtml(html, referer: referer);
    for (final item in found) {
      if (!_isExcluded(item.url)) return item;
    }
    return null;
  }

  bool _safeMatches(SnifferRule rule, String url) {
    try {
      return RegExp(rule.urlPattern).hasMatch(url);
    } on FormatException {
      return false;
    }
  }

  /// 通用广告/统计排除。
  ///
  /// 与 `docs/05-Spider引擎.md` §6 要求的「内置通用广告过滤名单」对应。
  /// 只挡明确无关的，宁可漏挡也不要误杀播放地址——误杀会让用户看到
  /// 「嗅探到了但播不了」，比没嗅到更难排查。
  bool _isExcluded(String url) {
    final lower = url.toLowerCase();
    const blocked = <String>[
      'google-analytics.com',
      'googletagmanager.com',
      'doubleclick.net',
      'googlesyndication.com',
      'cnzz.com',
      'baidu.com/hm.js',
      '/ad.js',
      '/ads/',
      'analytics',
      'beacon',
    ];
    return blocked.any(lower.contains);
  }

  Map<String, String> _headersOf(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (k is String && v != null) out[k] = v.toString();
    });
    return out;
  }
}
