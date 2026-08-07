/// UseCase 与基础设施的适配器。
///
/// 把 `search_engine` 的接口适配到 `storage` + `spider_host` 的真实实现。
library;

import 'dart:convert';

import 'package:search_engine/search_engine.dart';
import 'package:spider_host/spider_host.dart';
import 'package:storage/src/repository/site_repository.dart';

/// 基于 storage 的 [SourceProvider] 实现。
///
/// 从 `site` 表读取「已启用且可搜索」的站点。
class StorageSourceProvider implements SourceProvider {
  final SiteRepository sites;

  /// 构造适配器。
  StorageSourceProvider(this.sites);

  @override
  Future<List<SearchableSource>> getEnabledSites() async {
    final list = await sites.enabled(searchable: true);
    return list
        .map(
          (s) => SearchableSource(
            id: s.id,
            name: s.name,
            priority: s.priority,
          ),
        )
        .toList();
  }
}

/// 基于 [HttpRuntime] 的 [SpiderSearcher] 实现。
///
/// type=1 源直接通过 HTTP 调用 Spider API 的 search 方法。
class HttpSpiderSearcher implements SpiderSearcher {
  final HttpRuntime runtime;

  /// 构造适配器。
  HttpSpiderSearcher(this.runtime);

  @override
  Future<SpiderSearchResult> search(int sourceId, String keyword) async {
    // 资源限制：单源结果上限 50 条
    const maxResults = 50;
    final result = await runtime.search(keyword: keyword);
    return result.fold(
      (ok) {
        try {
          final json = _decode(ok.body);
          final rawList = json['list'];
          if (rawList is! List) {
            return const SpiderSearchResult(error: '搜索结果格式非法');
          }
          final items = rawList.take(maxResults).map((item) {
            final map = item is Map<String, Object?>
                ? item
                : (item is Map
                      ? Map<String, Object?>.from(item)
                      : <String, Object?>{});
            return SpiderRawItem(
              vodId: (map['vod_id'] as String?) ?? '',
              vodName: (map['vod_name'] as String?) ?? '',
              vodPic: map['vod_pic'] as String?,
              vodRemarks: map['vod_remarks'] as String?,
              vodYear: map['vod_year'] as String?,
            );
          }).toList();
          return SpiderSearchResult(items: items);
        } on Object catch (e) {
          return SpiderSearchResult(error: '解析失败: $e');
        }
      },
      (err) => SpiderSearchResult(error: err.message),
    );
  }

  static Map<String, Object?> _decode(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    return <String, Object?>{};
  }
}
