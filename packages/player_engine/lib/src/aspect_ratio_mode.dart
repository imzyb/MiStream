/// 画面比例模式。
library;

import 'package:meta/meta.dart';

/// 画面如何填充播放区。
///
/// 做成 sealed 而不是枚举，是因为「自定义比例」带参数。四个变体各自对应一组
/// 确定的 mpv 属性写入，映射写在各变体的文档里——这样二期换实现时，要对齐的
/// 是一张明确的属性表，而不是去猜某个封装库的 `BoxFit` 是怎么实现的。
@immutable
sealed class AspectRatioMode {
  const AspectRatioMode();

  /// 保持原始比例，完整显示（可能有黑边）。
  const factory AspectRatioMode.auto() = AutoAspectRatio;

  /// 保持比例并裁剪，填满播放区。
  const factory AspectRatioMode.fill() = FillAspectRatio;

  /// 拉伸到播放区，不保持比例。
  const factory AspectRatioMode.stretch() = StretchAspectRatio;

  /// 强制指定比例，如 16:9。
  const factory AspectRatioMode.ratio(int width, int height) =
      CustomAspectRatio;
}

/// 保持原始比例。
///
/// mpv：`keepaspect=yes`、`video-aspect-override=-1`、`panscan=0`。
@immutable
final class AutoAspectRatio extends AspectRatioMode {
  /// 构造。
  const AutoAspectRatio();

  @override
  bool operator ==(Object other) => other is AutoAspectRatio;

  @override
  int get hashCode => (AutoAspectRatio).hashCode;

  @override
  String toString() => 'AspectRatioMode.auto';
}

/// 保持比例并裁剪填满。
///
/// mpv：`panscan=1.0`。
@immutable
final class FillAspectRatio extends AspectRatioMode {
  /// 构造。
  const FillAspectRatio();

  @override
  bool operator ==(Object other) => other is FillAspectRatio;

  @override
  int get hashCode => (FillAspectRatio).hashCode;

  @override
  String toString() => 'AspectRatioMode.fill';
}

/// 拉伸填满，不保持比例。
///
/// mpv：`keepaspect=no`。
@immutable
final class StretchAspectRatio extends AspectRatioMode {
  /// 构造。
  const StretchAspectRatio();

  @override
  bool operator ==(Object other) => other is StretchAspectRatio;

  @override
  int get hashCode => (StretchAspectRatio).hashCode;

  @override
  String toString() => 'AspectRatioMode.stretch';
}

/// 强制指定比例。
///
/// mpv：`video-aspect-override=<width>/<height>`。
@immutable
final class CustomAspectRatio extends AspectRatioMode {
  /// 构造，[width] 与 [height] 必须为正。
  const CustomAspectRatio(this.width, this.height)
    : assert(width > 0 && height > 0, '比例的两个分量必须为正');

  /// 比例的宽分量。
  final int width;

  /// 比例的高分量。
  final int height;

  /// 写给 mpv `video-aspect-override` 的值。
  String get mpvValue => '$width/$height';

  @override
  bool operator ==(Object other) =>
      other is CustomAspectRatio &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'AspectRatioMode.ratio($width:$height)';
}
