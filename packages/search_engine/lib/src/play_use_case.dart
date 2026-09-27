/// 播放编排：根据 flag 获取真实播放地址并返回可播放的 MediaSource。
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:media_sniffer/media_sniffer.dart';
import 'package:player_engine/player_engine.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';

/// 反盗链默认 UA：大量源站对非浏览器 UA 直接返回 403。
const _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// 播放结果。
class PlayResult {
  const PlayResult({
    required this.mediaSource,
    this.title,
    this.coverUrl,
    this.viaSniffing = false,
  });
  final MediaSource mediaSource;
  final String? title;
  final String? coverUrl;

  /// 该地址是否经由页面嗅探得到（诊断用）。
  final bool viaSniffing;
}

/// 浏览器嗅探回调：给定播放页地址与请求头，返回真实流地址（没嗅到返回 null）。
///
/// 刻意用函数类型而不是 `play_engine` 的 `SnifferLauncher`：那个类型要求
/// `search_engine` 反向依赖 `play_engine`，而本包只需要「调一次拿个地址」。
/// 适配层放在装配处（`app_assembly.dart`）更合适 —— 依赖方向也保持单向。
typedef BrowserSniffCallback =
    Future<String?> Function(String url, Map<String, String> headers);

/// 播放编排器。
///
/// 职责：根据 siteId + vodId + flag 调用 Apple CMS v2 detail API，
/// 解析 `vod_play_from` / `vod_play_url` 字段，必要时经嗅探器把「网页播放页」
/// 解析成真实流地址，最后构造 MediaSource 返回。
///
/// Apple CMS v2 播放地址格式：
/// - `vod_play_from`: "线路1$$$线路2$$$线路3"（$$$ 分隔多线路）
/// - `vod_play_url`: "第1集$url1#第2集$url2$$$第1集$url3#第2集$url4"
///   （$$$ 分隔线路，# 分隔剧集，$ 分隔名称与 URL）
///
/// ## 为什么需要嗅探
///
/// 同一部片通常有两类线路：名字带 `m3u8` 的返回可直接播的流地址，名字形如
/// `share/xxxx` 的返回一个**网页播放页**——直接把后者喂给 mpv 只会得到
/// 「打开媒体失败」。[resolver] 负责把后者解析成真实地址；不注入 resolver 时
/// 退化为原来的行为（原地址直接返回），既保持向后兼容，也让单测不必联网。
///
/// ## 两级嗅探
///
/// [resolver] 是「抓 HTML + 正则抽地址」，便宜但只能看到静态标记；
/// [browserSniffer] 是「开真实浏览器跑一遍页面 JS」，贵但能看到脚本执行后
/// 才出现的地址。**只有前者失败时才调后者**——绝大多数网页线路在静态 HTML
/// 里就有地址，没必要为每一部片起一个浏览器进程。
class PlayUseCase {
  /// 构造播放编排器。
  PlayUseCase(
    this.sites, {
    this.runtimeFactory,
    this.resolver,
    this.browserSniffer,
  });
  final SiteRepository sites;
  final SpiderRuntimeFactory? runtimeFactory;

  /// 嗅探解析器；`null` 表示不做嗅探，原地址直接返回。
  final SnifferResolver? resolver;

  /// 静态嗅探失败后的浏览器兜底；`null` 表示不做这一步。
  ///
  /// 需要本机装有 Edge/Chrome，且 CDP 嗅探运行时可用（见 `runtimes/sniffer`）。
  final BrowserSniffCallback? browserSniffer;

