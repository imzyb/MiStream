/// Spider 运行时结果编解码。
///
/// JsRuntimeAdapter 与 JvmRuntimeAdapter 原先各有一份手写的
/// `_jsonEncodeMap/_jsonEncodeList`，逻辑完全重复且未处理转义。
/// 抽到此处统一用 `dart:convert jsonEncode`，并归一化错误映射。
library;

import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:spider_host/src/runtime/http_runtime.dart';

/// 把 `SpiderHost.call` 的 `Result<Object?, AppError>` 转为
/// `Result<HttpResponseData, AppError>`。
Result<HttpResponseData, AppError> parseSpiderResult(
  Result<Object?, AppError> result,
) {
  return result.fold(
    (ok) {
      final body = _encodeBody(ok);
      return Ok(
        HttpResponseData(
          status: 200,
          headers: const {},
          body: body,
          finalUrl: '',
          elapsedMs: 0,
        ),
      );
    },
    Err.new,
  );
}

String _encodeBody(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  try {
    return jsonEncode(value);
  } on Object {
    return value.toString();
  }
}
