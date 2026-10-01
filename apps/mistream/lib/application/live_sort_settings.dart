/// 直播频道排序偏好的持久化。
///
/// 排序是「我习惯怎么看这份频道表」，重启后应该还在。存枚举名（`source` /
/// `byName` / `favoritesFirst`）而不是序号：序号在枚举增删档位后会错位，把
/// 用户的「收藏优先」静默变成别的档位。
library;

import 'package:live/live.dart';
import 'package:storage/storage.dart';

/// 直播频道排序的设置键。
final SettingKey<String> kLiveChannelSortKey = SettingKey.stringKey(
  'live.channel_sort',
);

/// 读取已保存的排序方式；读不出来时回退到源顺序。
///
/// 不抛异常：库里一条脏数据不该让直播页打不开。
Future<LiveChannelSortOrder> loadLiveChannelSort(SettingsDao settings) async {
  try {
    final name = await settings.read(kLiveChannelSortKey, '');
    return liveChannelSortOrderFromName(name);
  } on Object {
    return LiveChannelSortOrder.source;
  }
}

/// 保存排序方式。
Future<void> saveLiveChannelSort(
  SettingsDao settings,
  LiveChannelSortOrder order,
) => settings.write(kLiveChannelSortKey, order.name);

/// 排序偏好的读写入口。
///
/// 包一层类，而不是让页面直接拿 `SettingsDao`：Presentation 层不得 import
/// `storage`（`docs/10` §3.3，由 `tools/arch_check` 强制）。页面只需要「读
/// 一次、写一次」，不必知道底下是 SQLite。
class LiveSortPreference {
  /// 以设置 DAO 构造。
  LiveSortPreference(this._settings);

  final SettingsDao _settings;

  /// 读取当前排序方式。
  Future<LiveChannelSortOrder> load() => loadLiveChannelSort(_settings);

  /// 保存排序方式。
  Future<void> save(LiveChannelSortOrder order) =>
      saveLiveChannelSort(_settings, order);
}