  /// 获取可播放的媒体源。
  ///
  /// [siteId] 站点 ID
  /// [vodId] 影片 ID
  /// [flag] 播放源标识（如"量子"、"无尽"，对应 `vod_play_from` 中的线路名）
  /// [episodeId] 剧集索引（0-based，对应 `vod_play_url` 中的剧集位置）
  Future<Result<PlayResult, AppError>> getPlayableSource({
    required int siteId,
    required String vodId,
    required String flag,
    String? episodeId,
  }) async {
    // 1. 查站点拿 API
    final site = await sites.byId(siteId);
    if (site == null) {
      return const Err(
        LocalError(
          code: ErrorCode.invalidArgument,
          message: '站点不存在',
        ),
      );
    }

    // 2. 根据站点类型创建运行时，取详情。
    //
    // 取完**立刻**回收，且成功/失败/抛异常三条路径都要走到。type=3 的 runtime
    // 背后是一个常驻子进程（JS 或 JVM），漏一次回收就多留一个进程：连播多集会
    // 持续堆积，离开播放页也不会释放。detail 返回的是字符串 body，回收之后仍能
    // 继续用于下面的候选提取，所以「取完即回收」是安全的，不必挂到方法末尾。
    final runtime = await _createRuntime(site);
    final detailResult = await _detailAndDispose(runtime, vodId);
    if (detailResult.isErr) {
      return Err(detailResult.errorOrNull!);
    }

    // 3. 从详情里列出本集在**所有线路**上的地址，按优先级排序。
    final extracted = _extractCandidates(
      body: detailResult.valueOrNull!.body,
      flag: flag,
      episodeId: episodeId,
    );
    if (extracted.isErr) {
      return Err(extracted.errorOrNull!);
    }
    final candidates = extracted.valueOrNull!;

    // 4. 站点域名作为默认 Referer：源站的反盗链多数只看域，不看具体路径。
    final apiUri = Uri.tryParse(site.api);
    final siteReferer = apiUri != null && apiUri.hasAuthority
        ? '${apiUri.scheme}://${apiUri.authority}/'
        : null;

    final sniffer = resolver;
    if (sniffer == null && browserSniffer == null) {
      // 两级嗅探都没装：保持旧行为，原地址直接交给播放器。
      return Ok(_plainResult(candidates.first.url, siteReferer));
    }

    // 5. 逐条线路尝试：网页线路要嗅探出真实流地址，直链线路走快路径。
    //
    // 一部片通常有多条线路，其中一条挂掉是常态。挨个试到第一条能用的为止，
    // 比让用户自己在详情页反复切线路合理。
    AppError? lastError;
    for (final candidate in candidates) {
      final outcome = await sniffer?.resolve(
        candidate.url,
        referer: siteReferer,
      );
      if (outcome != null && outcome.isOk) {
        final media = outcome.media!;
        return Ok(
          PlayResult(
            mediaSource: MediaSource(
              uri: Uri.parse(media.url),
              headers: media.headers,
            ),
            viaSniffing: media.viaSniffing,
          ),
        );
      }
      // 没有静态嗅探器时，把「没解析出来」记成 noMatch，好让下面的浏览器
      // 兜底仍然跑得起来——不能因为少装了一级就让整条回退链断掉。
      lastError = outcome == null
          ? const LocalError(
              code: ErrorCode.sniffNoMatch,
              message: '静态嗅探未启用',
            )
          : _snifferError(outcome, candidate.url);

      // 5b. 静态 HTML 里没找到地址 —— 多半是地址由页面 JS 运行时拼出来的。
      // 这时才起浏览器（贵，所以不做预判性调用），命中即返回。
      final browser = browserSniffer;
      if (browser != null) {
        final headers = <String, String>{
          'User-Agent': _defaultUserAgent,
          'Referer': ?siteReferer,
        };
        final hit = await browser(candidate.url, headers);
        if (hit != null && hit.isNotEmpty) {
          return Ok(
            PlayResult(
              mediaSource: MediaSource(
                uri: Uri.parse(hit),
                headers: {...headers, 'Referer': candidate.url},
              ),
              viaSniffing: true,
            ),
          );
        }
      }
    }

    // 全部线路都没解析成功。若其中有直链形态的地址，仍交给播放器碰运气——
    // 不少流服务器只回应播放器的 range 请求，我们的探测请求反而会被拒。
    final directFallback = candidates
        .where((c) => SnifferResolver.looksLikeDirectMedia(c.url))
        .firstOrNull;
    if (directFallback != null) {
      return Ok(_plainResult(directFallback.url, siteReferer));
    }

    return Err(
      lastError ??
          const LocalError(
            code: ErrorCode.playerNoPlayableSource,
            message: '没有可播放的线路',
          ),
    );
  }

  /// 取详情，并在**任何情况下**回收运行时。
  ///
  /// 与 `DetailUseCase.load`、`HomeUseCase._trySites` 保持同一套回收纪律：
  /// 成功、业务失败、抛异常三条路径都必须 dispose。回收本身失败只吞掉异常，
  /// 不掩盖业务结果。
  static Future<Result<HttpResponseData, AppError>> _detailAndDispose(
    SpiderRuntime runtime,
    String vodId,
  ) async {
    try {
      return await runtime.detail(ids: vodId);
    } finally {
      try {
        await runtime.dispose();
      } on Object {
        // 回收失败不掩盖业务结果。
      }
    }
  }

  /// 不经嗅探、直接把原地址包成 [PlayResult]。
  PlayResult _plainResult(String url, String? referer) => PlayResult(
    mediaSource: MediaSource(
      uri: Uri.parse(url),
      headers: {
        'User-Agent': _defaultUserAgent,
        'Referer': ?referer,
      },
    ),
  );

