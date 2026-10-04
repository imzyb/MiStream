import 'package:plugin_host/src/plugin_manifest.dart';

/// Checks whether a plugin has been granted required permissions.
///
/// **这是账本，不是通知者。** 它只负责「某项权限是否已授予」的读写；把
/// 「权限被撤销」这件事送到正在运行的插件，由 `PluginManager.revokePermissions`
/// 统一做（先改这里的账，再通知插件）。直接调 [revoke] / [revokeAll] 只改账、
/// **不通知插件** —— 只有当你确认插件没在运行时才该这么做。
class PermissionChecker {
  PermissionChecker(Map<String, List<PluginPermission>> granted)
    : _grantedPermissions = {
        for (final e in granted.entries) e.key: List.of(e.value),
      };

  /// Permissions granted per plugin ID.
  final Map<String, List<PluginPermission>> _grantedPermissions;

  /// Check if a plugin has all required permissions.
  bool hasAllPermissions(PluginManifest manifest) {
    final granted = _grantedPermissions[manifest.id] ?? [];
    return manifest.permissions.every(granted.contains);
  }

  /// Get missing permissions for a plugin.
  List<PluginPermission> getMissingPermissions(PluginManifest manifest) {
    final granted = _grantedPermissions[manifest.id] ?? [];
    return manifest.permissions.where((p) => !granted.contains(p)).toList();
  }

  /// Grant a permission to a plugin.
  void grant(String pluginId, PluginPermission permission) {
    _grantedPermissions.putIfAbsent(pluginId, () => []);
    if (!_grantedPermissions[pluginId]!.contains(permission)) {
      _grantedPermissions[pluginId]!.add(permission);
    }
  }

  /// Revoke a permission from a plugin.
  ///
  /// 返回**账目是否真的变了**：该权限本来就没授予时返回 `false`（幂等，不是错误）。
  /// 调用方据此决定要不要通知插件 —— 撤销一项本就没有的权限，插件无需知情。
  bool revoke(String pluginId, PluginPermission permission) {
    return _grantedPermissions[pluginId]?.remove(permission) ?? false;
  }

  /// Revoke all permissions for a plugin.
  ///
  /// 返回**被撤销的权限清单**（该插件本来就没有任何授权时返回空列表）。
  List<PluginPermission> revokeAll(String pluginId) {
    return _grantedPermissions.remove(pluginId) ?? const [];
  }

  /// Get all granted permissions for a plugin.
  List<PluginPermission> getGranted(String pluginId) {
    return List.unmodifiable(_grantedPermissions[pluginId] ?? []);
  }
}
