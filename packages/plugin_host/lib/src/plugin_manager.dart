import 'dart:async';

import 'package:plugin_host/src/permission_checker.dart';
import 'package:plugin_host/src/permission_revocation.dart';
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
///
/// 同时是**权限撤销的统一入口**：账本（[permissions]）与插件通知都在这里，
/// 避免「改了账却忘了通知插件」这种分裂。见 [revokePermissions]。
class PluginManager {
  /// 构造。[permissions] 缺省时新建一份空账本。
  PluginManager({PermissionChecker? permissions})
    : permissions = permissions ?? PermissionChecker(const {});

  /// 权限账本。**改账请走 [revokePermissions]**，直接改这里不会通知插件。
  final PermissionChecker permissions;

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

  /// 撤销 [pluginId] 的若干权限，并**通知正在运行的插件**。
  ///
  /// 顺序是固定的：**先改账，再通知**。账目只要该权限确实授予过就一定改掉，
  /// 通知成不成功都不回滚 —— 用户点了「撤销」，权限就不能还在。
  ///
  /// 通知只在插件**处于 [PluginState.enabled]** 时发出。未运行（未启用 / 已停用 /
  /// 激活失败）的插件下次启用时会重新读账本，无需运行时通知。
  ///
  /// **不做的事（有意为之）**：
  /// - **不自动停用插件**。撤销一项权限不等于插件一定废了 —— 它可能优雅降级
  ///   （例如源插件失去 `network` 后只回本地缓存）。要不要停用是应用层的策略，
  ///   宿主不替用户决定。是否还「完整可用」用 [isFullyPermitted] 查。
  /// - **不把插件标成 [PluginState.error]**。插件仍在运行，标故障不实。
  /// - **不让插件处理撤销时的异常外泄**。异常被捕获后放进返回值的 [error]，
  ///   宿主与其它插件不受影响 —— 这正是「不崩溃」的落点。
  Future<PermissionRevocationResult> revokePermissions(
    String pluginId,
    List<PluginPermission> revoked,
  ) async {
    final entry = _plugins[pluginId];
    if (entry == null) {
      return const PermissionRevocationResult(
        outcome: PermissionRevocationOutcome.notInstalled,
      );
    }

    final actuallyRevoked = <PluginPermission>[
      for (final permission in revoked)
        if (permissions.revoke(pluginId, permission)) permission,
    ];
    if (actuallyRevoked.isEmpty) {
      return const PermissionRevocationResult(
        outcome: PermissionRevocationOutcome.notGranted,
      );
    }
    final revokedView = List<PluginPermission>.unmodifiable(actuallyRevoked);

    if (entry.state != PluginState.enabled) {
      return PermissionRevocationResult(
        outcome: PermissionRevocationOutcome.notRunning,
        revoked: revokedView,
      );
    }

    try {
      await entry.api.onPermissionRevoked(revokedView);
    } on Object catch (error, stackTrace) {
      return PermissionRevocationResult(
        outcome: PermissionRevocationOutcome.handlerFailed,
        revoked: revokedView,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return PermissionRevocationResult(
      outcome: PermissionRevocationOutcome.notified,
      revoked: revokedView,
    );
  }

  /// 撤销 [pluginId] 的**全部**权限并通知插件（若它在运行）。
  ///
  /// 与 [revokePermissions] 同一套语义，只是撤销项来自账本而非调用方指定。
  Future<PermissionRevocationResult> revokeAllPermissions(
    String pluginId,
  ) async {
    final entry = _plugins[pluginId];
    if (entry == null) {
      return const PermissionRevocationResult(
        outcome: PermissionRevocationOutcome.notInstalled,
      );
    }
    return revokePermissions(pluginId, permissions.getGranted(pluginId));
  }

  /// 插件是否已拿到它清单里声明的**全部**权限。
  ///
  /// 撤销后为 `false` 说明插件进入了**降级运行**状态 —— 它可能仍能工作（用缓存、
  /// 用本地数据），但能力已不完整。未安装的插件返回 `false`。
  bool isFullyPermitted(String pluginId) {
    final entry = _plugins[pluginId];
    if (entry == null) return false;
    return permissions.hasAllPermissions(entry.manifest);
  }

  /// 宿主调用需要 [permission] 的插件能力前，统一走这个闸门。
  ///
  /// 缺权限时抛 [PluginPermissionDenied]（**可捕获的干净错误**），而不是把调用
  /// 交给插件、让它在内部炸出难以归因的异常。这是「撤销后不崩溃」在**调用侧**
  /// 的落点：调用方捕获这一种异常即可统一提示用户。
  ///
  /// [body] 只在权限齐备时执行。
  Future<T> requirePermission<T>(
    String pluginId,
    PluginPermission permission,
    Future<T> Function() body,
  ) async {
    if (!permissions.getGranted(pluginId).contains(permission)) {
      throw PluginPermissionDenied(pluginId, permission);
    }
    return body();
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
