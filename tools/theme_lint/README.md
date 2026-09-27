# theme_lint

主题包校验器。即 `docs/06-插件系统.md` §9 提到的 **`mistream theme lint`**，
供主题作者在本地提前发现「装上才被拒」的问题。

## 用法

```bash
# 直接校验
dart run tools/theme_lint/bin/theme_lint.dart path/to/theme.json

# 或走 melos
melos run theme:lint -- path/to/theme.json

# 从 stdin 读（配合编辑器/管道）
cat theme.json | dart run tools/theme_lint/bin/theme_lint.dart -

# 额外打印每对前景/背景的实测比值
dart run tools/theme_lint/bin/theme_lint.dart --ratios path/to/theme.json

# 指定叠加的基准主题（默认按包里的 brightness 推断）
dart run tools/theme_lint/bin/theme_lint.dart --base oled path/to/theme.json
```

退出码：`0` 通过 / `1` 存在 error / `64` 用法错误 / `66` 文件不存在。

## 校验内容

| 级别 | 内容 |
| --- | --- |
| error | 不是合法 JSON、清单根不是对象、缺 `id`、`type` 不是 `theme`、缺 `theme` / `theme.tokens`、**对比度不达标** |
| warning | 缺 `version`、未知 `color.*` / `motion.*` 令牌、非法令牌值、`brightness` 与底色矛盾、尺度/字体/动效令牌不合规 |
| info | 未覆盖的颜色令牌（会取基准主题的值） |

只有 error 会阻止加载；warning / info 只提示。

## 两条设计约束

**一、与运行时共用同一份断言。** 校验走的是 `theme_engine` 的
`contrastRules()` / `validateTheme()`，与 `loadThemePackage()` 完全一致——
本工具不另写一套规则。两套规则迟早会分叉，分叉的结果是 lint 说没问题、装上
却被拒。`test/theme_lint_test.dart` 里有一条用例拿同一份文本同时跑两边，
断言结论一致。

**二、只有对比度不达标才整包拒绝。** 圆角顺序反了、动效时长超过一秒，都不会
让界面不可读；整包回退却会把用户真正想改的那个圆角也丢掉。所以这类问题只
告警，**包里写的值照原样生效**（`font.scale` 是例外，它会被夹进 0.8×–1.5×）。
对比度是「不可读」，规范 §9 的硬红线，必须拒。

## `brightness` 自洽性检查为什么单独做

一套完整的深色配色，如果 `brightness` 抄成了 `light`，对比度断言**全过**
（配色本身是自洽的），光靠断言抓不到。危害在派生色：`isDark` 决定
`ColorScheme.fromSeed` 走哪套亮度，声明错了会让 secondary / tertiary / error
全取相反的变体，压在底色上。所以这里额外比一次「声明的明暗」与
`color.background` 的实际亮度。

## 未做

- **不校验字体是否存在**。Flutter 不提供字体枚举，做不到；运行时用优先级回退链
  兜底（见 `docs/09-UI规范.md` §2.3）。
- **不校验资源文件**（`theme.assets` 引用的图片）是否存在、是否超尺寸。
- 尚未落地的名字空间（如 `assets.*`）仍被静默忽略，不逐个告警。
