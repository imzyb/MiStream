/// 尺度与字体令牌，以及它们的校验。
///
/// 见 docs/09-UI规范.md §2.2 / §2.3。本文件保持纯 Dart——间距、圆角、字号都
/// 只是数字，不引 Flutter 才能在 `dart test` 下覆盖（widget 测试在本环境跑
/// 不了，这是唯一能自动验证 UI 面的地方）。
library;

import 'package:meta/meta.dart';

/// 间距、圆角与投影。
///
/// 间距一律是 [unit] 的整数倍（规范 §2.2：4/8/12/16/24/32/48）。**不要**在
/// 组件里写裸数字——断点变化时整套节奏会散。
@immutable
class DesignScale {
  const DesignScale({
    this.unit = 4,
    this.radiusSm = 4,
    this.radiusMd = 8,
    this.radiusLg = 16,
    this.radiusFull = 9999,
    this.elevationCard = 1,
    this.elevationDialog = 8,
    this.elevationOverlay = 16,
  });

  /// 规范默认值。
  static const standard = DesignScale();

  /// 间距基数。所有间距都应是它的整数倍。
  final double unit;

  /// 小圆角：标签、芯片。
  final double radiusSm;

  /// 中圆角：按钮、输入框、卡片。
  final double radiusMd;

  /// 大圆角：对话框、抽屉。
  final double radiusLg;

  /// 全圆角（胶囊）。
  final double radiusFull;

  /// 卡片投影。
  final double elevationCard;

  /// 对话框投影。
  final double elevationDialog;

  /// 浮层投影（播放器控制栏等）。
  final double elevationOverlay;

  /// [steps] 个单位的间距。`spacing(4)` = 16。
  double spacing(int steps) => unit * steps;

  /// 规范列出的那一档间距：4/8/12/16/24/32/48。
  static const steps = [1, 2, 3, 4, 6, 8, 12];

  DesignScale copyWith({
    double? unit,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusFull,
    double? elevationCard,
    double? elevationDialog,
    double? elevationOverlay,
  }) => DesignScale(
    unit: unit ?? this.unit,
    radiusSm: radiusSm ?? this.radiusSm,
    radiusMd: radiusMd ?? this.radiusMd,
    radiusLg: radiusLg ?? this.radiusLg,
    radiusFull: radiusFull ?? this.radiusFull,
    elevationCard: elevationCard ?? this.elevationCard,
    elevationDialog: elevationDialog ?? this.elevationDialog,
    elevationOverlay: elevationOverlay ?? this.elevationOverlay,
  );

  Map<String, double> toMap() => {
    'spacing.unit': unit,
    'radius.sm': radiusSm,
    'radius.md': radiusMd,
    'radius.lg': radiusLg,
    'radius.full': radiusFull,
    'elevation.card': elevationCard,
    'elevation.dialog': elevationDialog,
    'elevation.overlay': elevationOverlay,
  };
}

/// 一条字体样式：字号 + 字重。
@immutable
class TextStyleSpec {
  const TextStyleSpec({required this.size, required this.weight});

  /// 字号（逻辑像素）。
  final double size;

  /// 字重，100~900 的百位整数。
  final int weight;

  @override
  bool operator ==(Object other) =>
      other is TextStyleSpec && other.size == size && other.weight == weight;

  @override
  int get hashCode => Object.hash(size, weight);
}

/// 字体令牌。
@immutable
class DesignTypography {
  const DesignTypography({
    this.display = const TextStyleSpec(size: 28, weight: 600),
    this.title = const TextStyleSpec(size: 20, weight: 600),
    this.subtitle = const TextStyleSpec(size: 16, weight: 500),
    this.body = const TextStyleSpec(size: 14, weight: 400),
    this.caption = const TextStyleSpec(size: 12, weight: 400),
    this.family,
    this.fallback = defaultFallback,
    this.scale = 1,
  });

  /// 规范默认值。
  static const standard = DesignTypography();

  /// 规范 §2.3 的字体族优先级。
  ///
  /// 排序按规范给的原样，不按平台重排：`Microsoft YaHei UI` 放在最前，它同时
  /// 覆盖中英文，Windows 上不会出现「中文回退到某个衬线体」的观感。
  static const defaultFallback = [
    'Microsoft YaHei UI',
    'Segoe UI',
    'PingFang SC',
    'SF Pro',
    'Noto Sans CJK',
  ];

  /// 页面主标题。
  final TextStyleSpec display;

  /// 区块标题。
  final TextStyleSpec title;

  /// 卡片标题。
  final TextStyleSpec subtitle;

  /// 正文。
  final TextStyleSpec body;

  /// 说明、角标。
  final TextStyleSpec caption;

  /// 主字体族；`null` 表示用平台默认。
  final String? family;

  /// 回退字体族，按优先级排列。
  final List<String> fallback;

