import 'plugin_manifest.dart';

/// Plugin lifecycle states.
enum PluginState {
  installed,
  enabled,
  disabled,
  error;

  bool get canEnable => this == installed || this == disabled;
  bool get canDisable => this == enabled;
  bool get canUninstall => this != error;
}

/// Abstract API that a plugin must implement.
abstract class PluginApi {
  /// Called when the plugin is first loaded.
  Future<void> onActivate();

  /// Called when the plugin is deactivated.
  Future<void> onDeactivate();

  /// Called when the plugin is about to be removed.
  Future<void> onDispose();

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
