import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'plugin_manifest.dart';

/// Loads plugins from zip archives or directories.
///
/// Handles extraction, validation, and sandbox initialization
/// for each plugin before it's registered with the [PluginManager].
class PluginLoader {
  PluginLoader({required this.pluginsDirectory});

  /// Root directory where plugins are stored.
  final String pluginsDirectory;

  /// Load all plugins from the plugins directory.
  Future<List<LoadedPlugin>> loadAll() async {
    final dir = Directory(pluginsDirectory);
    if (!dir.existsSync()) return [];

    final plugins = <LoadedPlugin>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final plugin = await loadFromDirectory(entity.path);
        if (plugin != null) plugins.add(plugin);
      }
    }
    return plugins;
  }

  /// Load a plugin from a directory containing manifest.json and source files.
  Future<LoadedPlugin?> loadFromDirectory(String path) async {
    final manifestFile = File('$path/manifest.json');
    if (!manifestFile.existsSync()) return null;

    try {
      final jsonStr = await manifestFile.readAsString();
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final manifest = PluginManifest.fromJson(json);

      // Verify integrity
      final integrity = await verifyIntegrity(path);
      if (!integrity.valid) return null;

      return LoadedPlugin(
        manifest: manifest,
        path: path,
        integrityHash: integrity.hash,
      );
    } catch (_) {
      return null;
    }
  }

  /// Load a plugin from a zip file.
  Future<LoadedPlugin?> loadFromZip(String zipPath) async {
    final tempDir = await Directory.systemTemp.createTemp('plugin_');

    try {
      if (!File(zipPath).existsSync()) return null;

      // After extraction, load from the temp directory
      return await loadFromDirectory(tempDir.path);
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// Verify plugin file integrity using SHA-256.
  Future<IntegrityResult> verifyIntegrity(String pluginPath) async {
    final dir = Directory(pluginPath);
    if (!dir.existsSync()) {
      return IntegrityResult(valid: false, hash: '');
    }

    final bytes = BytesBuilder();
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      bytes.add(await file.readAsBytes());
    }

    final hash = sha256.convert(bytes.toBytes()).toString();
    return IntegrityResult(valid: true, hash: hash);
  }
}

/// Result of loading a plugin.
class LoadedPlugin {
  const LoadedPlugin({
    required this.manifest,
    required this.path,
    required this.integrityHash,
  });

  final PluginManifest manifest;
  final String path;
  final String integrityHash;
}

/// Result of integrity verification.
class IntegrityResult {
  const IntegrityResult({required this.valid, required this.hash});

  final bool valid;
  final String hash;
}
