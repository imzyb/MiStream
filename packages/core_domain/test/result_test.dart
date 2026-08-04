import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  const ok = Result<int, String>.ok(2);
  const err = Result<int, String>.err('炸了');

  group('基本判定', () {
    test('isOk / isErr', () {
      expect(ok.isOk, isTrue);
      expect(ok.isErr, isFalse);
      expect(err.isErr, isTrue);
      expect(err.isOk, isFalse);
    });

    test('valueOrNull / errorOrNull', () {
      expect(ok.valueOrNull, 2);
      expect(ok.errorOrNull, isNull);
      expect(err.valueOrNull, isNull);
      expect(err.errorOrNull, '炸了');
    });

    test('模式匹配是穷尽的', () {
      String describe(Result<int, String> result) => switch (result) {
        Ok(:final value) => '成功 $value',
        Err(:final error) => '失败 $error',
      };

      expect(describe(ok), '成功 2');
      expect(describe(err), '失败 炸了');
    });
  });

  group('组合子', () {
    test('map 只作用于成功分支', () {
      expect(ok.map((v) => v * 3), const Ok<int, String>(6));
      expect(err.map((v) => v * 3), const Err<int, String>('炸了'));
    });

    test('mapErr 只作用于失败分支', () {
      expect(ok.mapErr((e) => e.length), const Ok<int, int>(2));
      expect(err.mapErr((e) => e.length), const Err<int, int>(2));
    });

    test('flatMap 遇错短路', () {
      var called = false;
      final result = err.flatMap<int>((v) {
        called = true;
        return Ok(v);
      });

      expect(called, isFalse);
      expect(result, const Err<int, String>('炸了'));
    });

    test('flatMap 串联成功分支', () {
      expect(
        ok.flatMap((v) => Result<String, String>.ok('值=$v')),
        const Ok<String, String>('值=2'),
      );
    });

    test('flatMapAsync', () async {
      expect(
        await ok.flatMapAsync((v) async => Result<int, String>.ok(v + 1)),
        const Ok<int, String>(3),
      );
      expect(
        await err.flatMapAsync((v) async => Result<int, String>.ok(v + 1)),
        const Err<int, String>('炸了'),
      );
    });

    test('fold 把两个分支归约到同一类型', () {
      expect(ok.fold((v) => 'v$v', (e) => 'e$e'), 'v2');
      expect(err.fold((v) => 'v$v', (e) => 'e$e'), 'e炸了');
    });

    test('getOrElse 能用错误值算替代值', () {
      expect(ok.getOrElse((e) => -1), 2);
      expect(err.getOrElse((e) => e.length), 2);
    });

    test('onOk / onErr 只在对应分支触发副作用', () {
      final touched = <String>[];

      ok.onOk((v) => touched.add('ok$v')).onErr((e) => touched.add('err$e'));
      err.onOk((v) => touched.add('ok$v')).onErr((e) => touched.add('err$e'));

      expect(touched, ['ok2', 'err炸了']);
    });
  });

  group('相等性', () {
    test('按内容比较', () {
      expect(const Ok<int, String>(1), const Ok<int, String>(1));
      expect(const Err<int, String>('x'), const Err<int, String>('x'));
      expect(const Ok<int, String>(1), isNot(const Ok<int, String>(2)));
      expect(const Ok<int, String>(1), isNot(const Err<int, String>('x')));
    });

    test('Ok(x) 与 Err(x) 不相等', () {
      expect(
        const Ok<String, String>('x'),
        isNot(const Err<String, String>('x')),
      );
    });
  });

  group('guard', () {
    test('正常返回值包成 Ok', () {
      expect(
        Result.guard(() => 7, onError: (e, s) => 'never'),
        const Ok<int, String>(7),
      );
    });

    test('异常经 onError 转成 Err，并带上堆栈', () {
      StackTrace? captured;
      final result = Result.guard<int, String>(
        () => throw StateError('坏了'),
        onError: (error, stackTrace) {
          captured = stackTrace;
          return error.toString();
        },
      );

      expect(result.isErr, isTrue);
      expect(result.errorOrNull, contains('坏了'));
      expect(captured, isNotNull);
    });

    test('guardAsync 捕获异步异常', () async {
      final result = await Result.guardAsync<int, String>(
        () async => throw TimeoutException('慢'),
        onError: (error, stackTrace) => 'caught',
      );

      expect(result, const Err<int, String>('caught'));
    });
  });

  group('guardApp', () {
    test('成功路径', () {
      expect(guardApp(() => 1).valueOrNull, 1);
    });

    test('异常收敛成带错误码的 AppError', () {
      final result = guardApp<int>(() => throw ArgumentError('参数错'));

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, ErrorCode.invalidArgument);
    });

    test('guardAppAsync 同理', () async {
      final result = await guardAppAsync<int>(
        () async => throw TimeoutException('超时'),
      );

      expect(result.errorOrNull?.code, ErrorCode.timeout);
      expect(result.errorOrNull?.retryable, isTrue);
    });
  });
}
