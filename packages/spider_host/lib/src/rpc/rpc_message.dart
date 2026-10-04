/// JSON-RPC 2.0 消息类型与编解码。
///
/// 三种形态见 `docs/08-RPC协议.md` §2：请求 / 响应 / 通知。字段名严格对齐
/// JSON-RPC 2.0 规范（`jsonrpc`/`id`/`method`/`params`/`result`/`error`）。
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';

/// JSON-RPC 协议版本号（`jsonrpc` 字段值）。
const String kJsonRpcVersion = '2.0';

/// 双向调用中，一方发给另一方的抽象消息。
///
/// 分三种具体形态：[RpcRequest]（需响应）、[RpcResponse]（响应）、
/// [RpcNotification]（无响应）。统一用 [RpcMessage.fromJson] 解码，
/// [RpcMessage.toJson] 编码。
sealed class RpcMessage {
  /// 序列化回 JSON 友好的 map。
  Map<String, Object?> toJson();

  /// 从 [json] 解码消息。
  static RpcMessage fromJson(Map<String, Object?> json) {
    final isRequest = json.containsKey('method');
    final isResponse = json.containsKey('result') || json.containsKey('error');

    if (isRequest) {
      final id = json['id'];
      if (id is num) {
        return RpcRequest(
          id: id.toInt(),
          method: json['method']! as String,
          params: _asMap(json['params']),
        );
      }
      return RpcNotification(
        method: json['method']! as String,
        params: _asMap(json['params']),
      );
    }

    if (isResponse) {
      final id = json['id'];
      final requestId = id is num ? id.toInt() : -1;
      if (json.containsKey('error')) {
        return RpcResponse.error(
          id: requestId,
          error: RemoteError.fromRpc(
            (json['error']! as Map).cast<String, Object?>(),
          ),
        );
      }
      return RpcResponse.result(
        id: requestId,
        result: json['result'],
      );
    }

    throw const FormatException('无法识别的 JSON-RPC 消息');
  }

  static Map<String, Object?> _asMap(Object? value) =>
      value is Map<String, Object?>
      ? value
      : value is Map
      ? value.cast<String, Object?>()
      : <String, Object?>{};
}

/// 请求（需要响应）。
class RpcRequest extends RpcMessage {
  /// 构造请求。
  RpcRequest({
    required this.id,
    required this.method,
    this.params = const {},
  });

  /// 请求 id，由发起方分配，单调递增。
  final int id;

  /// 方法名，如 `spider.search`。
  final String method;

  /// 参数对象。
  final Map<String, Object?> params;

  @override
  Map<String, Object?> toJson() => {
    'jsonrpc': kJsonRpcVersion,
    'id': id,
    'method': method,
    'params': params,
  };
}

/// 通知（无响应，双向）。
class RpcNotification extends RpcMessage {
  /// 构造通知。
  RpcNotification({
    required this.method,
    this.params = const {},
  });

  /// 方法名。
  final String method;

  /// 参数对象。
  final Map<String, Object?> params;

  @override
  Map<String, Object?> toJson() => {
    'jsonrpc': kJsonRpcVersion,
    'method': method,
    'params': params,
  };
}

/// 响应（对请求的应答）。携带 [result] 或 [error] 之一。
class RpcResponse extends RpcMessage {
  RpcResponse._({
    required this.id,
    this.result,
    this.error,
  });

  /// 成功：携带结果。
  factory RpcResponse.result({
    required int id,
    required Object? result,
  }) {
    return RpcResponse._(id: id, result: result);
  }

  /// 失败：携带错误。
  factory RpcResponse.error({
    required int id,
    required RemoteError error,
  }) {
    return RpcResponse._(id: id, error: error);
  }

  /// 所响应的请求 id。
  final int id;

  /// 成功结果；失败时为 null。
  final Object? result;

  /// 失败错误；成功时为 null。
  final RemoteError? error;

  /// 是否成功。
  bool get isError => error != null;

  @override
  Map<String, Object?> toJson() {
    if (error != null) {
      return {
        'jsonrpc': kJsonRpcVersion,
        'id': id,
        'error': error!.toRpcJson(),
      };
    }
    return {
      'jsonrpc': kJsonRpcVersion,
      'id': id,
      'result': result,
    };
  }
}

/// 便捷函数：构造一个 Parse error 响应（RFC 要求的标准错误）。
RpcResponse jsonRpcParseError() => RpcResponse.error(
  id: -1,
  error: const RemoteError(
    code: ErrorCode.parseError,
    message: 'Invalid JSON',
  ),
);

/// 便捷函数：构造一个 Invalid Request 响应。
RpcResponse jsonRpcInvalidRequest() => RpcResponse.error(
  id: -1,
  error: const RemoteError(
    code: ErrorCode.invalidRequest,
    message: 'Invalid Request',
  ),
);

/// 便捷函数：构造一个 Method not found 响应。
RpcResponse jsonRpcMethodNotFound(String method) => RpcResponse.error(
  id: -1,
  error: RemoteError(
    code: ErrorCode.methodNotFound,
    message: 'Method not found: $method',
  ),
);

/// 便捷函数：构造一个 Internal error 响应。
RpcResponse jsonRpcInternalError(Object? detail) => RpcResponse.error(
  id: -1,
  error: RemoteError(
    code: ErrorCode.internalError,
    message: 'Internal error',
    detail: detail is Map<String, Object?> ? detail : const <String, Object?>{},
  ),
);

/// 把 [message] 编码为 LSP 风格分帧的字节（header + body）。
List<int> encodeFramed(RpcMessage message) {
  final body = utf8.encode(jsonEncode(message.toJson()));
  final header = utf8.encode('Content-Length: ${body.length}\r\n\r\n');
  return [...header, ...body];
}
