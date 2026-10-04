/// Plugin manifest — describes a plugin's identity, capabilities, and requirements.
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.type,
    this.description,
    this.author,
    this.homepage,
    this.runtime,
    this.permissions = const [],
    this.entryPoint,
    this.minAppVersion,
    this.signature,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      type: PluginType.fromString(json['type'] as String? ?? 'source'),
      description: json['description'] as String?,
      author: json['author'] as String?,
      homepage: json['homepage'] as String?,
      runtime: json['runtime'] as String?,
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => PluginPermission.fromString(e as String))
              .toList() ??
          const [],
      entryPoint: json['entry_point'] as String?,
      minAppVersion: json['min_app_version'] as String?,
      signature: json['signature'] as String?,
    );
  }

  final String id;
  final String name;
  final String version;
  final PluginType type;
  final String? description;
  final String? author;
  final String? homepage;
  final String? runtime;
  final List<PluginPermission> permissions;
  final String? entryPoint;
  final String? minAppVersion;
  final String? signature;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'type': type.value,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      if (homepage != null) 'homepage': homepage,
      if (runtime != null) 'runtime': runtime,
      'permissions': permissions.map((e) => e.value).toList(),
      if (entryPoint != null) 'entry_point': entryPoint,
      if (minAppVersion != null) 'min_app_version': minAppVersion,
      if (signature != null) 'signature': signature,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginManifest &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          version == other.version;

  @override
  int get hashCode => id.hashCode ^ version.hashCode;
}

/// Plugin type enumeration.
enum PluginType {
  source('source'),
  parser('parser'),
  sniffer('sniffer'),
  player('player'),
  theme('theme'),
  unknown('unknown');

  const PluginType(this.value);

  factory PluginType.fromString(String value) {
    return PluginType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PluginType.unknown,
    );
  }
  final String value;
}

/// Plugin permission model.
class PluginPermission {
  const PluginPermission(this.value);

  factory PluginPermission.fromString(String value) {
    return PluginPermission(value);
  }

  final String value;

  static const network = PluginPermission('network');
  static const storage = PluginPermission('storage');
  static const database = PluginPermission('database');
  static const clipboard = PluginPermission('clipboard');
  static const webview = PluginPermission('webview');
  static const fileSystem = PluginPermission('file_system');
  static const mediaPlayback = PluginPermission('media_playback');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginPermission && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PluginPermission($value)';
}
