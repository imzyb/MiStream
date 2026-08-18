/// 影片详情用例：站点查找 → Spider `detail` 调用 → 解析为领域模型。
///
/// Presentation 层不得直连 `storage` / `spider_host`（`docs/10` §3.3，
/// 由 `tools/arch_check` 强制），详情页的基础设施调用因此收在这里。
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/storage.dart';

/// 单个剧集。
class VodEpisode {
  /// 构造剧集。
  const VodEpisode({required this.name, required this.id});

  /// 剧集名（如「第 1 集」）。
  final String name;

  /// 剧集地址或标识，透传给播放页。
  final String id;
}

/// 解析后的影片详情。
class VodDetail {
  /// 构造详情。
  const VodDetail({
    required this.name,
    required this.description,
    required this.flags,
    required this.episodes,
    this.pic,
    this.year,
    this.area,
    this.genre,
    this.remarks,
  });

  /// 影片名。
  final String name;

  /// 封面地址。
  final String? pic;

  /// 年份。
  final String? year;

  /// 地区。
  final String? area;

  /// 类型。
  final String? genre;

  /// 备注（如「更新至 12 集」）。
  final String? remarks;

  /// 简介（已剥离 HTML 标签）。
  final String description;

  /// 线路名列表，顺序与源返回一致。
  final List<String> flags;

  /// 线路名 → 该线路下的剧集列表。
  final Map<String, List<VodEpisode>> episodes;
}

/// 影片详情用例。
class DetailUseCase {
  /// 以站点仓储构造。
  DetailUseCase(this._sites);

  final SiteRepository _sites;

  /// 加载 [siteId] 站点上 [vodId] 的详情。
  Future<Result<VodDetail, AppError>> load({
    required int siteId,
    required String vodId,
  }) async {
    final site = await _sites.byId(siteId);
    if (site == null) {
      return const Err(
        LocalError(code: ErrorCode.notFound, message: '站点不存在'),
      );
    }

    final result = await HttpRuntime(site.api).detail(ids: vodId);
    return result.fold<Result<VodDetail, AppError>>(
      (ok) {
        try {
          final json = jsonDecode(ok.body);
          if (json is! Map<String, Object?>) {
            return const Err<VodDetail, AppError>(
              LocalError(
                code: ErrorCode.invalidResultSchema,
                message: '详情返回不是 JSON 对象',
              ),
            );
          }
          final list = json['list'];
          if (list is! List<Object?> || list.isEmpty) {
            return const Err<VodDetail, AppError>(
              LocalError(code: ErrorCode.emptyResult, message: '无详情数据'),
            );
          }
          final first = list.first;
          if (first is! Map<Object?, Object?>) {
            return const Err<VodDetail, AppError>(
              LocalError(
                code: ErrorCode.invalidResultSchema,
                message: '详情条目不是 JSON 对象',
              ),
            );
          }
          return Ok<VodDetail, AppError>(
            parseDetail(Map<String, Object?>.from(first)),
          );
        } on Object catch (e) {
          return Err<VodDetail, AppError>(
            LocalError(
              code: ErrorCode.invalidResultSchema,
              message: '解析失败: $e',
            ),
          );
        }
      },
      Err<VodDetail, AppError>.new,
    );
  }

  /// 把 TVBox `detail` 返回的单条记录解析为 [VodDetail]。
  ///
  /// 线路以 `$$$` 分隔（`vod_play_from`），各线路的剧集列表以 `##` 分隔
  /// （`vod_play_url`），线路内剧集以 `$` 分隔、`名称$地址` 成对出现。
  /// 公开以便单测直接喂样本，不必起 HTTP。
  static VodDetail parseDetail(Map<String, Object?> vod) {
    final desc =
        (vod['vod_content'] as String?) ?? (vod['vod_blurb'] as String?) ?? '';

    final flagsRaw = (vod['vod_play_from'] as String? ?? '').split(r'$$$');
    final urlsRaw = (vod['vod_play_url'] as String? ?? '').split(r'$$$');

    final episodes = <String, List<VodEpisode>>{};
    for (var i = 0; i < flagsRaw.length; i++) {
      final flag = flagsRaw[i].trim();
      if (flag.isEmpty) continue;
      final urlStr = i < urlsRaw.length ? urlsRaw[i] : '';
      final eps = <VodEpisode>[];
      // TVBox 格式: `第1集$url1#第2集$url2` —— `#` 分隔剧集，`$` 分隔名称与地址。
      //
      // 这里只留名称与**序号**：地址会由 `PlayUseCase` 用同样的规则重新取一次。
      // 让 id 是序号而不是地址，是因为播放前还要经嗅探器解析，把一个可能已经
      // 失效的地址在详情页缓存下来只会让两处解析结果不一致。
      final epParts = urlStr.split('#');
      for (var j = 0; j < epParts.length; j++) {
        final ep = epParts[j];
        if (ep.isEmpty) continue;
        final dollarIndex = ep.indexOf(r'$');
        final name = dollarIndex > 0
            ? ep.substring(0, dollarIndex)
            : '第${j + 1}集';
        eps.add(VodEpisode(name: name, id: '${eps.length}'));
      }
      episodes[flag] = eps;
    }

    return VodDetail(
      name: (vod['vod_name'] as String?) ?? '',
      pic: vod['vod_pic'] as String?,
      year: vod['vod_year'] as String?,
      area: vod['vod_area'] as String?,
      genre: vod['vod_class'] as String?,
      remarks: vod['vod_remarks'] as String?,
      description: _stripHtml(desc),
      flags: episodes.keys.toList(),
      episodes: episodes,
    );
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp('<[^>]*>'), '').trim();
}
