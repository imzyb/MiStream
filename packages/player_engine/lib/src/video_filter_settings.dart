/// 画面滤镜参数。
library;

import 'package:meta/meta.dart';

/// 亮度 / 对比度 / 饱和度 / 伽马。
///
/// 取值范围沿用 mpv 的 `-100 ~ 100`，0 为不改变。不归一化到 `-1.0 ~ 1.0`：
/// 归一化看着漂亮，但用户在设置面板上看到的、以及诊断信息里贴出来的，都会
/// 和 mpv 文档对不上号，排查时多一层换算。
@immutable
final class VideoFilterSettings {
  /// 构造一组滤镜参数，四个分量都必须落在 `-100 ~ 100`。
  const VideoFilterSettings({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.gamma = 0,
  }) : assert(
         brightness >= -100 && brightness <= 100,
         'brightness 超出 -100 ~ 100',
       ),
       assert(contrast >= -100 && contrast <= 100, 'contrast 超出 -100 ~ 100'),
       assert(
         saturation >= -100 && saturation <= 100,
         'saturation 超出 -100 ~ 100',
       ),
       assert(gamma >= -100 && gamma <= 100, 'gamma 超出 -100 ~ 100');

  /// 四项都不改变。
  static const neutral = VideoFilterSettings();

  /// 亮度，对应 mpv `brightness`。
  final int brightness;

  /// 对比度，对应 mpv `contrast`。
  final int contrast;

  /// 饱和度，对应 mpv `saturation`。
  final int saturation;

  /// 伽马，对应 mpv `gamma`。
  final int gamma;

  /// 是否四项皆为 0。
  bool get isNeutral =>
      brightness == 0 && contrast == 0 && saturation == 0 && gamma == 0;

  /// 复制并覆盖部分分量。
  VideoFilterSettings copyWith({
    int? brightness,
    int? contrast,
    int? saturation,
    int? gamma,
  }) => VideoFilterSettings(
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    gamma: gamma ?? this.gamma,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoFilterSettings &&
          other.brightness == brightness &&
          other.contrast == contrast &&
          other.saturation == saturation &&
          other.gamma == gamma);

  @override
  int get hashCode => Object.hash(brightness, contrast, saturation, gamma);

  @override
  String toString() =>
      'VideoFilterSettings(b=$brightness c=$contrast '
      's=$saturation g=$gamma)';
}
