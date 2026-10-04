/// 「减少动效」开关的持有者：改了立刻通知整棵树。
library;

import 'package:flutter/widgets.dart';
import 'package:storage/storage.dart';

/// 持久化键。
final reduceMotionKey = SettingKey<bool>(
  'reduce_motion',
  (json) => json! as bool,
  (value) => value,
);

/// 「减少动效」开关。
///
/// docs/09-UI规范.md §2.4 要求：开启后所有动效降为 0ms，**同时**响应系统的
/// 无障碍设置。两者是「或」的关系，合成在 `MiStreamApp` 的 builder 里——只有
/// 那里同时够得到用户开关与 `MediaQuery`。
///
/// 为什么和 `ThemeController` 分开：外观是审美选择，这个是无障碍选项。合成
/// 成一个「外观设置」会让「我只想关动效、但保留深色」表达不出来。
///
/// 也正因为它是无障碍选项，主题包**不许**设置它（`theme_engine` 会把
/// `motion.reduceMotion` 当未知键拒掉）。
class MotionController extends ValueNotifier<bool> {
  MotionController._(this._settings, bool initial) : super(initial);

  final SettingsDao _settings;

  /// 从库里读出已保存的开关；读不到就默认**不**减少动效。
  ///
  /// 默认关而不是开：规范说的是「提供一个开关」，没有说默认打开。默认打开会
  /// 让第一次启动的界面显得生硬，而想关动效的用户本来就会去无障碍设置里关。
  static Future<MotionController> load(SettingsDao settings) async {
    final value = await settings.read(reduceMotionKey, false);
    return MotionController._(settings, value);
  }

  /// 开关：先改内存让 UI 这一帧就跟上，再落库。
  ///
  /// 参数写成具名：位置 `bool` 会被 `avoid_positional_boolean_parameters` 判为
  /// 告警，而且 `set(value: true)` 在调用点也比裸 `set(true)` 说得清。
  Future<void> set({required bool value}) async {
    if (value == this.value) return;
    this.value = value;
    await _settings.write(reduceMotionKey, value);
  }
}

/// 把 [MotionController] 下发到整棵树。
class MotionScope extends InheritedNotifier<MotionController> {
  const MotionScope({
    required super.notifier,
    required super.child,
    super.key,
  });

  /// 取最近的 [MotionController]，并注册依赖。**只在 `build` 里用**。
  static MotionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MotionScope>();
    assert(scope?.notifier != null, '找不到 MotionScope，检查 MiStreamApp 是否在树上');
    return scope!.notifier!;
  }

  /// 取 [MotionController] 但**不**注册依赖。**事件回调里用这个**。
  static MotionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MotionScope>();
    assert(scope?.notifier != null, '找不到 MotionScope，检查 MiStreamApp 是否在树上');
    return scope!.notifier!;
  }
}
