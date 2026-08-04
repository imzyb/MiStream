import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('AppError.from', () {
    test('已经是 AppError 就原样返回，不套娃', () {
      const original = LocalError(
        code: ErrorCode.dbOpenFailed,
        message: '打不开',
      );

      expect(AppError.from(original), same(original));
    });

    test('映射已知的核心异常', () {
      expect(
        AppError.from(TimeoutException('超时')).code,
        ErrorCode.timeout,
      );
      expect(
        AppError.from(ArgumentError('参数错')).code,
        ErrorCode.invalidArgument,
      );
      expect(
        AppError.from(StateError('状态错')).code,
        ErrorCode.invalidState,
      );
      expect(
        AppError.from(const FormatException('格式错')).code,
        ErrorCode.invalidArgument,
      );
      expect(
        AppError.from(UnsupportedError('不支持')).code,
        ErrorCode.unsupportedPlatform,
      );
    });

    test('陌生异常落到 unknown，并保留原始异常与堆栈', () {
      final stackTrace = StackTrace.current;
      final error = Exception('说不清');
      final appError = AppError.from(error, stackTrace);

      expect(appError.code, ErrorCode.unknown);
      expect(appError.cause, same(error));
      expect(appError.stackTrace, same(stackTrace));
      expect(appError, isA<LocalError>());
    });
  });

  group('retryable', () {
    test('未显式指定时取错误码的默认判断', () {
      const error = LocalError(
        code: ErrorCode.updateDownloadFailed,
        message: '下载断了',
      );

      expect(error.retryable, isTrue);
    });

    test('显式指定时覆盖默认判断', () {
      const error = LocalError(
        code: ErrorCode.updateDownloadFailed,
        message: '磁盘满了，重试也没用',
        retryable: false,
      );

      expect(error.retryable, isFalse);
    });
  });

  group('语义判定', () {
    test('EMPTY_RESULT 是空而不是失败', () {
      const empty = RemoteError(
        code: ErrorCode.emptyResult,
        message: '没搜到',
      );

      expect(empty.isEmpty, isTrue);
      expect(empty.isCancelled, isFalse);
    });

    test('两侧的取消码都算取消', () {
      const local = LocalError.cancelled();
      const remote = RemoteError(
        code: ErrorCode.requestCancelled,
        message: '被取消',
      );

      expect(local.isCancelled, isTrue);
      expect(remote.isCancelled, isTrue);
    });
  });

  group('RemoteError.fromRpc', () {
    test('解出 data 里的诊断字段', () {
      final error = RemoteError.fromRpc(const {
        'code': -32101,
        'message': "TypeError: Cannot read property 'url' of undefined",
        'data': {
          'instanceId': 'site-12',
          'method': 'spider.detail',
          'stack': 'at parseDetail (index.js:88:20)',
          'elapsedMs': 340,
          'retryable': false,
        },
      });

      expect(error.code, ErrorCode.scriptRuntimeError);
      expect(error.instanceId, 'site-12');
      expect(error.method, 'spider.detail');
      expect(error.remoteStack, 'at parseDetail (index.js:88:20)');
      expect(error.elapsed, const Duration(milliseconds: 340));
      expect(error.retryable, isFalse);
    });

    test('data 里的 retryable 能覆盖错误码的默认判断', () {
      final error = RemoteError.fromRpc(const {
        'code': -32213,
        'message': '502 Bad Gateway',
        'data': {'status': 502, 'retryable': true},
      });

      // HTTP_ERROR 默认不可重试，网络层按 5xx 覆盖成可重试。
      expect(ErrorCode.httpError.retryable, isFalse);
      expect(error.retryable, isTrue);
    });

    test('未知错误码不抛异常，合成占位码后照常走错误路径', () {
      final error = RemoteError.fromRpc(const {
        'code': -32198,
        'message': '来自更新版运行时的新错误',
      });

      expect(error.code.value, -32198);
      expect(error.code.band, ErrorBand.spider);
      expect(error.retryable, isFalse);
    });

    test('缺字段或类型不对时降级，不崩', () {
      final error = RemoteError.fromRpc(const {'data': 'not-a-map'});

      expect(error.code, ErrorCode.internalError);
      expect(error.message, isEmpty);
      expect(error.detail, isEmpty);
      expect(error.instanceId, isNull);
    });

    test('toRpcJson 能把解出来的东西原样编回去', () {
      const source = {
        'code': -32102,
        'message': '脚本超时',
        'data': {
          'instanceId': 'site-3',
          'method': 'spider.search',
          'stack': 'at search (index.js:12:1)',
          'elapsedMs': 8000,
          'retryable': true,
        },
      };

      final encoded = RemoteError.fromRpc(source).toRpcJson();

      expect(encoded['code'], -32102);
      expect(encoded['message'], '脚本超时');
      expect(encoded['data'], source['data']);
    });
  });
}
