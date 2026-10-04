/// 直播 EPG 模板的持久化。
///
/// 为什么需要单独存一份：`epg` 模板来自配置的 `lives[]`，而**配置原文不入库**
/// （`config_sources` 只存 URL 与哈希）。不存的话重启后 EPG 就没了 —— 用户
/// 只会在「刚导入配置」那一次会话里看到节目单，之后永远是空的，很难往
/// 「模板没持久化」上想。
library;

import 'package:storage/storage.dart';

/// EPG 模板列表的设置键。
///
/// 直接存 JSON 数组（而不是把数组再编码成字符串），这样 `value_json` 列里就是
/// 一个可读的数组，用 `sqlite3` 手工排查时不用解两层。
final SettingKey<List<String>> kLiveEpgTemplatesKey = SettingKey<List<String>>(
  'live.epg_templates',
  (json) => json is List ? json.whereType<String>().toList() : const [],
  (value) => value,
);

/// 读取已保存的 EPG 模板。
///
/// 解析不出来时返回空列表而**不抛异常**：这条设置是可选增强，库里的脏数据
/// 不该让启动失败（`SettingsDao.read` 内部会对 `value_json` 直接
/// `jsonDecode`，值坏掉时会抛 `FormatException`）。
Future<List<String>> loadLiveEpgTemplates(SettingsDao settings) async {
  try {
    final values = await settings.read(kLiveEpgTemplatesKey, const <String>[]);
    return _clean(values);
  } on Object {
    return const [];
  }
}

/// 保存 EPG 模板（去重、丢空白、保序）。
Future<void> saveLiveEpgTemplates(
  SettingsDao settings,
  List<String> templates,
) => settings.write(kLiveEpgTemplatesKey, _clean(templates));

/// 去重 + 丢空白，保持配置里的先后顺序。
List<String> _clean(List<String> raw) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in raw) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    if (seen.add(trimmed)) result.add(trimmed);
  }
  return result;
}
