import 'dart:convert';

import 'package:storage/src/database/database.dart';

/// 一个类型安全的设置键：绑定一个唯一 [key]（`setting.key` 主键）与值的
/// Dart 类型，并提供独立的编解码方式。
///
/// 应用所有设置项都声明为全局 [SettingKey] 常量（见
/// `docs/07-数据库设计.md` §3.11），避免散落的字符串 key 拼写错误。
class SettingKey<T> {
  /// 一般通过静态工厂（如 [SettingKey.stringKey]）构造，确保类型匹配。
  const SettingKey(this.key, this.decode, this.encode);

  /// 唯一键名，即 `setting.key` 主键。
  final String key;

  /// 把 `value_json` 反序列化出的 JSON 值还原为对应类型。
  final T Function(Object? json) decode;

  /// 把值序列化为可 JSON 编码的形式。
  final Object? Function(T value) encode;

  /// JSON 字符串键。
  static SettingKey<String> stringKey(String key) =>
      SettingKey<String>(key, _asString, (v) => v);

  /// JSON 布尔键。
  static SettingKey<bool> boolKey(String key) =>
      SettingKey<bool>(key, _asBool, (v) => v);

  /// JSON 整数键。
  static SettingKey<int> intKey(String key) =>
      SettingKey<int>(key, _asInt, (v) => v);

  /// JSON 双精度数键。
  static SettingKey<double> doubleKey(String key) =>
      SettingKey<double>(key, _asDouble, (v) => v);

  /// JSON 数值（int 或 double）键。
  static SettingKey<num> numKey(String key) =>
      SettingKey<num>(key, _asNum, (v) => v);

  static String _asString(Object? v) => v! as String;
  static bool _asBool(Object? v) => v! as bool;
  static int _asInt(Object? v) => v! as int;
  static double _asDouble(Object? v) => (v! as num).toDouble();
  static num _asNum(Object? v) => v! as num;
}

/// `setting` 表的类型安全 KV 访问。
///
/// 值一律以 JSON 存 `value_json` 列；这里负责 encode/decode + 维护
/// `updated_at`，上层拿到的永远是类型对应的值。
class SettingsDao {
  /// 持有底层数据库连接。
  SettingsDao(this.db);

  /// 底层数据库连接。
  final AppDatabase db;

  /// 读取设置；键不存在时返回 [fallback]。
  Future<T> read<T>(SettingKey<T> key, T fallback) async {
    final row = await (db.select(
      db.settings,
    )..where((t) => t.key.equals(key.key))).getSingleOrNull();
    if (row == null) return fallback;

    return key.decode(jsonDecode(row.valueJson));
  }

  /// 读取设置；键不存在时抛 [StateError]。
  Future<T> readRequired<T>(SettingKey<T> key) async {
    final row = await (db.select(
      db.settings,
    )..where((t) => t.key.equals(key.key))).getSingleOrNull();
    if (row == null) {
      throw StateError('Missing required setting: ${key.key}');
    }
    return key.decode(jsonDecode(row.valueJson));
  }

  /// 写入（覆盖）一项设置，同步更新时间戳。
  Future<void> write<T>(SettingKey<T> key, T value) async {
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: key.key,
            valueJson: jsonEncode(key.encode(value)),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// 删除一项设置。
  Future<void> remove(SettingKey<Object?> key) async {
    await (db.delete(db.settings)..where((t) => t.key.equals(key.key))).go();
  }
}
