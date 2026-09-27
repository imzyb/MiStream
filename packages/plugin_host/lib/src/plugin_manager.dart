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
/// State transitions are validated against [PluginState] — e.g. you cannot
/// disable a plugin that is not currently enabled. 迁移的完整规则见
/// [PluginState] 的文档。
class PluginManager {
  final Map<String, _PluginEntry> _plugins = {};
  final StreamController<PluginEvent> _eventController =
      StreamController.broadcast();

  /// Stream of plugin state change events.
  Stream<PluginEvent> get events => _eventController.stream;

  /// All registered plugins.
  Iterable<PluginManifest> get manifests =>
      _plugins.values.map((e) => e.manifest);

  /// Install a plugin: register it, then activate it.
  ///
  /// 登记**先于**激活。这样激活失败时插件会以 [PluginState.error] 留在管理器里
  /// —— 用户看得到它、能卸载它，而不是无痕消失。激活抛出的异常仍然向上传播，
  /// 调用方据此提示「已安装但启用失败」；此时插件已登记，重试要走 [enable]。
  Future<void> install(PluginManifest manifest, PluginApi api) async {
    if (_plugins.containsKey(manifest.id)) {
      throw StateError('Plugin ${manifest.id} already installed');
    }

    final entry = _PluginEntry(
      manifest: manifest,
      api: api,
      state: PluginState.installed,
    );
    _plugins[manifest.id] = entry;

    try {
      await api.onActivate();
    } on Object {
      entry.state = PluginState.error;
      _emit(manifest.id, PluginState.installed, PluginState.error);
      rethrow;
    }

    entry.state = PluginState.enabled;
    _emit(manifest.id, PluginState.installed, PluginState.enabled);
  }

  /// Enable a disabled plugin.
  ///
  /// 处于 [PluginState.error] 的插件也允许启用 —— 那是「重试激活」。激活再次
  /// 失败会退回 [PluginState.error] 并抛出。
  Future<void> enable(String pluginId) async {
    final entry = _plugins[pluginId];
    if (entry == null) throw StateError('Plugin $pluginId not found');
    if (!entry.state.canEnable) {
      throw StateError(
        'Plugin $pluginId cannot be enabled (state: ${entry.state})',
      );
    }

    final old = entry.state;
    try {
      await entry.api.onActivate();
    } on Object {
      entry.state = PluginState.error;
      _emit(pluginId, old, PluginState.error);
      rethrow;
    }

    entry.state = PluginState.enabled;
    _emit(pluginId, old, PluginState.enabled);
  }

  /// Disable an enabled plugin.
  ///
  /// `onDeactivate` 抛异常时状态**保持 [PluginState.enabled]**：插件实际仍在
  /// 运行，标成「已停用」或「故障」都不符合事实。异常照常抛出。
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
  ///
  /// 任何状态都能卸载，**包括 [PluginState.error]** —— 卸载是故障插件唯一的
  /// 恢复手段，加闸门会让用户被卡死。因此这里不做状态校验。
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
  ///
  /// 逐个 `onDispose`，**单个失败不中断其余**：一个坏插件（例如 [PluginState.error]
  /// 的那个）不该让其它插件的清理也做不成，更不该让事件流永远关不掉。
  /// 清理完成后把第一个异常抛出去 —— 既不静默吞掉，也不半途而废。
  Future<void> disposeAll() async {
    Object? firstFailure;
    StackTrace? firstStack;
    for (final entry in _plugins.values) {
      try {
        await entry.api.onDispose();
      } on Object catch (error, stack) {
        firstFailure ??= error;
        firstStack ??= stack;
      }
    }
    _plugins.clear();
    await _eventController.close();
    if (firstFailure != null) {
      Error.throwWithStackTrace(firstFailure, firstStack!);
    }
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
