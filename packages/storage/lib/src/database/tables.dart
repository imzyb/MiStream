// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars - drift 表列是 schema 机械声明，列名即文档；@TableIndex.sql 是单行 SQL
import 'package:drift/drift.dart';

import 'package:storage/src/database/type_converters.dart';

/// 用户导入的配置订阅。
///
/// `docs/07-数据库设计.md` §3.1
@TableIndex.sql(
  'CREATE UNIQUE INDEX ux_config_source_url ON config_source(url) WHERE url IS NOT NULL',
)
class ConfigSources extends Table {
  @override
  String get tableName => 'config_source';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get url => text().nullable()();
  TextColumn get localPath => text().named('local_path').nullable()();
  TextColumn get rawHash => text().named('raw_hash')();
  TextColumn get format => text()();
  BoolColumn get autoUpdate =>
      boolean().named('auto_update').withDefault(const Constant(false))();
  IntColumn get updateIntervalH =>
      integer().named('update_interval_h').withDefault(const Constant(24))();
  IntColumn get lastSyncAt =>
      integer().named('last_sync_at').nullable().map(utcMillis)();
  TextColumn get lastError => text().named('last_error').nullable()();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer().named('created_at').map(utcMillis)();
  IntColumn get updatedAt => integer().named('updated_at').map(utcMillis)();
}

