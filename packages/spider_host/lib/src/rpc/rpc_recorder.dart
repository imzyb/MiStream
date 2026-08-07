/// RPC 录制与回放工具。
///
/// docs/08-RPC协议.md §9。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

import 'package:spider_host/src/rpc/stdio_rpc_channel.dart';

/// 一条录制的 RPC 事件。
class RpcRecordEvent {
  final int timestamp;
  final String direction;
  final String type;
  final int? id;
  final String? method;
  final Object? result;
  final int? errorCode;
  final String? errorMessage;
  final Map<String, Object?>? params;

  const RpcRecordEvent({
    required this.timestamp,
    required this.direction,
    required this.type,
    this.id,
    this.method,
    this.result,
    this.errorCode,
    this.errorMessage,
    this.params,
  });

  Map<String, Object?> toJson() => {
    'ts': timestamp,
    'direction': direction,
    'type': type,
    if (id != null) 'id': id,
    if (method != null) 'method': method,
    if (result != null) 'result': result,
    if (errorCode != null) 'errorCode': errorCode,
    if (errorMessage != null) 'errorMessage': errorMessage,
    if (params != null) 'params': params,
  };

  factory RpcRecordEvent.fromJson(Map<String, Object?> json) => RpcRecordEvent(
    timestamp: (json['ts'] as num).toInt(),
    direction: json['direction'] as String,
    type: json['type'] as String,
    id: json['id'] as int?,
    method: json['method'] as String?,
    result: json['result'],
    errorCode: json['errorCode'] as int?,
    errorMessage: json['errorMessage'] as String?,
    params: json['params'] as Map<String, Object?>?,
  );
}

/// 录制 RPC 会话。
class RpcRecorder {
  final List<RpcRecordEvent> events = [];

  void record(Map<String, Object?> msg, String direction) {
    final type = msg.containsKey('method')
        ? (msg.containsKey('id') ? 'request' : 'notification')
        : msg.containsKey('error')
        ? 'error'
        : 'response';

    final rawParams = msg['params'];
    final params = rawParams is Map
        ? Map<String, Object?>.from(rawParams)
        : null;

    final rawError = msg['error'];
    final errorMap = rawError is Map
        ? Map<String, Object?>.from(rawError)
        : null;

    events.add(
      RpcRecordEvent(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        direction: direction,
        type: type,
        id: msg['id'] as int?,
        method: msg['method'] as String?,
        result: msg['result'],
        errorCode: errorMap?['code'] as int?,
        errorMessage: errorMap?['message'] as String?,
        params: params,
      ),
    );
  }

  Future<void> saveToFile(String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    for (final event in events) {
      sink.writeln(jsonEncode(event.toJson()));
    }
    await sink.flush();
    await sink.close();
  }

  static Future<List<RpcRecordEvent>> loadFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return [];
    final lines = await file.readAsLines();
    return lines
        .where((l) => l.trim().isNotEmpty)
        .map(
          (l) => RpcRecordEvent.fromJson(
            jsonDecode(l) as Map<String, Object?>,
          ),
        )
        .toList();
  }
}

/// 带录制功能的 RPC 通道。
///
/// 包装 [StdioRpcChannel]，记录所有收发消息，不干扰正常通信。
class RecordingRpcChannel {
  final StdioRpcChannel channel;
  final RpcRecorder recorder;

  RecordingRpcChannel(this.channel, this.recorder);

  Future<Result<Object?, RemoteError>> call(
    String method, {
    Map<String, Object?> params = const {},
    Duration? timeout,
  }) async {
    recorder.record(<String, Object?>{
      'method': method,
      'params': params,
    }, 'send');
    final result = await channel.call(method, params: params, timeout: timeout);
    result.fold(
      (value) => recorder.record(<String, Object?>{'result': value}, 'recv'),
      (error) => recorder.record(<String, Object?>{
        'error': <String, Object?>{
          'code': error.code.value,
          'message': error.message,
        },
      }, 'recv'),
    );
    return result;
  }

  Future<void> notify(String method, {Map<String, Object?> params = const {}}) {
    recorder.record(<String, Object?>{
      'method': method,
      'params': params,
    }, 'send');
    return channel.notify(method, params: params);
  }
}

/// RPC 回放器。
class RpcReplayer {
  final List<RpcRecordEvent> events;
  int _index = 0;
  int injectDelayMs = 0;
  final Set<String> injectErrorMethods = {};

  RpcReplayer(this.events);

  static Future<RpcReplayer> fromFile(String filePath) async {
    final events = await RpcRecorder.loadFromFile(filePath);
    return RpcReplayer(events);
  }

  /// 查找下一个匹配的响应。
  Future<Object?> findResponse(
    String method,
    Map<String, Object?> params,
  ) async {
    while (_index < events.length) {
      final event = events[_index];
      _index++;

      if (event.direction == 'send' &&
          event.type == 'request' &&
          event.method == method) {
        if (injectDelayMs > 0) {
          await Future<void>.delayed(Duration(milliseconds: injectDelayMs));
        }

        if (injectErrorMethods.contains(method)) {
          return RemoteError(
            code: ErrorCode.scriptRuntimeError,
            message: '注入错误: $method',
          );
        }

        // 找后续的 response
        for (var j = _index; j < events.length; j++) {
          final resp = events[j];
          if (resp.direction == 'recv' &&
              (resp.type == 'response' || resp.type == 'error') &&
              resp.id == event.id) {
            _index = j + 1;
            if (resp.type == 'error') {
              return RemoteError(
                code: ErrorCode.resolve(
                  resp.errorCode ?? ErrorCode.internalError.value,
                ),
                message: resp.errorMessage ?? '',
              );
            }
            return resp.result;
          }
        }
        return null;
      }
    }
    return null;
  }
}
