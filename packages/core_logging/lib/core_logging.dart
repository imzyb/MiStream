/// MiStream 结构化日志的公共 API。
///
/// 落盘格式与字段见 `docs/10-开发规范.md` §9；脱敏为什么做成不可绕过，见
/// `README.md`。
library;

export 'package:core_logging/src/jsonl_file_sink.dart';
export 'package:core_logging/src/log_level.dart';
export 'package:core_logging/src/log_record.dart';
export 'package:core_logging/src/log_sink.dart';
export 'package:core_logging/src/logger.dart';
export 'package:core_logging/src/redactor.dart';
