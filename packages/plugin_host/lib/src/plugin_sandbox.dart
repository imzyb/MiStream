/// 插件执行的**并发闸门与登记表**。
///
/// ⚠️ 这个类**不是隔离执行器**。名字里的 sandbox 指「宿主侧对插件调用的登记
/// 与限额」，不是「把插件代码关进另一个 isolate」。[execute] 就在**调用方的
/// isolate 里**跑 `task`：插件抛的异常照常传播，插件里的死循环照常卡住整个
/// 进程 —— 不要指望它挡住这些。
///
/// 真正的隔离在别处：`type=3` 的源跑在 `spider_host` 的**子进程**里（进程级
/// 隔离，见 docs/08），嗅探跑在独立 isolate。这个类只是宿主侧的簿记。
///
/// 历史（2026-09-30）：它原先的文档写着「Runs plugin code in isolated Dart
/// isolates to prevent plugins from accessing host memory or causing crashes」，
/// 但实现**从未 spawn 过 isolate** —— `_isolates` 表只在 `terminate` 里被读、
/// 从来没有写入，`isRunning` 因此恒为 false；`execute` 里那个 `ReceivePort`
/// 建了就扔、从未被监听。属空壳承诺，已如实化。
///
/// 真要做 isolate 隔离，应改用 `Isolate.run`（一次性任务）或
/// `Isolate.spawn` + 句柄（需要可终止）。当前**无任何调用方**，未投入 ——
/// 与其留一个假的隔离器，不如留一个说明白了的限额器。
class PluginSandbox {
  /// 构造。[maxConcurrentIsolates] 是同时执行的插件任务上限。
  PluginSandbox({this.maxConcurrentIsolates = 4});

  /// 同时执行的插件任务上限。
  final int maxConcurrentIsolates;

  /// 正在执行任务的插件。
  final Set<String> _running = {};

  /// 当前同时执行的任务数。
  int get activeIsolateCount => _running.length;

  /// 在并发限额内执行 [task]。
  ///
  /// 已达上限、或同一插件重入时抛 [StateError]。任务抛异常时照常向上传播，
  /// 但登记一定会被清掉。
  Future<T> execute<T>(String pluginId, Future<T> Function() task) async {
    if (_running.length >= maxConcurrentIsolates) {
      throw StateError('并发插件任务已达上限 $maxConcurrentIsolates，拒绝 $pluginId');
    }
    if (!_running.add(pluginId)) {
      throw StateError('插件 $pluginId 已有正在执行的任务');
    }
    try {
      return await task();
    } finally {
      _running.remove(pluginId);
    }
  }

  /// 把插件从登记表里摘掉。
  ///
  /// ⚠️ **不会中断正在执行的 task**（见类文档）。它只是让后续 [execute] 不被
  /// 重入检查挡住 —— 原实现里那句 `_activeIsolates--` 还会把计数减成负数，
  /// 让限额彻底失效。
  Future<void> terminate(String pluginId) async {
    _running.remove(pluginId);
  }

  /// 清空登记表。同样不中断任何 task。
  Future<void> terminateAll() async {
    _running.clear();
  }

  /// 该插件当前是否有登记中的任务。
  bool isRunning(String pluginId) => _running.contains(pluginId);
}

/// 插件与宿主之间的消息类型定义。
///
/// 目前**没有使用方**：没有一条路径会真的跨 isolate 发这些消息（见
/// [PluginSandbox] 的说明）。保留是因为它们定义了未来做 isolate 隔离时的
/// 线协议形状。
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
