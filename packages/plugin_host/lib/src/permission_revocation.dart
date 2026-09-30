import 'package:plugin_host/src/plugin_manifest.dart';

/// [PluginManager.revokePermissions] 的结果类别。
///
/// 「改账」与「通知插件」是两件事：账目**一定会改**（只要该权限确实授予过），
/// 通知则取决于插件是否正在运行、以及它处理通知时有没有抛异常。这个枚举把
/// 所有组合显式列出来，调用方不必猜。
enum PermissionRevocationOutcome {
  /// 账已改，且插件收到通知并正常返回。
  notified,

  /// 账已改，但插件没有在运行（未启用 / 已停用 / 激活失败），无需通知。
  notRunning,

  /// 账已改，插件收到通知但**抛了异常** —— 异常已被宿主隔离，宿主与其它插件
  /// 不受影响。
  handlerFailed,

  /// 这些权限本来就没授予，账目未变，也没通知。
  notGranted,

  /// 插件未安装，什么都没做。
  notInstalled;

  /// 账目是否真的发生了变化。
  bool get changedAccount =>
      this == notified || this == notRunning || this == handlerFailed;

  /// 插件是否真的收到了通知（不论它处理得成不成功）。
  bool get notifiedPlugin => this == notified || this == handlerFailed;
}

/// [PluginManager.revokePermissions] 的完整结果。
class PermissionRevocationResult {
  const PermissionRevocationResult({
    required this.outcome,
    this.revoked = const [],
    this.error,
    this.stackTrace,
  });

  /// 结果类别。
  final PermissionRevocationOutcome outcome;

  /// 本次**真正被撤销**的权限。本来就缺的不在其中 —— 调用方据此知道该通知
  /// 插件「少了哪几项」，而不是把请求的整份清单原样转过去。
  final List<PluginPermission> revoked;

  /// 插件处理撤销时抛出的异常。仅
  /// [PermissionRevocationOutcome.handlerFailed] 时非空。
  final Object? error;

  /// [error] 对应的调用栈。
  final StackTrace? stackTrace;

  @override
  String toString() {
    final suffix = error == null ? '' : ', error: $error';
    return 'PermissionRevocationResult(${outcome.name}, revoked: $revoked$suffix)';
  }
}

/// 插件在**缺少所需权限**时被宿主调用，抛出的可捕获的干净错误。
///
/// 宿主能力层（例如 `spider_host` 的宿主 RPC）应当在调用前走
/// [PluginManager.requirePermission] 闸门，缺权限时抛这个 —— 比让插件自己
/// 炸在内部更好：错误类型明确，上层能统一捕获并转成用户可见的提示，
/// 而不是把插件的内部异常当成宿主崩溃。
class PluginPermissionDenied implements Exception {
  const PluginPermissionDenied(this.pluginId, this.permission);

  /// 缺权限的插件。
  final String pluginId;

  /// 缺失的那项权限。
  final PluginPermission permission;

  @override
  String toString() =>
      'PluginPermissionDenied($pluginId 缺少权限 ${permission.value})';
}
