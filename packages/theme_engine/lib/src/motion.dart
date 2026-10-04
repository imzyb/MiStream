/// 动效令牌，以及它们的校验。
///
/// 见 docs/09-UI规范.md §2.4。本文件保持纯 Dart——曲线在这里只是一个**名字**
/// （[MotionCurve]），到 app 层才由 `curveOf` 映射成 Flutter 的 `Curve`。
///
/// 为什么不像颜色那样直接存 `Color`、像字重那样直接用 `FontWeight` 一样存
/// `Curve`：`theme_engine` 一旦 import Flutter，这个包就只能跑在 `flutter test`
/// 下，而本环境 `flutter_tester` 起不来（widget 测试跑不了），等于把唯一能
/// 自动验证 UI 面的地方关掉。曲线名→曲线的映射只有 4 行，放 app 层不亏。
library;

import 'package:meta/meta.dart';

/// 规范 §2.4 用到的四条曲线。
///
/// 刻意只收规范列出的四条，不顺手加 `linear`：主题作者能选什么，应该是规范
/// 说了算。要加就走改规范那条路。
///
/// 枚举名即主题包 JSON 里写的字符串（`Curve.name`），改名等于破坏已发布的
/// 主题包，所以 [fromName] 对不认识的名字返回 `null` 让调用方告警，而不是
/// 悄悄退回默认值——作者会以为自己写的曲线生效了。
enum MotionCurve {
  /// 悬停、点击反馈。
  easeOut,

  /// 页面切换。
  easeInOutCubic,

  /// 抽屉、弹窗。
  easeOutCubic,

  /// 播放器控制栏淡入淡出。
  easeInOut;

  /// 解析主题包里的曲线名；不认识时返回 `null`。
  static MotionCurve? fromName(String value) {
    final trimmed = value.trim();
    for (final curve in values) {
      if (curve.name == trimmed) return curve;
    }
    return null;
  }
}

/// 一个动效场景：时长 + 曲线。
@immutable
class MotionSpec {
  /// 构造一个动效场景。
  const MotionSpec({required this.duration, required this.curve});

  /// 时长。开启「减少动效」后由 [DesignMotion.resolve] 压成零。
  final Duration duration;

  /// 曲线。
  final MotionCurve curve;

  /// 时长（毫秒）。主题包按毫秒读写，`toMap` 也用它。
  double get milliseconds => duration.inMicroseconds / 1000;

  /// 开启「减少动效」时的等价场景：时长归零，曲线保留。
  ///
  /// 0ms 下曲线没有实际作用，保留是为了让调用方少写一个分支——不必先判断
  /// 「是不是零」再决定取不取曲线。
  MotionSpec get collapsed => MotionSpec(duration: Duration.zero, curve: curve);

  /// 复制并覆盖部分字段。
  MotionSpec copyWith({Duration? duration, MotionCurve? curve}) => MotionSpec(
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
  );

  @override
  bool operator ==(Object other) =>
      other is MotionSpec && other.duration == duration && other.curve == curve;

  @override
  int get hashCode => Object.hash(duration, curve);

  @override
  String toString() => '${_msText(milliseconds)}ms ${curve.name}';
}

/// 动效令牌。
@immutable
class DesignMotion {
  /// 构造一套动效令牌。默认值即规范 §2.4 的表格。
  const DesignMotion({
    this.hover = const MotionSpec(
      duration: Duration(milliseconds: 120),
      curve: MotionCurve.easeOut,
    ),
    this.pageTransition = const MotionSpec(
      duration: Duration(milliseconds: 240),
      curve: MotionCurve.easeInOutCubic,
    ),
    this.overlay = const MotionSpec(
      duration: Duration(milliseconds: 200),
      curve: MotionCurve.easeOutCubic,
    ),
    this.playerControls = const MotionSpec(
      duration: Duration(milliseconds: 180),
      curve: MotionCurve.easeInOut,
    ),
    this.reduceMotion = false,
  });

  /// 规范默认值。
  static const standard = DesignMotion();

