/// [AppResult] 与它的构造助手。
///
/// 单独一个文件，是为了让 `result.dart` 保持完全泛型、不认识 [AppError]——
/// 这样 `Result` 也能用在错误类型不是 [AppError] 的地方（比如解析器内部的
/// 中间结果）。
library;

import 'package:core_domain/src/error/app_error.dart';
import 'package:core_domain/src/error/result.dart';

/// 全项目默认的 `Result` 形态。
typedef AppResult<T> = Result<T, AppError>;

/// 执行 [action]，把抛出的异常收敛成 [AppError]。
///
/// 每一处调用外部世界（IO、第三方库、解码）的地方都该套上它，这是
/// `docs/10-开发规范.md` §3.4「禁止裸 catch」的正向表达：不是不许 catch，
/// 而是 catch 完必须转成带错误码的 [AppError]。
AppResult<T> guardApp<T>(T Function() action) =>
    Result.guard(action, onError: AppError.from);

/// [guardApp] 的异步版本。
Future<AppResult<T>> guardAppAsync<T>(Future<T> Function() action) =>
    Result.guardAsync(action, onError: AppError.from);
