import 'dart:io' show Platform;

/// Platform detection and adaptation layer for multi-platform support.
///
/// Provides abstractions over platform-specific features like
/// file system access, window management, and native APIs.
abstract class PlatformAdapter {
  /// Get the current platform type.
  PlatformType get platformType;

  /// Get the application support directory path.
  Future<String> getAppSupportDirectory();

  /// Get the cache directory path.
  Future<String> getCacheDirectory();

  /// Get the downloads directory path.
  Future<String> getDownloadsDirectory();

  /// Check if a feature is supported on this platform.
  bool isFeatureSupported(PlatformFeature feature);

  /// Get platform-specific configuration.
  PlatformConfig getConfig();
}

/// Supported platform types.
enum PlatformType { windows, macos, linux, android, ios, web, unknown }

/// Platform features that may or may not be available.
enum PlatformFeature {
  webview2,
  webkit,
  fileSystem,
  backgroundService,
  notifications,
  systemTray,
  windowControls,
  protocolHandler,
}

/// Platform-specific configuration.
class PlatformConfig {
  const PlatformConfig({
    required this.type,
    this.supportsWebView = false,
    this.supportsBackground = false,
    this.supportsNotifications = false,
    this.supportsSystemTray = false,
    this.libraryExtension = '.so',
  });

  final PlatformType type;
  final bool supportsWebView;
  final bool supportsBackground;
  final bool supportsNotifications;
  final bool supportsSystemTray;
  final String libraryExtension;
}

/// Windows platform adapter.
class WindowsPlatformAdapter implements PlatformAdapter {
  @override
  PlatformType get platformType => PlatformType.windows;

  @override
  Future<String> getAppSupportDirectory() async =>
      '${Platform.environment['APPDATA'] ?? ''}/MiStream';

  @override
  Future<String> getCacheDirectory() async =>
      '${Platform.environment['LOCALAPPDATA'] ?? ''}/MiStream/Cache';

  @override
  Future<String> getDownloadsDirectory() async =>
      '${Platform.environment['USERPROFILE'] ?? ''}/Downloads';

  @override
  bool isFeatureSupported(PlatformFeature feature) {
    return switch (feature) {
      PlatformFeature.webview2 => true,
      PlatformFeature.fileSystem => true,
      PlatformFeature.backgroundService => true,
      PlatformFeature.notifications => true,
      PlatformFeature.systemTray => true,
      PlatformFeature.windowControls => true,
      PlatformFeature.protocolHandler => true,
      _ => false,
    };
  }

  @override
  PlatformConfig getConfig() => const PlatformConfig(
    type: PlatformType.windows,
    supportsWebView: true,
    supportsBackground: true,
    supportsNotifications: true,
    supportsSystemTray: true,
    libraryExtension: '.dll',
  );
}

/// Placeholder for other platforms.
class StubPlatformAdapter implements PlatformAdapter {
  @override
  PlatformType get platformType => PlatformType.unknown;

  @override
  Future<String> getAppSupportDirectory() async => '/tmp/mistream';

  @override
  Future<String> getCacheDirectory() async => '/tmp/mistream/cache';

  @override
  Future<String> getDownloadsDirectory() async => '/tmp/downloads';

  @override
  bool isFeatureSupported(PlatformFeature feature) => false;

  @override
  PlatformConfig getConfig() =>
      const PlatformConfig(type: PlatformType.unknown);
}

/// macOS platform adapter.
class MacosPlatformAdapter implements PlatformAdapter {
  @override
  PlatformType get platformType => PlatformType.macos;

  @override
  Future<String> getAppSupportDirectory() async =>
      '${Platform.environment['HOME'] ?? ''}/Library/Application Support/MiStream';

  @override
  Future<String> getCacheDirectory() async =>
      '${Platform.environment['HOME'] ?? ''}/Library/Caches/MiStream';

  @override
  Future<String> getDownloadsDirectory() async =>
      '${Platform.environment['HOME'] ?? ''}/Downloads';

  @override
  bool isFeatureSupported(PlatformFeature feature) {
    return switch (feature) {
      PlatformFeature.webkit => true,
      PlatformFeature.fileSystem => true,
      PlatformFeature.backgroundService => true,
      PlatformFeature.notifications => true,
      PlatformFeature.systemTray => false,
      PlatformFeature.windowControls => true,
      PlatformFeature.protocolHandler => true,
      _ => false,
    };
  }

  @override
  PlatformConfig getConfig() => const PlatformConfig(
    type: PlatformType.macos,
    supportsWebView: true,
    supportsBackground: true,
    supportsNotifications: true,
    supportsSystemTray: false,
    libraryExtension: '.dylib',
  );
}

/// Linux platform adapter.
class LinuxPlatformAdapter implements PlatformAdapter {
  @override
  PlatformType get platformType => PlatformType.linux;

  @override
  Future<String> getAppSupportDirectory() async =>
      '${Platform.environment['HOME'] ?? ''}/.config/MiStream';

  @override
  Future<String> getCacheDirectory() async =>
      '${Platform.environment['HOME'] ?? ''}/.cache/MiStream';

  @override
  Future<String> getDownloadsDirectory() async =>
      '${Platform.environment['HOME'] ?? ''}/Downloads';

  @override
  bool isFeatureSupported(PlatformFeature feature) {
    return switch (feature) {
      PlatformFeature.fileSystem => true,
      PlatformFeature.backgroundService => true,
      PlatformFeature.notifications => true,
      PlatformFeature.systemTray => true,
      PlatformFeature.protocolHandler => true,
      _ => false,
    };
  }

  @override
  PlatformConfig getConfig() => const PlatformConfig(
    type: PlatformType.linux,
    supportsWebView: false,
    supportsBackground: true,
    supportsNotifications: true,
    supportsSystemTray: true,
    libraryExtension: '.so',
  );
}

/// Factory to create the appropriate [PlatformAdapter] for the current platform.
PlatformAdapter createPlatformAdapter() {
  if (Platform.isWindows) return WindowsPlatformAdapter();
  if (Platform.isMacOS) return MacosPlatformAdapter();
  if (Platform.isLinux) return LinuxPlatformAdapter();
  return StubPlatformAdapter();
}