/// 单个数据源站点。
///
/// `docs/07-数据库设计.md` §3.2
@TableIndex.sql(
  "CREATE UNIQUE INDEX ux_site_scope_key ON site(COALESCE(config_id,-1), COALESCE(plugin_id,''), site_key)",
)
@TableIndex(name: 'ix_site_enabled', columns: {#enabled, #priority})
class Sites extends Table {
  @override
  String get tableName => 'site';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get configId => integer()
      .named('config_id')
      .nullable()
      .references(ConfigSources, #id, onDelete: KeyAction.cascade)();
  TextColumn get pluginId => text()
      .named('plugin_id')
      .nullable()
      .references(Plugins, #pluginId, onDelete: KeyAction.cascade)();
  TextColumn get siteKey => text().named('site_key')();
  TextColumn get name => text()();
  IntColumn get typeCode => integer().named('type_code')();
  TextColumn get runtime => text()();
  TextColumn get api => text()();
  TextColumn get ext => text().nullable()();
  BoolColumn get searchable => boolean().withDefault(const Constant(true))();
  BoolColumn get quickSearch =>
      boolean().named('quick_search').withDefault(const Constant(false))();
  BoolColumn get filterable => boolean().withDefault(const Constant(false))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('unknown'))();
  IntColumn get failCount =>
      integer().named('fail_count').withDefault(const Constant(0))();
  IntColumn get lastOkAt =>
      integer().named('last_ok_at').nullable().map(utcMillis)();
  TextColumn get lastError => text().named('last_error').nullable()();
  IntColumn get lastLatencyMs =>
      integer().named('last_latency_ms').nullable()();
  IntColumn get createdAt => integer().named('created_at').map(utcMillis)();
  IntColumn get updatedAt => integer().named('updated_at').map(utcMillis)();

  @override
  List<String> get customConstraints => [
    'CHECK ((config_id IS NULL) <> (plugin_id IS NULL))',
  ];
}

/// 播放历史。`(site, vod)` 只保留一条，随播放更新。
///
/// `docs/07-数据库设计.md` §3.3
@TableIndex(
  name: 'ux_history_item',
  unique: true,
  columns: {#siteId, #vodId},
)
@TableIndex(name: 'ix_history_recent', columns: {#playedAt})
class Histories extends Table {
  @override
  String get tableName => 'history';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get siteId => integer()
      .named('site_id')
      .references(Sites, #id, onDelete: KeyAction.cascade)();
  TextColumn get vodId => text().named('vod_id')();
  TextColumn get vodName => text().named('vod_name')();
  TextColumn get vodPic => text().named('vod_pic').nullable()();
  TextColumn get flag => text().nullable()();
  IntColumn get episodeIndex =>
      integer().named('episode_index').withDefault(const Constant(0))();
  TextColumn get episodeName => text().named('episode_name').nullable()();
  IntColumn get positionMs =>
      integer().named('position_ms').withDefault(const Constant(0))();
  IntColumn get durationMs =>
      integer().named('duration_ms').withDefault(const Constant(0))();
  BoolColumn get finished => boolean().withDefault(const Constant(false))();
  IntColumn get openingMs => integer().named('opening_ms').nullable()();
  IntColumn get endingMs => integer().named('ending_ms').nullable()();
  RealColumn get playRate => real().named('play_rate').nullable()();
  TextColumn get audioTrack => text().named('audio_track').nullable()();
  TextColumn get subtitleTrack => text().named('subtitle_track').nullable()();
  IntColumn get playedAt => integer().named('played_at').map(utcMillis)();
  IntColumn get createdAt => integer().named('created_at').map(utcMillis)();
}

/// 收藏。`vod_remarks` vs `latest_remarks` 的差异就是「有更新」的判定依据。
///
/// `docs/07-数据库设计.md` §3.4
@TableIndex(
  name: 'ux_favorite_item',
  unique: true,
  columns: {#siteId, #vodId},
)
@TableIndex(name: 'ix_favorite_folder', columns: {#folder, #sortOrder})
class Favorites extends Table {
  @override
  String get tableName => 'favorite';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get siteId => integer()
      .named('site_id')
      .references(Sites, #id, onDelete: KeyAction.cascade)();
  TextColumn get vodId => text().named('vod_id')();
  TextColumn get vodName => text().named('vod_name')();
  TextColumn get vodPic => text().named('vod_pic').nullable()();
  TextColumn get vodRemarks => text().named('vod_remarks').nullable()();
  TextColumn get latestRemarks => text().named('latest_remarks').nullable()();
  TextColumn get folder => text().withDefault(const Constant(''))();
  BoolColumn get notifyUpdate =>
      boolean().named('notify_update').withDefault(const Constant(false))();
  IntColumn get lastCheckAt =>
      integer().named('last_check_at').nullable().map(utcMillis)();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
  IntColumn get createdAt => integer().named('created_at').map(utcMillis)();
}

/// 下载任务。
///
/// `docs/07-数据库设计.md` §3.5
@TableIndex(
  name: 'ix_download_status',
  columns: {#status, #priority, #createdAt},
)
class Downloads extends Table {
  @override
  String get tableName => 'download';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get siteId => integer()
      .named('site_id')
      .nullable()
      .references(Sites, #id, onDelete: KeyAction.setNull)();
  TextColumn get vodId => text().named('vod_id').nullable()();
  TextColumn get vodName => text().named('vod_name')();
  TextColumn get episodeName => text().named('episode_name').nullable()();
  TextColumn get sourceUrl => text().named('source_url')();
  TextColumn get headersJson => text().named('headers_json').nullable()();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get mediaType => text().named('media_type')();
  IntColumn get totalBytes =>
      integer().named('total_bytes').withDefault(const Constant(0))();
  IntColumn get doneBytes =>
      integer().named('done_bytes').withDefault(const Constant(0))();
  IntColumn get totalSegments => integer().named('total_segments').nullable()();
  IntColumn get doneSegments => integer().named('done_segments').nullable()();
  TextColumn get status => text()();
  TextColumn get error => text().nullable()();
  IntColumn get speedBps => integer().named('speed_bps').nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().named('created_at').map(utcMillis)();
  IntColumn get updatedAt => integer().named('updated_at').map(utcMillis)();
  IntColumn get completedAt =>
      integer().named('completed_at').nullable().map(utcMillis)();
}

/// HLS 分片进度，支持断点续传。复合主键 `(download_id, seq)`。
///
/// `docs/07-数据库设计.md` §3.5
class DownloadSegments extends Table {
  @override
  String get tableName => 'download_segment';

  IntColumn get downloadId => integer()
      .named('download_id')
      .references(Downloads, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  TextColumn get url => text()();
  IntColumn get bytes => integer().withDefault(const Constant(0))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {downloadId, seq};
}

/// 已安装插件。`plugin_id` 是 manifest.id。
///
/// `docs/07-数据库设计.md` §3.6
class Plugins extends Table {
  @override
  String get tableName => 'plugin';

  TextColumn get pluginId => text().named('plugin_id')();
  TextColumn get name => text()();
  TextColumn get version => text()();
  TextColumn get prevVersion => text().named('prev_version').nullable()();
  TextColumn get type => text()();
  TextColumn get runtime => text().nullable()();
  TextColumn get installPath => text().named('install_path')();
  TextColumn get sourceMarket => text().named('source_market').nullable()();
  TextColumn get manifestJson => text().named('manifest_json')();
  TextColumn get grantedPermissions =>
      text().named('granted_permissions').withDefault(const Constant('{}'))();
  TextColumn get integrityHash => text().named('integrity_hash')();
  TextColumn get signatureStatus => text()
      .named('signature_status')
      .withDefault(const Constant('unsigned'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get installedAt => integer().named('installed_at').map(utcMillis)();
  IntColumn get updatedAt => integer().named('updated_at').map(utcMillis)();

  @override
  Set<Column> get primaryKey => {pluginId};
}

/// 插件的键值设置，复合主键 `(plugin_id, key)`。
///
/// `docs/07-数据库设计.md` §3.7
class PluginSettings extends Table {
  @override
  String get tableName => 'plugin_setting';

  TextColumn get pluginId => text()
      .named('plugin_id')
      .references(Plugins, #pluginId, onDelete: KeyAction.cascade)();
  TextColumn get key => text()();
  TextColumn get valueJson => text().named('value_json')();

  @override
  Set<Column> get primaryKey => {pluginId, key};
}

/// 插件/源脚本的 `local.get/set` 落点，按 owner 隔离。
///
/// `docs/07-数据库设计.md` §3.7
@TableIndex(name: 'ix_plugin_storage_owner', columns: {#owner})
class PluginStorages extends Table {
  @override
  String get tableName => 'plugin_storage';

  TextColumn get owner => text()();
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get bytes => integer()();
  IntColumn get updatedAt => integer().named('updated_at').map(utcMillis)();

  @override
  Set<Column> get primaryKey => {owner, key};
}

/// 直播分组。
///
/// `docs/07-数据库设计.md` §3.8
class LiveGroups extends Table {
  @override
  String get tableName => 'live_group';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get configId => integer()
      .named('config_id')
      .nullable()
      .references(ConfigSources, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
}

/// 直播频道。
///
/// `docs/07-数据库设计.md` §3.8
@TableIndex(name: 'ix_live_channel_group', columns: {#groupId, #sortOrder})
@TableIndex(name: 'ix_live_channel_name', columns: {#name})
class LiveChannels extends Table {
  @override
  String get tableName => 'live_channel';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer()
      .named('group_id')
      .references(LiveGroups, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get logo => text().nullable()();
  TextColumn get urlsJson => text().named('urls_json')();
  TextColumn get epgId => text().named('epg_id').nullable()();
  TextColumn get headersJson => text().named('headers_json').nullable()();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  IntColumn get lastPlayedAt =>
      integer().named('last_played_at').nullable().map(utcMillis)();
}

/// 解析器。`success_count` / `fail_count` 用于自适应排序。
///
/// `docs/07-数据库设计.md` §3.9
class ParseRules extends Table {
  @override
  String get tableName => 'parse_rule';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get configId => integer()
      .named('config_id')
      .nullable()
      .references(ConfigSources, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get typeCode => integer().named('type_code')();
  TextColumn get url => text()();
  TextColumn get extJson => text().named('ext_json').nullable()();
  TextColumn get flagsJson => text().named('flags_json').nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get successCount =>
      integer().named('success_count').withDefault(const Constant(0))();
  IntColumn get failCount =>
      integer().named('fail_count').withDefault(const Constant(0))();
  IntColumn get avgLatencyMs => integer().named('avg_latency_ms').nullable()();
}

/// 源数据缓存。`payload` 是 gzip 压缩的 JSON。
///
/// `docs/07-数据库设计.md` §3.10
@TableIndex(name: 'ix_site_cache_expiry', columns: {#expiresAt})
class SiteCaches extends Table {
  @override
  String get tableName => 'site_cache';

  TextColumn get cacheKey => text().named('cache_key')();
  IntColumn get siteId => integer()
      .named('site_id')
      .references(Sites, #id, onDelete: KeyAction.cascade)();
  TextColumn get method => text()();
  BlobColumn get payload => blob()();
  IntColumn get bytes => integer()();
  IntColumn get expiresAt => integer().named('expires_at').map(utcMillis)();
  IntColumn get createdAt => integer().named('created_at').map(utcMillis)();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

/// 应用设置 KV。类型安全靠 Dart 侧 `SettingKey<T>` 常量表保证。
///
/// `docs/07-数据库设计.md` §3.11
class Settings extends Table {
  @override
  String get tableName => 'setting';

  TextColumn get key => text()();
  TextColumn get valueJson => text().named('value_json')();
  IntColumn get updatedAt => integer().named('updated_at').map(utcMillis)();

  @override
  Set<Column> get primaryKey => {key};
}

/// 搜索历史。
///
/// `docs/07-数据库设计.md` §3.12
class SearchHistories extends Table {
  @override
  String get tableName => 'search_history';

  TextColumn get keyword => text()();
  IntColumn get hitCount =>
      integer().named('hit_count').withDefault(const Constant(1))();
  IntColumn get lastAt => integer().named('last_at').map(utcMillis)();

  @override
  Set<Column> get primaryKey => {keyword};
}

/// 结构化诊断日志。保留最近 7 天或 50000 条（取先到者）。
///
/// `docs/07-数据库设计.md` §3.13
@TableIndex(name: 'ix_app_event_ts', columns: {#ts})
@TableIndex(name: 'ix_app_event_scope', columns: {#scope, #ts})
class AppEvents extends Table {
  @override
  String get tableName => 'app_event';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer().map(utcMillis)();
  TextColumn get level => text()();
  TextColumn get scope => text()();
  IntColumn get siteId => integer().named('site_id').nullable()();
  TextColumn get code => text().nullable()();
  TextColumn get message => text()();
  TextColumn get detailJson => text().named('detail_json').nullable()();
}
