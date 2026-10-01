/// 直播频道排序偏好的持久化验证。
///
/// 盯住的是「重启后排序还在」以及「存的是名字而不是序号」—— 后者是这类枚举
/// 持久化最常见的坑：存序号时，中间插入一个档位就会把用户的「收藏优先」静默
/// 变成别的档位。
///
/// 刻意不引 `flutter_test`：排序偏好的读写是数据面的事，进程内垫片就能跑。
library;

import 'package:live/live.dart';
import 'package:mistream/application/live_sort_settings.dart';
import 'package:storage/storage.dart' as db;
import 'package:test/test.dart';

void main() {
  late db.AppDatabase database;
  late db.Repositories repositories;

  setUp(() {
    database = db.AppDatabase.inMemory();
    repositories = db.Repositories(database);
  });

  tearDown(() => database.close());

  test('从未设置过时是源顺序', () async {
    expect(
      await loadLiveChannelSort(repositories.settings),
      LiveChannelSortOrder.source,
    );
  });

  test('每个档位都能存进去再读回来', () async {
    for (final order in LiveChannelSortOrder.values) {
      await saveLiveChannelSort(repositories.settings, order);
      expect(
        await loadLiveChannelSort(repositories.settings),
        order,
        reason: '$order 存进去读不回来',
      );
    }
  });

  test('存的是枚举名而不是序号', () async {
    await saveLiveChannelSort(
      repositories.settings,
      LiveChannelSortOrder.favoritesFirst,
    );
    // 直接读原始字符串：一旦有人把它改成 `index`，这条会红。
    final raw = await repositories.settings.read(kLiveChannelSortKey, '');
    expect(raw, 'favoritesFirst');
    expect(int.tryParse(raw), isNull, reason: '存序号会在枚举增删档位后错位');
  });

  test('库里认不出的值回退到源顺序而不抛异常', () async {
    // 枚举改名、旧版本写入的值、手工改坏的库 —— 都走这一条。
    await repositories.settings.write(kLiveChannelSortKey, 'byPinyin');
    expect(
      await loadLiveChannelSort(repositories.settings),
      LiveChannelSortOrder.source,
    );
  });

  test('存的是数字形态的字符串也回退，不打不开直播页', () async {
    await repositories.settings.write(kLiveChannelSortKey, '42');
    expect(
      await loadLiveChannelSort(repositories.settings),
      LiveChannelSortOrder.source,
    );
  });

  test('空串回退到源顺序', () async {
    await repositories.settings.write(kLiveChannelSortKey, '');
    expect(
      await loadLiveChannelSort(repositories.settings),
      LiveChannelSortOrder.source,
    );
  });
}
