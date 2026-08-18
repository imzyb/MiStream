/// 配置安装服务：把解析好的 TVBox 配置落库，并置引导完成标记。
///
/// 解码与解析复用 `core_config` 的 `ConfigImportService.import`（纯函数，
/// 不碰库）；本服务只负责持久化，这样 Presentation 层就不必直连 `storage`
/// （`docs/10` §3.3，由 `tools/arch_check` 强制）。
library;

import 'package:core_config/core_config.dart';
import 'package:storage/storage.dart';

/// 引导完成标记的设置键。
///
/// 唯一定义处——之前引导页与启动入口各写各的字面量，很容易写歪。
final SettingKey<bool> kOnboardingDoneKey = SettingKey.boolKey(
  'onboarding_done',
);

/// 配置安装服务。
class ConfigInstallService {
  /// 以仓储集合构造。
  ConfigInstallService(this._repositories);

  final Repositories _repositories;

  /// 引导是否已完成。
  Future<bool> isOnboardingDone() =>
      _repositories.settings.read(kOnboardingDoneKey, false);

  /// 置引导完成标记（「跳过」与「导入成功」都走这里）。
  Future<void> markOnboardingDone() =>
      _repositories.settings.write(kOnboardingDoneKey, true);

  /// 把 [result] 中的站点写入库，并置引导完成标记。
  ///
  /// [sourceUrl] 配置源 URL（用于 type=3 站点解析相对脚本路径）。
  /// 返回写入的站点数。
  Future<int> install(
    ConfigImportResult result, {
    String name = '导入配置',
    String? sourceUrl,
  }) async {
    final now = DateTime.now().toUtc();

    final configSourceId = await _repositories.configSources.add(
      ConfigSourcesCompanion.insert(
        name: name,
        url: Value(sourceUrl),
        rawHash: '',
        format: result.format,
        createdAt: now,
        updatedAt: now,
      ),
    );

    for (final site in result.config.sites) {
      await _repositories.sites.upsert(
        SitesCompanion.insert(
          configId: Value(configSourceId),
          siteKey: site.key,
          name: site.name,
          typeCode: site.type,
          runtime: 'http',
          api: site.api,
          ext: Value(site.ext),
          searchable: Value(site.searchable),
          quickSearch: Value(site.quickSearch),
          filterable: Value(site.filterable),
          priority: Value(site.priority),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    await markOnboardingDone();
    return result.config.sites.length;
  }
}
