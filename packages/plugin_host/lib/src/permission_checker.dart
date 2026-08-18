import 'plugin_manifest.dart';

/// Checks whether a plugin has been granted required permissions.
class PermissionChecker {
  const PermissionChecker(this._grantedPermissions);

  /// Permissions granted per plugin ID.
  final Map<String, List<PluginPermission>> _grantedPermissions;

  /// Check if a plugin has all required permissions.
  bool hasAllPermissions(PluginManifest manifest) {
    final granted = _grantedPermissions[manifest.id] ?? [];
    return manifest.permissions.every((p) => granted.contains(p));
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
  void revoke(String pluginId, PluginPermission permission) {
    _grantedPermissions[pluginId]?.remove(permission);
  }

  /// Revoke all permissions for a plugin.
  void revokeAll(String pluginId) {
    _grantedPermissions.remove(pluginId);
  }

  /// Get all granted permissions for a plugin.
  List<PluginPermission> getGranted(String pluginId) {
    return List.unmodifiable(_grantedPermissions[pluginId] ?? []);
  }
}
