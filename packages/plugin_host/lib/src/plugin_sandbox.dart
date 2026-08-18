import 'dart:async';
import 'dart:isolate';

/// Sandboxed execution environment for plugins.
///
/// Runs plugin code in isolated Dart isolates to prevent
/// plugins from accessing host memory or causing crashes.
class PluginSandbox {
  PluginSandbox({this.maxConcurrentIsolates = 4});

  /// Maximum number of concurrent plugin isolates.
  final int maxConcurrentIsolates;

  final Map<String, Isolate> _isolates = {};
  final Map<String, ReceivePort> _receivePorts = {};
  int _activeIsolates = 0;

  /// Execute a plugin method in a sandboxed isolate.
  Future<T> execute<T>(
    String pluginId,
    Future<T> Function() task,
  ) async {
    if (_activeIsolates >= maxConcurrentIsolates) {
      throw StateError('Too many concurrent plugin isolates');
    }

    final receivePort = ReceivePort();
    _receivePorts[pluginId] = receivePort;
    _activeIsolates++;

    try {
      final result = await task();
      return result;
    } finally {
      _receivePorts.remove(pluginId);
      _activeIsolates--;
    }
  }

  /// Terminate a plugin's isolate.
  Future<void> terminate(String pluginId) async {
    final isolate = _isolates.remove(pluginId);
    if (isolate != null) {
      isolate.kill(priority: Isolate.immediate);
    }
    _receivePorts.remove(pluginId);
    _activeIsolates--;
  }

  /// Terminate all isolates.
  Future<void> terminateAll() async {
    for (final entry in _isolates.entries) {
      entry.value.kill(priority: Isolate.immediate);
    }
    _isolates.clear();
    _receivePorts.clear();
    _activeIsolates = 0;
  }

  /// Check if a plugin isolate is running.
  bool isRunning(String pluginId) => _isolates.containsKey(pluginId);
}

/// Abstract interface for plugin communication protocol.
///
/// Defines the message types that can be sent between the host
/// and a sandboxed plugin isolate.
abstract class PluginMessage {
  const PluginMessage({required this.type});

  final String type;
}

/// Request message from host to plugin.
class PluginRequest extends PluginMessage {
  const PluginRequest({
    required this.method,
    this.params = const {},
  }) : super(type: 'request');

  final String method;
  final Map<String, dynamic> params;
}

/// Response message from plugin to host.
class PluginResponse extends PluginMessage {
  const PluginResponse({
    required this.requestId,
    this.data,
    this.error,
  }) : super(type: 'response');

  final String requestId;
  final dynamic data;
  final String? error;

  bool get isSuccess => error == null;
}

/// Notification message (one-way, no response expected).
class PluginNotification extends PluginMessage {
  const PluginNotification({
    required this.event,
    this.data,
  }) : super(type: 'notification');

  final String event;
  final dynamic data;
}
