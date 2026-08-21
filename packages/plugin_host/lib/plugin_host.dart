/// Plugin system host — manifest, permissions, lifecycle, and API.
///
/// Provides the plugin framework for MiStream's extensible architecture.
/// Plugins are identified by [PluginManifest.id] and managed through
/// [PluginManager] which handles install/enable/disable/uninstall lifecycle.
library;

import 'package:plugin_host/plugin_host.dart'
    show PluginManager, PluginManifest;

export 'src/permission_checker.dart' show PermissionChecker;
export 'src/plugin_api.dart'
    show PluginApi, PluginState, SnifferPluginApi, SourcePluginApi;
export 'src/plugin_loader.dart'
    show IntegrityResult, LoadedPlugin, PluginLoader;
export 'src/plugin_manager.dart' show PluginEvent, PluginManager;
export 'src/plugin_manifest.dart'
    show PluginManifest, PluginPermission, PluginType;
export 'src/path_guard.dart' show isPathTraversal;
export 'src/plugin_sandbox.dart'
    show
        PluginMessage,
        PluginNotification,
        PluginRequest,
        PluginResponse,
        PluginSandbox;
