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
  final MediaSource mediaSource;
  final String? title;
  final String? coverUrl;

  /// 该地址是否经由页面嗅探得到（诊断用）。
  final bool viaSniffing;

  const PlayResult({
    required this.mediaSource,
    this.title,
    this.coverUrl,
    this.viaSniffing = false,
  });
}

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
class PlayUseCase {
  final SiteRepository sites;
  final SpiderRuntimeFactory? runtimeFactory;

  /// 嗅探解析器；`null` 表示不做嗅探，原地址直接返回。
  final SnifferResolver? resolver;

  /// 构造播放编排器。
  PlayUseCase(this.sites, {this.runtimeFactory, this.resolver});

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

    // 2. 根据站点类型创建运行时，取详情
    final runtime = await _createRuntime(site);
    final detailResult = await runtime.detail(ids: vodId);
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
    if (sniffer == null) {
      // 没装嗅探器：保持旧行为，原地址直接交给播放器。
      return Ok(_plainResult(candidates.first.url, siteReferer));
    }

    // 5. 逐条线路尝试：网页线路要嗅探出真实流地址，直链线路走快路径。
    //
    // 一部片通常有多条线路，其中一条挂掉是常态。挨个试到第一条能用的为止，
    // 比让用户自己在详情页反复切线路合理。
    AppError? lastError;
    for (final candidate in candidates) {
      final outcome = await sniffer.resolve(
        candidate.url,
        referer: siteReferer,
      );
      if (outcome.isOk) {
        final media = outcome.media!;
        return Ok(
          PlayResult(
            mediaSource: MediaSource(
              uri: Uri.parse(media.url),
              headers: media.headers,
              isLive: false,
            ),
            viaSniffing: media.viaSniffing,
          ),
        );
      }
      lastError = _snifferError(outcome, candidate.url);
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

  /// 不经嗅探、直接把原地址包成 [PlayResult]。
  PlayResult _plainResult(String url, String? referer) => PlayResult(
    mediaSource: MediaSource(
      uri: Uri.parse(url),
      isLive: false,
      headers: {
        'User-Agent': _defaultUserAgent,
        if (referer != null) 'Referer': referer,
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
      String? sourceUrl;
      if (site.configId != null) {
        sourceUrl = await sites.configSourceUrl(site.id);
      }
      return runtimeFactory!.create(
        typeCode: site.typeCode,
        api: site.api,
        ext: site.ext,
        sourceUrl: sourceUrl,
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
