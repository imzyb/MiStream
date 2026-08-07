import 'package:storage/src/dao/plugin_storage_dao.dart';
import 'package:storage/src/dao/settings_dao.dart';
import 'package:storage/src/dao/site_cache_dao.dart';
import 'package:storage/src/database/database.dart';
import 'package:storage/src/repository/config_source_repository.dart';
import 'package:storage/src/repository/favorite_repository.dart';
import 'package:storage/src/repository/history_repository.dart';
import 'package:storage/src/repository/search_history_repository.dart';
import 'package:storage/src/repository/site_repository.dart';

/// 一组仓储的聚合入口。
///
/// 直接对 `AppDatabase` 建各个仓储，避免调用方各自管理依赖。
class Repositories {
  /// 以 [db] 装配全部仓储。
  Repositories(this.db) {
    settings = SettingsDao(db);
    caches = SiteCacheDao(db);
    pluginStorage = PluginStorageDao(db);
    histories = HistoryRepository(db);
    favorites = FavoriteRepository(db);
    searchHistories = SearchHistoryRepository(db);
    sites = SiteRepository(db);
    configSources = ConfigSourceRepository(db);
  }

  /// 底层数据库连接。
  final AppDatabase db;

  /// 设置 KV。
  late final SettingsDao settings;

  /// 源数据缓存。
  late final SiteCacheDao caches;

  /// 插件/源隔离存储。
  late final PluginStorageDao pluginStorage;

  /// 播放历史。
  late final HistoryRepository histories;

  /// 收藏。
  late final FavoriteRepository favorites;

  /// 搜索历史。
  late final SearchHistoryRepository searchHistories;

  /// 站点。
  late final SiteRepository sites;

  /// 配置订阅源。
  late final ConfigSourceRepository configSources;
}
