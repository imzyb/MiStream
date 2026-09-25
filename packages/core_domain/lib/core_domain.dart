/// MiStream 领域层的公共 API。
///
/// 这个包不依赖 Flutter，也不碰 IO——约束由 `tools/arch_check` 在 CI 中强制
/// 校验。详见 `README.md` 与 `docs/02-系统架构.md` §1。
library;

export 'package:core_domain/src/error/app_error.dart';
export 'package:core_domain/src/error/app_result.dart';
export 'package:core_domain/src/error/error_code.dart';
export 'package:core_domain/src/error/result.dart';
export 'package:core_domain/src/site/site_runtime.dart'
    show SiteRuntimeKind, classifySiteRuntime, kCspApiPrefix;