  /// 把嗅探失败翻译成领域错误。
  static AppError _snifferError(SniffOutcome outcome, String rawUrl) {
    final detail = outcome.detail;
    return switch (outcome.failure) {
      SniffFailure.pageUnavailable => RemoteError(
        code: ErrorCode.sniffPageError,
        message: '播放页无法访问${detail == null ? '' : '（$detail）'}',
        detail: {'url': rawUrl},
      ),
      SniffFailure.noMatch => LocalError(
        code: ErrorCode.sniffNoMatch,
        message: '播放页里没有找到可播放的地址',
        detail: {'url': rawUrl},
      ),
      SniffFailure.candidatesUnplayable => RemoteError(
        code: ErrorCode.playerNoPlayableSource,
        message: '嗅探到的地址都无法播放${detail == null ? '' : '（$detail）'}',
        detail: {'url': rawUrl},
      ),
      null => LocalError(
        code: ErrorCode.sniffNoMatch,
        message: '嗅探失败',
        detail: {'url': rawUrl},
      ),
    };
  }

  /// 本集在某条线路上的候选地址。
  Result<List<_Candidate>, AppError> _extractCandidates({
    required String body,
    required String flag,
    required String? episodeId,
  }) {
    try {
      final json = jsonDecode(body) as Map<String, Object?>;
      final list = json['list'] as List?;
      if (list == null || list.isEmpty) {
        return const Err(
          LocalError(
            code: ErrorCode.spiderParseFailed,
            message: '详情数据为空',
          ),
        );
      }

      final detail = list.first is Map<String, Object?>
          ? list.first as Map<String, Object?>
          : Map<String, Object?>.from(list.first as Map);

      // 线路名与线路地址一一对应，都以 $$$ 分隔。
      final flags = ((detail['vod_play_from'] as String?) ?? '').split(r'$$$');
      final flagUrls = ((detail['vod_play_url'] as String?) ?? '').split(
        r'$$$',
      );

      final requestedIndex = flags.indexOf(flag);
      final episodeIndex = int.tryParse(episodeId ?? '') ?? 0;

      final out = <_Candidate>[];
      for (var i = 0; i < flagUrls.length; i++) {
        final url = _episodeUrl(flagUrls[i], episodeIndex);
        if (url == null || url.isEmpty) continue;
        out.add(
          _Candidate(
            url: url,
            flag: i < flags.length ? flags[i] : '',
            isRequested: i == requestedIndex,
          ),
        );
      }

      if (out.isEmpty) {
        return const Err(
          LocalError(
            code: ErrorCode.spiderParseFailed,
            message: '播放地址为空',
          ),
        );
      }

      // 用户点的那条线路排最前；其余按「直链优先」——直链能直接播，网页线路
      // 还要多一次嗅探往返，成功率也更低。
      out.sort((a, b) {
        if (a.isRequested != b.isRequested) return a.isRequested ? -1 : 1;
        final aDirect = SnifferResolver.looksLikeDirectMedia(a.url);
        final bDirect = SnifferResolver.looksLikeDirectMedia(b.url);
        if (aDirect != bDirect) return aDirect ? -1 : 1;
        return 0;
      });
      return Ok(out);
    } on Object catch (e) {
      return Err(
        LocalError(
          code: ErrorCode.spiderParseFailed,
          message: '解析播放结果失败: $e',
        ),
      );
    }
  }

  /// 从一条线路的剧集串里取第 [episodeIndex] 集的地址。
  ///
  /// 线路内以 `#` 分隔剧集，每集是 `名称$地址`；越界时退回第一集。
  static String? _episodeUrl(String line, int episodeIndex) {
    final episodes = line.split('#');
    if (episodes.isEmpty) return null;
    var index = episodeIndex;
    if (index < 0 || index >= episodes.length) index = 0;
    final episode = episodes[index];
    final dollarIndex = episode.indexOf(r'$');
    return dollarIndex > 0 ? episode.substring(dollarIndex + 1) : episode;
  }

  /// 根据站点类型创建运行时。
  Future<SpiderRuntime> _createRuntime(Site site) async {
    if (runtimeFactory != null) {
      // 查找配置源 URL（用于解析相对路径脚本）与 spider jar（csp_ 站点）
      String? sourceUrl;
      String? spiderJarUrl;
      String? spiderJarMd5;
      if (site.configId != null) {
        sourceUrl = await sites.configSourceUrl(site.id);
        spiderJarUrl = await sites.configSourceSpider(site.id);
        spiderJarMd5 = await sites.configSourceSpiderMd5(site.id);
      }
      return runtimeFactory!.create(
        typeCode: site.typeCode,
        api: site.api,
        ext: site.ext,
        sourceUrl: sourceUrl,
        spiderJarUrl: spiderJarUrl,
        spiderJarMd5: spiderJarMd5,
      );
    }
    // 降级：总是用 HttpRuntime
    return HttpRuntimeAdapter(HttpRuntime(site.api));
  }
}

/// 一条候选播放地址。
class _Candidate {
  const _Candidate({
    required this.url,
    required this.flag,
    required this.isRequested,
  });

  /// 原始地址（可能是直链，也可能是网页播放页）。
  final String url;

  /// 所属线路名。
  final String flag;

  /// 是否是用户在详情页选中的那条线路。
  final bool isRequested;
}
