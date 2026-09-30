import 'package:plugin_host/src/plugin_manifest.dart';

/// Plugin lifecycle states.
///
/// 允许的迁移（左侧为动作）：
///
/// ```
/// install   : (无)      -> installed
/// 激活成功   : installed -> enabled
/// 激活失败   : installed -> error
/// disable   : enabled   -> disabled
/// enable    : disabled  -> enabled
/// enable    : error     -> enabled      // 重试激活
/// uninstall : 任意状态   -> (无)
/// ```
///
/// - [installed]：已登记、尚未激活。只在安装过程中短暂出现。
/// - [enabled]：已激活，正在工作。
/// - [disabled]：已停用，可再次启用。
/// - [error]：激活失败。**不是终态** —— 补上外部条件（例如授予缺失的权限）
///   后可以重新启用，也可以直接卸载。
///
/// 卸载不设闸门：故障插件必须能被移除，否则用户会被卡在一个卸不掉的插件上。
enum PluginState {
  installed,
  enabled,
  disabled,
  error;

  /// 能否迁移到 [enabled]。
  ///
  /// [error] 也允许 —— 那是「重试激活」。唯一不允许的是已经处于 [enabled]。
  bool get canEnable => this == installed || this == disabled || this == error;

  /// 能否迁移到 [disabled]。只有正在运行的插件需要停用。
  bool get canDisable => this == enabled;

  /// 是否处于激活失败态。
  bool get isFailed => this == error;
}

/// Abstract API that a plugin must implement.
abstract class PluginApi {
  /// Called when the plugin is first loaded.
  Future<void> onActivate();

  /// Called when the plugin is deactivated.
  Future<void> onDeactivate();

  /// Called when the plugin is about to be removed.
  Future<void> onDispose();

  /// 插件**已被授予的权限被运行时撤销**时调用。
  ///
  /// 插件应停止使用这些能力并**优雅降级**：源插件失去 `network` 后应当回空
  /// 列表 / 明确失败，而不是继续发起请求或抛出内部异常。降级到什么程度由插件
  /// 自己决定 —— 宿主**不会**替它自动停用（见 `PluginManager.revokePermissions`）。
  ///
  /// [revoked] 只含**本次真正从「已授予」变为「未授予」**的项，不是调用方请求
  /// 撤销的整份清单。
  ///
  /// ⚠️ 这里抛出的异常会被宿主**隔离**，不会影响其它插件或宿主进程；但插件
  /// 自身的状态可能因此不一致，别把它当成兜底手段。
  ///
  /// 默认空实现：存量插件不实现也能编译、也能正常运行（只是不感知撤销）。
  Future<void> onPermissionRevoked(List<PluginPermission> revoked) async {}

  /// Returns the plugin's manifest.
  PluginManifest get manifest;
}

/// Source plugin API — provides content from a media source.
abstract class SourcePluginApi extends PluginApi {
  /// Fetch home page content.
  Future<List<Map<String, dynamic>>> getHome();

  /// Fetch category list.
  Future<List<Map<String, dynamic>>> getCategories();

  /// Fetch category detail with pagination.
  Future<Map<String, dynamic>> getCategoryDetail({
    required String typeId,
    int page = 1,
  });

  /// Search content by keyword.
  Future<List<Map<String, dynamic>>> search({
    required String keyword,
    int page = 1,
  });

  /// Fetch detail for a specific item.
  Future<Map<String, dynamic>> getDetail({required String vodId});

  /// Get playable URL for an episode.
  Future<Map<String, dynamic>> getPlayUrl({
    required String vodId,
    required String flag,
    String? episodeId,
  });
}

/// Sniffer plugin API — detects media URLs from web pages.
abstract class SnifferPluginApi extends PluginApi {
  /// Sniff media URLs from HTML content.
  Future<List<Map<String, dynamic>>> sniffFromHtml(String html);

  /// Sniff media URLs from JavaScript content.
  Future<List<Map<String, dynamic>>> sniffFromJs(String js);

  /// Sniff media URLs from a URL by fetching it.
  Future<List<Map<String, dynamic>>> sniffFromUrl(String url);
}
