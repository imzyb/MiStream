/// `Result<T, E>`：把可预期的失败编进类型里。
///
/// `docs/10-开发规范.md` §3.4 要求领域层不用异常做控制流。理由在聚合搜索上最
/// 明显：几十个源并发查询，个别源超时、返回畸形数据、脚本抛错，都是**正常**
/// 情况。用异常表达就得在每一层写 `try/catch`，漏写一处就是崩溃；用 `Result`
/// 表达，编译器会在你忘记处理失败分支时提醒你。
///
/// 真正的编程错误（断言失败、非法状态、不该发生的分支）仍然 `throw`。
library;

import 'package:meta/meta.dart';

/// 一次可能失败的计算的结果：要么 [Ok]，要么 [Err]。
@immutable
sealed class Result<T, E> {
  /// 供子类调用。
  const Result();

  /// 成功。
  const factory Result.ok(T value) = Ok<T, E>;

  /// 失败。
  const factory Result.err(E error) = Err<T, E>;

  /// 执行 [action]，把抛出的异常经 [onError] 转成 [Err]。
  ///
  /// 这是「外部世界的异常」进入领域层的唯一入口。传 `AppError.from` 就能得到
  /// 一个 `AppResult<T>`。
  static Result<T, E> guard<T, E>(
    T Function() action, {
    required E Function(Object error, StackTrace stackTrace) onError,
  }) {
    try {
      return Ok(action());
    } on Object catch (error, stackTrace) {
      return Err(onError(error, stackTrace));
    }
  }

  /// [guard] 的异步版本。
  static Future<Result<T, E>> guardAsync<T, E>(
    Future<T> Function() action, {
    required E Function(Object error, StackTrace stackTrace) onError,
  }) async {
    try {
      return Ok(await action());
    } on Object catch (error, stackTrace) {
      return Err(onError(error, stackTrace));
    }
  }

  /// 是否成功。
  bool get isOk => this is Ok<T, E>;

  /// 是否失败。
  bool get isErr => this is Err<T, E>;

  /// 成功值，失败时为 `null`。
  ///
  /// `T` 本身可空时无法区分「失败」与「成功但值为 null」，那种场景请用
  /// [fold] 或模式匹配。
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// 错误值，成功时为 `null`。
  E? get errorOrNull => switch (this) {
    Ok() => null,
    Err(:final error) => error,
  };

  /// 两个分支都归约到同一个类型。
  R fold<R>(R Function(T value) onOk, R Function(E error) onErr) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final error) => onErr(error),
      };

  /// 变换成功值，失败原样透传。
  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final error) => Err(error),
  };

  /// 变换错误值，成功原样透传。
  ///
  /// 用于跨层转换错误类型，比如把 `RemoteError` 换成带上下文的 `LocalError`。
  Result<T, F> mapErr<F>(F Function(E error) transform) => switch (this) {
    Ok(:final value) => Ok(value),
    Err(:final error) => Err(transform(error)),
  };

  /// 串联下一步计算，失败则短路。
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform) =>
      switch (this) {
        Ok(:final value) => transform(value),
        Err(:final error) => Err(error),
      };

  /// [flatMap] 的异步版本。
  Future<Result<R, E>> flatMapAsync<R>(
    Future<Result<R, E>> Function(T value) transform,
  ) async => switch (this) {
    Ok(:final value) => await transform(value),
    Err(:final error) => Err(error),
  };

  /// 取成功值，失败时用 [orElse] 由错误算出一个替代值。
  T getOrElse(T Function(E error) orElse) => switch (this) {
    Ok(:final value) => value,
    Err(:final error) => orElse(error),
  };

  /// 成功时执行副作用，返回自身以便链式调用。
  Result<T, E> onOk(void Function(T value) action) {
    if (this case Ok(:final value)) action(value);
    // ignore: avoid_returning_this — 链式调用正是这个方法存在的理由
    return this;
  }

  /// 失败时执行副作用，返回自身以便链式调用。
  Result<T, E> onErr(void Function(E error) action) {
    if (this case Err(:final error)) action(error);
    // ignore: avoid_returning_this — 同 onOk，返回 void 就接不上链子了
    return this;
  }
}

/// 成功。
final class Ok<T, E> extends Result<T, E> {
  /// 包装一个成功值。
  const Ok(this.value);

  /// 成功值。
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T, E> && other.value == value);

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// 失败。
final class Err<T, E> extends Result<T, E> {
  /// 包装一个错误值。
  const Err(this.error);

  /// 错误值。
  final E error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T, E> && other.error == error);

  @override
  int get hashCode => Object.hash(Err, error);

  @override
  String toString() => 'Err($error)';
}
