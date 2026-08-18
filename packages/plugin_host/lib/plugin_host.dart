/// Plugin system host — manifest, permissions, lifecycle, and API.
///
/// Provides the plugin framework for MiStream's extensible architecture.
/// Plugins are identified by [PluginManifest.id] and managed through
/// [PluginManager] which handles install/enable/disable/uninstall lifecycle.
library;

export 'src/plugin_manifest.dart'
    show PluginManifest, PluginType, PluginPermission;
export 'src/plugin_api.dart'
    show PluginApi, SourcePluginApi, SnifferPluginApi, PluginState;
export 'src/plugin_manager.dart' show PluginManager, PluginEvent;
export 'src/permission_checker.dart' show PermissionChecker;
export 'src/plugin_loader.dart'
    show PluginLoader, LoadedPlugin, IntegrityResult;
export 'src/plugin_sandbox.dart'
    show
        PluginSandbox,
        PluginMessage,
        PluginRequest,
        PluginResponse,
        PluginNotification;
