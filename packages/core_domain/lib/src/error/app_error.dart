/// 领域层错误类型。
///
/// 形态对齐 `docs/08-RPC协议.md` §7 的统一错误对象：`code` + `message` +
/// `data`，并把 `data.retryable` 提升为一等字段——上层编排（换解析器、换线路、
/// 退避重启）需要它做决策，藏在 map 里每次都要 `as bool?` 太脆。
library;

import 'dart:async';

import 'package:core_domain/src/error/error_code.dart';
import 'package:meta/meta.dart';

/// 一个可预期的失败。
///
/// 只有两个变体，且这个集合是稳定的：
///
/// - [RemoteError]：来自子进程 / RPC，错误码为负数
/// - [LocalError]：宿主进程本地产生，错误码为正数
///
/// 刻意**不**按模块（配置 / 存储 / 播放…）拆子类。模块语义由 [code] 承载，
/// 按模块拆子类会让每加一个模块就把全仓库的 `switch` 打断一次，而这些
/// `switch` 真正关心的从来是「能不能重试」「给用户看什么文案」，不是
/// 「这个错来自哪个包」。
@immutable
sealed class AppError {
  /// 基类构造。
  const AppError({
    required this.code,
    required this.message,
    this.detail = const {},
    this.cause,
    this.stackTrace,
    bool? retryable,
    // ignore: prefer_initializing_formals — 命名参数不能以下划线开头
  }) : _retryable = retryable;

  /// 把任意捕获到的异常收敛成 [AppError]。
  ///
  /// 用于 `Result.guard` 与各层 `catch` 的收口。已知的 Dart 核心异常映射到
  /// 对应错误码，其余归到 [ErrorCode.unknown]——出现在日志里就是「该补一个
  /// 专用码」的信号。
  static AppError from(Object error, [StackTrace? stackTrace]) {
    if (error is AppError) return error;

    final code = switch (error) {
      TimeoutException() => ErrorCode.timeout,
      ArgumentError() => ErrorCode.invalidArgument,
      StateError() => ErrorCode.invalidState,
      FormatException() => ErrorCode.invalidArgument,
      UnsupportedError() => ErrorCode.unsupportedPlatform,
      _ => ErrorCode.unknown,
    };

    return LocalError(
      code: code,
      message: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// 错误码。
  final ErrorCode code;

  /// 面向开发者的原因描述。**不是**直接给用户看的文案——UI 按 [code] 查
  /// 本地化文案，这里的内容进日志与诊断报告。
  final String message;

  /// 结构化补充信息，对应 RPC 错误对象的 `data`。
  final Map<String, Object?> detail;

  /// 引发本错误的原始异常（如果有）。
  final Object? cause;

  /// 原始异常的堆栈（如果有）。
  final StackTrace? stackTrace;

  final bool? _retryable;

  /// 是否值得重试。
  ///
  /// 显式传入的值优先；没传就取 [ErrorCode.retryable] 的默认判断。对端在
  /// `data.retryable` 里给了值时，[RemoteError.fromRpc] 会把它填进来。
  bool get retryable => _retryable ?? code.retryable;

  /// 是否为「正常执行但无数据」。
  ///
  /// `EMPTY_RESULT` 走错误通道只是为了让调用方一处判断即可，语义上不是失败。
  /// UI 要据此区分「这个源没搜到」和「这个源挂了」——两者的处置完全不同。
  bool get isEmpty => code == ErrorCode.emptyResult;

  /// 是否为用户主动取消。取消不该弹错误提示。
  bool get isCancelled =>
      code == ErrorCode.cancelled || code == ErrorCode.requestCancelled;
}

/// 宿主进程本地产生的错误，错误码为正数。
final class LocalError extends AppError {
  /// 构造一个本地错误。
  const LocalError({
    required super.code,
    required super.message,
    super.detail,
    super.cause,
    super.stackTrace,
    super.retryable,
  });

  /// 操作被主动取消。
  const LocalError.cancelled({String message = '操作已取消'})
    : this(code: ErrorCode.cancelled, message: message);

  @override
  String toString() => 'LocalError($code): $message';
}

/// 来自子进程 / RPC 的错误，错误码为负数。
///
/// 额外携带的四个字段直接对应 `docs/08-RPC协议.md` §7 的 `data`，源诊断面板
/// 靠它们定位到「哪个源的哪个方法、跑了多久、脚本栈在哪」。
final class RemoteError extends AppError {
  /// 构造一个远端错误。
  const RemoteError({
    required super.code,
    required super.message,
    this.instanceId,
    this.method,
    this.remoteStack,
    this.elapsed,
    super.detail,
    super.cause,
    super.stackTrace,
    super.retryable,
  });

  /// 从 JSON-RPC 错误对象解码。
  ///
  /// 未知错误码交给 [ErrorCode.resolve] 合成占位码而不是抛异常——对端可能比
  /// 本端新，见 `docs/compatibility.md` §2。
  factory RemoteError.fromRpc(Map<String, Object?> json) {
    final data = switch (json['data']) {
      final Map<String, Object?> map => map,
      _ => const <String, Object?>{},
    };
    final elapsedMs = data['elapsedMs'];

    return RemoteError(
      code: ErrorCode.resolve(switch (json['code']) {
        final int value => value,
        _ => ErrorCode.internalError.value,
      }),
      message: switch (json['message']) {
        final String text => text,
        _ => '',
      },
      instanceId: data['instanceId'] as String?,
      method: data['method'] as String?,
      remoteStack: data['stack'] as String?,
      elapsed: elapsedMs is int ? Duration(milliseconds: elapsedMs) : null,
      detail: data,
      retryable: data['retryable'] as bool?,
    );
  }

  /// 出错的 Spider 实例 id。
  final String? instanceId;

  /// 出错的 RPC 方法名，如 `spider.detail`。
  final String? method;

  /// 脚本侧的堆栈。这是源作者排错唯一有用的东西，务必透传，不要吞。
  final String? remoteStack;

  /// 该调用的耗时。
  final Duration? elapsed;

  /// 编码回 JSON-RPC 错误对象。
  Map<String, Object?> toRpcJson() => {
    'code': code.value,
    'message': message,
    'data': {
      ...detail,
      if (instanceId != null) 'instanceId': instanceId,
      if (method != null) 'method': method,
      if (remoteStack != null) 'stack': remoteStack,
      if (elapsed != null) 'elapsedMs': elapsed!.inMilliseconds,
      'retryable': retryable,
    },
  };

  @override
  String toString() {
    final where = method == null ? '' : ' @$method';
    return 'RemoteError($code$where): $message';
  }
}
