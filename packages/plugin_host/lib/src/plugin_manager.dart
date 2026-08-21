import 'dart:async';

import 'package:plugin_host/src/plugin_api.dart';
import 'package:plugin_host/src/plugin_manifest.dart';

/// Event emitted when plugin state changes.
class PluginEvent {
  const PluginEvent({
    required this.pluginId,
    required this.oldState,
    required this.newState,
  });

  final String pluginId;
  final PluginState oldState;
  final PluginState newState;
}

/// Manages plugin lifecycle: install, enable, disable, uninstall.
///
/// Plugins are identified by their manifest [PluginManifest.id].
/// State transitions are validated — e.g., you cannot enable a plugin
/// that is in error state.
class PluginManager {
  final Map<String, _PluginEntry> _plugins = {};
  final StreamController<PluginEvent> _eventController =
      StreamController.broadcast();

  /// Stream of plugin state change events.
  Stream<PluginEvent> get events => _eventController.stream;

  /// All registered plugins.
  Iterable<PluginManifest> get manifests =>
      _plugins.values.map((e) => e.manifest);

  /// Install a plugin from a manifest and API implementation.
  Future<void> install(PluginManifest manifest, PluginApi api) async {
    if (_plugins.containsKey(manifest.id)) {
      throw StateError('Plugin ${manifest.id} already installed');
    }

    await api.onActivate();

    _plugins[manifest.id] = _PluginEntry(
      manifest: manifest,
      api: api,
      state: PluginState.installed,
    );

    _emit(manifest.id, PluginState.installed, PluginState.enabled);
    _plugins[manifest.id]!.state = PluginState.enabled;
  }

  /// Enable a disabled plugin.
  Future<void> enable(String pluginId) async {
    final entry = _plugins[pluginId];
    if (entry == null) throw StateError('Plugin $pluginId not found');
    if (!entry.state.canEnable) {
      throw StateError(
        'Plugin $pluginId cannot be enabled (state: ${entry.state})',
      );
    }

    await entry.api.onActivate();

    final old = entry.state;
    entry.state = PluginState.enabled;
    _emit(pluginId, old, PluginState.enabled);
  }

  /// Disable an enabled plugin.
  Future<void> disable(String pluginId) async {
    final entry = _plugins[pluginId];
    if (entry == null) throw StateError('Plugin $pluginId not found');
    if (!entry.state.canDisable) {
      throw StateError(
        'Plugin $pluginId cannot be disabled (state: ${entry.state})',
      );
    }

    await entry.api.onDeactivate();

    final old = entry.state;
    entry.state = PluginState.disabled;
    _emit(pluginId, old, PluginState.disabled);
  }

  /// Uninstall a plugin.
  Future<void> uninstall(String pluginId) async {
    final entry = _plugins.remove(pluginId);
    if (entry == null) throw StateError('Plugin $pluginId not found');

    await entry.api.onDispose();
    _emit(pluginId, entry.state, PluginState.installed);
  }

  /// Get the state of a plugin.
  PluginState? getState(String pluginId) {
    return _plugins[pluginId]?.state;
  }

  /// Get the API for a plugin.
  PluginApi? getApi(String pluginId) {
    return _plugins[pluginId]?.api;
  }

  /// Get all plugins of a specific type.
  List<PluginManifest> getByType(PluginType type) {
    return _plugins.values
        .where((e) => e.manifest.type == type)
        .map((e) => e.manifest)
        .toList();
  }

  /// Get all enabled plugins.
  List<PluginManifest> getEnabled() {
    return _plugins.values
        .where((e) => e.state == PluginState.enabled)
        .map((e) => e.manifest)
        .toList();
  }

  /// Dispose all plugins.
  Future<void> disposeAll() async {
    for (final entry in _plugins.values) {
      await entry.api.onDispose();
    }
    _plugins.clear();
    await _eventController.close();
  }

  void _emit(String pluginId, PluginState oldState, PluginState newState) {
    if (!_eventController.isClosed) {
      _eventController.add(
        PluginEvent(
          pluginId: pluginId,
          oldState: oldState,
          newState: newState,
        ),
      );
    }
  }
}

class _PluginEntry {
  _PluginEntry({
    required this.manifest,
    required this.api,
    required this.state,
  });

  final PluginManifest manifest;
  final PluginApi api;
  PluginState state;
}
