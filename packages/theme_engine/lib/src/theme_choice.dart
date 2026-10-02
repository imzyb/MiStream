/// 用户的主题「选择」与「选择 → 具体主题」的解析。
library;

import 'package:theme_engine/src/theme.dart';

/// 设置页里可选的四种外观。
///
/// 与 [AppTheme] 不是一回事：[AppTheme] 是一套**已确定**的令牌，这里是用户
/// 的**选择**。`system` 要等运行时拿到系统明暗偏好才能定下用哪套，所以两者
/// 不能合并——`AppTheme.system` 那套令牌就是合并失败的残留，它其实只是
/// 「跟随系统、且系统此刻是浅色」时的取值。
enum AppThemeChoice {
  /// 跟随系统明暗。
  system,

  /// 亮色。
  light,

  /// 深色。
  dark,

  /// OLED 纯黑。
  ///
  /// 底色是纯 `#000000` 而非深灰，自发光屏上黑底不发光，既省电也没有灰底
  /// 漏光。代价是纯黑与卡片之间几乎没有明度差，边界只能靠 `outlineStrong`
  /// 撑住。
  oled;

  /// 规范指定的默认外观。
  ///
  /// docs/09-UI规范.md §9：内置「深色（默认）」。
  static const defaultChoice = AppThemeChoice.dark;

  /// 设置项标题。
  String get label => switch (this) {
    AppThemeChoice.system => '跟随系统',
    AppThemeChoice.light => '亮色',
    AppThemeChoice.dark => '深色',
    AppThemeChoice.oled => 'OLED 纯黑',
  };

  /// 设置项副标题。
  ///
  /// 写「选了会怎样」而不是复读标题——标题已经说了名字，副标题再写一遍
  /// 等于没写。
  String get description => switch (this) {
    AppThemeChoice.system => '随系统明暗自动切换',
    AppThemeChoice.light => '亮底深字',
    AppThemeChoice.dark => '深底浅字',
    AppThemeChoice.oled => '纯黑底，自发光屏更省电',
  };

  /// 是否要在系统层面强制走深色。
  ///
  /// Material 的 `ThemeMode` 只有三档，没有「OLED」这一档。OLED 是深色的
  /// 一个变体，只能靠强制 `ThemeMode.dark` + 换掉 `darkTheme` 实现。
  bool get forceDark =>
      this == AppThemeChoice.dark || this == AppThemeChoice.oled;

  /// 从持久化的 index 还原；越界或脏值回退到 [defaultChoice]。
  ///
  /// 存的是枚举 index，将来重排枚举顺序就会整体错位，所以这里必须判范围
  /// 而不是直接下标取值——否则一次重排会把所有用户打回默认值，还看不出
  /// 为什么。
  static AppThemeChoice fromIndex(int index) {
    if (index < 0 || index >= AppThemeChoice.values.length) {
      return defaultChoice;
    }
    return AppThemeChoice.values[index];
  }
}

/// 把用户选择解析成具体的 [AppTheme]。
///
/// [platformIsDark] 是系统当前的明暗偏好，只有 [AppThemeChoice.system] 用得到。
/// 分别以 `false` / `true` 调两次，就得到 `MaterialApp` 需要的明暗两套主题：
/// 选 `light` 时两次都是浅色，选 `oled` 时两次都是 OLED，`MaterialApp` 那边
/// 不必再 branch。
///
/// 收 `bool` 而不是 Flutter 的 `Brightness`，是为了让本包保持纯 Dart、解析
/// 逻辑能直接跑单测；接 Flutter 的转换放在 app 侧。
AppTheme resolveTheme(AppThemeChoice choice, {required bool platformIsDark}) =>
    switch (choice) {
      AppThemeChoice.system => platformIsDark ? AppTheme.dark : AppTheme.light,
      AppThemeChoice.light => AppTheme.light,
      AppThemeChoice.dark => AppTheme.dark,
      AppThemeChoice.oled => AppTheme.oled,
    };