  /// 悬停、点击反馈。
  final MotionSpec hover;

  /// 页面切换。
  final MotionSpec pageTransition;

  /// 抽屉、弹窗。
  final MotionSpec overlay;

  /// 播放器控制栏淡入淡出。
  final MotionSpec playerControls;

  /// 是否开启「减少动效」。
  ///
  /// **主题包设置不了它**——这是用户偏好与系统无障碍设置的合成结果，由 app
  /// 层算好后 `copyWith` 进来。理由：一个主题不该替用户决定要不要关掉动效，
  /// 那是无障碍选项，不是审美选项。
  final bool reduceMotion;

  /// 时长上限（毫秒）。
  ///
  /// 超过一秒的微交互会被感知成「界面卡住了」而不是「有动效」。这个上限不是
  /// 规范里的数字，是本包加的护栏，写进 [validateMotion] 的提示里。
  static const maxMilliseconds = 1000.0;

  /// 场景名 → 场景。键名与主题包 JSON 一致，顺序即规范 §2.4 的表格顺序。
  Map<String, MotionSpec> get scenes => {
    'motion.hover': hover,
    'motion.pageTransition': pageTransition,
    'motion.overlay': overlay,
    'motion.playerControls': playerControls,
  };

  /// 应用「减少动效」后的实际场景。
  MotionSpec resolve(MotionSpec spec) => reduceMotion ? spec.collapsed : spec;

  /// 生效的悬停反馈。
  MotionSpec get effectiveHover => resolve(hover);

  /// 生效的页面切换。
  MotionSpec get effectivePageTransition => resolve(pageTransition);

  /// 生效的抽屉/弹窗。
  MotionSpec get effectiveOverlay => resolve(overlay);

  /// 生效的播放器控制栏。
  MotionSpec get effectivePlayerControls => resolve(playerControls);

  /// 复制并覆盖部分字段。
  DesignMotion copyWith({
    MotionSpec? hover,
    MotionSpec? pageTransition,
    MotionSpec? overlay,
    MotionSpec? playerControls,
    bool? reduceMotion,
  }) => DesignMotion(
    hover: hover ?? this.hover,
    pageTransition: pageTransition ?? this.pageTransition,
    overlay: overlay ?? this.overlay,
    playerControls: playerControls ?? this.playerControls,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  /// 序列化。键名与主题包 JSON 的键名一致——[ThemePackage] 能原样读回来，
  /// 这条不变式有测试钉住。
  Map<String, Object> toMap() => {
    for (final entry in scenes.entries) ...{
      entry.key: entry.value.milliseconds,
      '${entry.key}.curve': entry.value.curve.name,
    },
  };
}

/// 校验动效令牌，返回问题清单（空 = 通过）。
///
/// 与尺度、字体一样**只告警不拒绝**：动效配错了界面仍然可用可读，只是手感
/// 不对。回退整包反而是更差的选择。
List<String> validateMotion(DesignMotion m) {
  final problems = <String>[];

  for (final entry in m.scenes.entries) {
    final name = entry.key;
    final ms = entry.value.milliseconds;

    if (ms.isNaN) {
      problems.add('$name 不是合法数字');
    } else if (ms < 0) {
      problems.add('$name 不能为负（当前 ${_msText(ms)}ms）');
    } else if (ms > DesignMotion.maxMilliseconds) {
      problems.add(
        '$name ${_msText(ms)}ms 超过 ${_msText(DesignMotion.maxMilliseconds)}ms '
        '上限，这个时长会被感知成卡顿而不是动效',
      );
    } else if (ms == 0 && !m.reduceMotion) {
      // 「减少动效」关着却是 0ms，多半是漏填而不是有意为之。有意为之的话，
      // 用户打开开关就没有任何变化，看不出开关生效了。
      problems.add('$name 是 0ms，但未开启「减少动效」');
    }
  }

  return problems;
}

/// 毫秒的人读写法：整数不带小数点。
String _msText(double ms) =>
    ms == ms.roundToDouble() ? '${ms.round()}' : ms.toString();
