import 'package:drift/drift.dart';

import 'package:storage/src/database/database.dart';

/// `site` 表：站点仓储。
///
/// 语义见 `docs/07-数据库设计.md` §3.2：站点来自配置源或插件（`config_id` 与
/// `plugin_id` 恰有一个非空）；运行时状态列（`status`/`fail_count` 等）可重建。
class SiteRepository {
  /// 持有底层数据库连接。
  SiteRepository(this.db);

  /// 底层数据库连接。
  final AppDatabase db;

  /// 全部启用站点（按优先级降序）。
  Future<List<Site>> enabled({bool searchable = true}) async {
    final query = db.select(db.sites)
      ..where(
        (t) =>
            t.enabled.equals(true) &
            (searchable ? t.searchable.equals(true) : const Constant(true)),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.priority)]);
    return query.get();
  }

  /// 某配置源下的站点。
  Future<List<Site>> byConfig(int configId) async {
    final query = db.select(db.sites)
      ..where((t) => t.configId.equals(configId))
      ..orderBy([(t) => OrderingTerm.desc(t.priority)]);
    return query.get();
  }

  /// 某插件提供的站点。
  Future<List<Site>> byPlugin(String pluginId) async {
    final query = db.select(db.sites)
      ..where((t) => t.pluginId.equals(pluginId))
      ..orderBy([(t) => OrderingTerm.desc(t.priority)]);
    return query.get();
  }

  /// 按 id 取站点；不存在返回 null。
  Future<Site?> byId(int id) async {
    return (db.select(
      db.sites,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 插入/更新站点。返回最终落库行。
  ///
  /// 带 `id` 走覆盖更新；不带则插入并回读自增 id。
  Future<Site> upsert(SitesCompanion companion) async {
    if (companion.id.present) {
      await db.into(db.sites).insertOnConflictUpdate(companion);
      return (await byId(companion.id.value))!;
    }
    final id = await db.into(db.sites).insert(companion);
    return (await byId(id))!;
  }

  /// 更新运行时状态（可重建数据，不影响业务字段）。
  Future<void> updateStatus(
    int siteId, {
    required String status,
    int? failCount,
    DateTime? lastOkAt,
    String? lastError,
    int? lastLatencyMs,
  }) async {
    final companion = SitesCompanion(
      status: Value(status),
      failCount: Value(failCount ?? 0),
      lastOkAt: Value(lastOkAt),
      lastError: Value(lastError),
      lastLatencyMs: Value(lastLatencyMs),
    );
    await (db.update(db.sites)..where((t) => t.id.equals(siteId))).write(
      companion,
    );
  }

  /// 删除某配置源下的全部站点。
  Future<int> deleteByConfig(int configId) async {
    return (db.delete(
      db.sites,
    )..where((t) => t.configId.equals(configId))).go();
  }

  /// 清空全部站点。
  Future<int> clear() => db.delete(db.sites).go();

  /// 获取站点所属配置源的 URL；无配置源或无 URL 时返回 null。
  Future<String?> configSourceUrl(int siteId) async {
    final query = db.select(db.configSources).join([
      innerJoin(db.sites, db.sites.configId.equalsExp(db.configSources.id)),
    ])..where(db.sites.id.equals(siteId));
    final row = await query.getSingleOrNull();
    return row?.read(db.configSources.url);
  }

  /// 获取站点所属配置源的 `spider` jar URL（**已解析为可直接下载的绝对地址**）。
  ///
  /// TVBox 配置根级 `spider` 字段指向远程蜘蛛 jar（含 `csp_XXX` 类），
  /// 导入时需持久化以便 JVM 运行时加载。
  ///
  /// 解析规则见 [resolveSpiderJarUrl]（拆内联 md5 + 相对路径按配置源 URL 解析）。
  /// 此前原样返回，导致 `qist/tvbox` 那类写 `./spider.jar` 的配置 105 个
  /// `csp_` 站点全部取数失败。
  Future<String?> configSourceSpider(int siteId) async {
    final query = db.select(db.configSources).join([
      innerJoin(db.sites, db.sites.configId.equalsExp(db.configSources.id)),
    ])..where(db.sites.id.equals(siteId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return resolveSpiderJarUrl(
      row.read(db.configSources.spider),
      row.read(db.configSources.url),
    );
  }

  /// 获取站点所属配置源的 `spider` jar MD5（配置提供时用于下载校验）。
  ///
  /// **只读列，不回退到 `spider` 字段里内联的 md5** —— 这是刻意的。
  ///
  /// 2026-09-25 之前导入的库把整串 `<url>;md5;<hash>` 原样存进了 `spider`，
  /// `spider_md5` 是 null。看着「回退一下就能把校验补上」，实测是错的：
  /// 那批旧行的内联 md5 与内联 URL **同龄**，上游换过 jar 之后它一样过期
  /// （实测 `qist/tvbox` 的 `af187c2a…` → `abc13bea…`）。拿一个确定过期的
  /// 期望值去校验，只会把本来能下的 jar 卡死在 `_ensureJar` 的 MD5 分支上，
  /// 而且用户看不出该做什么。
  ///
  /// 返回 null 的语义是「本次不做校验」：下游按 URL 哈希命名缓存、直接采用
  /// 下载结果。校验能力没有丢——**新导入的配置由 `parseSpiderField` 把 md5
  /// 正确拆进本列**，正常路径照常校验；旧库想要校验，走「刷新订阅」重建。
  Future<String?> configSourceSpiderMd5(int siteId) async {
    final query = db.select(db.configSources).join([
      innerJoin(db.sites, db.sites.configId.equalsExp(db.configSources.id)),
    ])..where(db.sites.id.equals(siteId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _trimToNull(row.read(db.configSources.spiderMd5));
  }
}

/// TVBox `spider` 字段里 URL 与 md5 的内联分隔符。
///
/// 与 `core_config` 的 `kSpiderMd5Separator` 同值。storage 不依赖 core_config
/// （配置解析是上游的职责，存储层不该为此背一个依赖），所以这里重复一份。
/// 该写法由 TVBox 生态固定（`<url>;md5;<hash>`），不是本项目自定的格式。
const String _kSpiderMd5Separator = ';md5;';

/// 把配置里的 `spider` 字段解析成**可直接下载的绝对 URL**。
///
/// 两件必须做的事：
///
/// 1. **拆掉内联的 `;md5;` 段**。生态写法是 `<url>;md5;<hash>`（见 `core_config`
///    的 `parseSpiderField`）。2026-09-25 之前导入的库把整串原样存进了
///    `config_source.spider`，不拆的话拼出来的 URL 会带上 `;md5;af187…` 后缀，
///    取回来是 404。已拆分的值不含分隔符，重复处理无害（幂等）。
/// 2. **相对路径按 [configUrl] 解析**。真实配置里这个字段常写成 `./spider.jar`
///    —— `qist/tvbox` 的 `xiaosa/api.json` 就是（2026-10-02 实测上游仍是相对
///    路径）。不解析的话下游 `JvmRuntimeFactory._ensureJar` 看到它不是 http(s)，
///    会当成**本地文件路径**去找，然后抛 `spider jar 不存在: ./spider.jar`；
///    该配置 100+ 个 `csp_` 站点因此全部取数失败，首页只报一句
///    「所有站点均无法连接」。
///
/// 已经是绝对 URL、或 [configUrl] 本身不是 http(s)（本地文件 / Base64 /
/// 剪贴板导入）时原样返回 URL 部分：前者无需解析，后者无从解析 —— 交给下游
/// 按本地路径处理。
String? resolveSpiderJarUrl(String? spider, String? configUrl) {
  final raw = _trimToNull(spider);
  if (raw == null) return null;

  // 1. 拆内联 md5（幂等：已拆分的值里没有分隔符）
  final at = raw.indexOf(_kSpiderMd5Separator);
  final url = _trimToNull(at < 0 ? raw : raw.substring(0, at));
  if (url == null) return null;

  // 2. 相对路径 → 绝对 URL
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = Uri.tryParse(_trimToNull(configUrl) ?? '');
  if (base == null || (base.scheme != 'http' && base.scheme != 'https')) {
    return url;
  }
  return base.resolve(url).toString();
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
