import 'package:drift/drift.dart';

/// UTC 毫秒整数 ↔ [DateTime] 的类型转换。
///
/// `docs/07-数据库设计.md` §1 约定：所有时间戳统一为 UTC 毫秒整数，不用本地时间、
/// 不用字符串。drift 默认把 `dateTime` 存成 Unix 秒，这里用转换器落成毫秒。
class UtcMillisConverter extends TypeConverter<DateTime, int> {
  /// 构造转换器。
  const UtcMillisConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}

/// 所有时间戳列共用同一个转换器实例。
const utcMillis = UtcMillisConverter();
