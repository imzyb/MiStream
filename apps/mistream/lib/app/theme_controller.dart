/// 外观选择的持有者：改了立刻通知整棵 widget 树重建主题。
library;

import 'package:flutter/widgets.dart';
import 'package:storage/storage.dart';
import 'package:theme_engine/theme_engine.dart';

/// 持久化键。存的是 [AppThemeChoice.index]。
///
/// 这个键从 `settings_page.dart` 搬过来——外观不再只是设置页自己的 state，
/// 树根也要读它，键的定义必须只有一处。
final themeModeKey = SettingKey<int>(
  'theme_mode',
  (json) => (json! as num).toInt(),
  (value) => value,
);

/// 当前生效的外观，以及「切换」这个动作。
///
/// 之所以要做成 [ValueNotifier] 而不是让设置页自己 setState：主题是整棵树
/// 的事，而 `MaterialApp` 在树根。设置页改一个局部 state 只能重画自己那一屏，
/// 结果就是「要重启才生效」——docs/09-UI规范.md §9 明确禁止。
class ThemeController extends ValueNotifier<AppThemeChoice> {
  ThemeController._(this._settings, AppThemeChoice initial) : super(initial);

  final SettingsDao _settings;

  /// 从库里读出已保存的外观；读不到用规范默认值（深色）。
  static Future<ThemeController> load(SettingsDao settings) async {
    final index = await settings.read(
      themeModeKey,
      AppThemeChoice.defaultChoice.index,
    );
    return ThemeController._(settings, AppThemeChoice.fromIndex(index));
  }

  /// 切换外观：先改内存让 UI 这一帧就跟上，再落库。
  ///
  /// 落库失败也不回滚内存值——用户选了什么就该是什么，库没写进去下次启动时
  /// 退回默认值，比「点了没反应」好解释。
  Future<void> set(AppThemeChoice choice) async {
    if (choice == value) return;
    value = choice;
    await _settings.write(themeModeKey, choice.index);
  }
}

/// 把 [ThemeController] 下发到整棵树。
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({required super.notifier, required super.child, super.key});

  /// 取最近的 [ThemeController]，并注册依赖。
  ///
  /// 这里用 `dependOn...` 而不是 `getInheritedWidgetOfExactType`：设置页要
  /// 跟着外观变化重建（选中项要跟着变），不像装配那样取到就不变了。
  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope?.notifier != null, '找不到 ThemeScope，检查 MiStreamApp 是否在树上');
    return scope!.notifier!;
  }
}