  /// 字号缩放系数。
  ///
  /// 这是**主题自己的**缩放，会叠加在系统字号缩放之上。规范 §231 要求支持
  /// 0.8×–1.5×，所以 [effectiveScale] 会把它夹进这个区间——主题包写 3.0 也
  /// 只会得到 1.5，不至于把界面撑爆。
  final double scale;

  /// 规范 §231 的下限。
  static const minScale = 0.8;

  /// 规范 §231 的上限。
  static const maxScale = 1.5;

  /// 夹进规范区间后的缩放系数。
  double get effectiveScale => scale.clamp(minScale, maxScale);

  /// 字号阶梯，从大到小。校验靠它。
  List<TextStyleSpec> get ladder => [display, title, subtitle, body, caption];

  DesignTypography copyWith({
    TextStyleSpec? display,
    TextStyleSpec? title,
    TextStyleSpec? subtitle,
    TextStyleSpec? body,
    TextStyleSpec? caption,
    String? family,
    List<String>? fallback,
    double? scale,
  }) => DesignTypography(
    display: display ?? this.display,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    body: body ?? this.body,
    caption: caption ?? this.caption,
    family: family ?? this.family,
    fallback: fallback ?? this.fallback,
    scale: scale ?? this.scale,
  );

  Map<String, Object?> toMap() => {
    'font.display': display.size,
    'font.title': title.size,
    'font.subtitle': subtitle.size,
    'font.body': body.size,
    'font.caption': caption.size,
    'font.family': family,
    'font.scale': scale,
  };
}

/// 校验尺度令牌，返回问题清单（空 = 通过）。
///
/// 主题包是用户数据，错了不能抛异常把加载链路打断——收集成清单交给调用方
/// 告警。圆角与投影的顺序不是审美偏好：`radiusFull` 小于 `radiusLg` 会让
/// 「胶囊」比「对话框」还方，那是明确的配置错误。
List<String> validateScale(DesignScale s) {
  final problems = <String>[];
  void positive(String name, double v) {
    if (v.isNaN || v <= 0) problems.add('$name 必须是正数（当前 $v）');
  }

  void nonNegative(String name, double v) {
    if (v.isNaN || v < 0) problems.add('$name 不能为负（当前 $v）');
  }

  positive('spacing.unit', s.unit);
  nonNegative('radius.sm', s.radiusSm);
  nonNegative('radius.md', s.radiusMd);
  nonNegative('radius.lg', s.radiusLg);
  nonNegative('radius.full', s.radiusFull);

  if (!(s.radiusSm <= s.radiusMd && s.radiusMd <= s.radiusLg)) {
    problems.add(
      '圆角必须单调递增：sm ${s.radiusSm} / md ${s.radiusMd} / lg ${s.radiusLg}',
    );
  }
  if (s.radiusFull < s.radiusLg) {
    problems.add('radius.full(${s.radiusFull}) 不能小于 radius.lg(${s.radiusLg})');
  }

  nonNegative('elevation.card', s.elevationCard);
  nonNegative('elevation.dialog', s.elevationDialog);
  nonNegative('elevation.overlay', s.elevationOverlay);
  if (!(s.elevationCard <= s.elevationDialog &&
      s.elevationDialog <= s.elevationOverlay)) {
    problems.add(
      '投影必须单调递增：card ${s.elevationCard} / '
      'dialog ${s.elevationDialog} / overlay ${s.elevationOverlay}',
    );
  }
  return problems;
}

/// 校验字体令牌，返回问题清单（空 = 通过）。
List<String> validateTypography(DesignTypography t) {
  final problems = <String>[];

  const names = [
    'font.display',
    'font.title',
    'font.subtitle',
    'font.body',
    'font.caption',
  ];
  final ladder = t.ladder;
  for (var i = 0; i < ladder.length; i++) {
    final spec = ladder[i];
    if (spec.size.isNaN || spec.size <= 0) {
      problems.add('${names[i]} 字号必须是正数（当前 ${spec.size}）');
    }
    if (spec.weight < 100 || spec.weight > 900 || spec.weight % 100 != 0) {
      problems.add('${names[i]} 字重必须是 100~900 的百位整数（当前 ${spec.weight}）');
    }
    if (i > 0 && spec.size >= ladder[i - 1].size) {
      problems.add(
        '字号必须逐级递减：${names[i - 1]} ${ladder[i - 1].size} '
        '→ ${names[i]} ${spec.size}',
      );
    }
  }

  if (t.scale.isNaN) {
    problems.add('font.scale 不是合法数字');
  } else if (t.scale < DesignTypography.minScale ||
      t.scale > DesignTypography.maxScale) {
    // 不算致命：effectiveScale 会夹住。但要说出来，否则主题作者会以为自己
    // 写的 1.8 生效了。
    problems.add(
      'font.scale ${t.scale} 超出规范区间 '
      '${DesignTypography.minScale}~${DesignTypography.maxScale}，将被夹住',
    );
  }

  if (t.family != null && t.family!.trim().isEmpty) {
    problems.add('font.family 不能是空字符串');
  }
  return problems;
}
