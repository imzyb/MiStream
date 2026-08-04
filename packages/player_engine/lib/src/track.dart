/// 轨道标识与轨道信息。
library;

import 'package:meta/meta.dart';

/// 轨道类型。
enum TrackKind {
  /// 视频轨，对应 mpv 的 `vid`。
  video('vid'),

  /// 音频轨，对应 mpv 的 `aid`。
  audio('aid'),

  /// 字幕轨，对应 mpv 的 `sid`。
  subtitle('sid');

  const TrackKind(this.mpvProperty);

  /// 选择该类轨道时要写的 mpv 属性名。
  final String mpvProperty;
}

/// 一条轨道的标识。
///
/// 直接采用 mpv 的取值语义而不是「列表下标」：mpv 的 `vid` / `aid` / `sid`
/// 接受三种值——从 1 开始的轨道号、`auto`（让 mpv 按语言偏好挑）、`no`
/// （关闭）。用下标表达会丢掉后两者，而「自动选轨」和「关字幕」恰恰是播放器
/// 最常用的两个操作。这是 [ADR-004] 说的「以 mpv 原生能力为参照系」的具体
/// 落点之一。
///
/// [ADR-004]: ../../../docs/adr/004-播放器分两期实现.md
@immutable
final class TrackId {
  /// 按轨道号构造。mpv 的轨道号从 1 开始。
  factory TrackId(int number) {
    if (number < 1) {
      throw ArgumentError.value(number, 'number', 'mpv 轨道号从 1 开始');
    }
    return TrackId._('$number');
  }

  const TrackId._(this._raw);

  /// 交给 mpv 按语言与默认标志自动选择。
  static const auto = TrackId._('auto');

  /// 关闭该类轨道。对字幕就是「不显示字幕」。
  static const disabled = TrackId._('no');

  final String _raw;

  /// 写给 mpv 的属性值。
  String get mpvValue => _raw;

  /// 轨道号；[auto] 与 [disabled] 为 `null`。
  int? get number => int.tryParse(_raw);

  /// 是否是「自动选择」。
  bool get isAuto => identical(this, auto);

  /// 是否是「关闭」。
  bool get isDisabled => identical(this, disabled);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TrackId && other._raw == _raw);

  @override
  int get hashCode => _raw.hashCode;

  @override
  String toString() => 'TrackId($_raw)';
}

/// 一条轨道的元信息。
///
/// 字段对应 mpv `track-list` 的同名项，命名做了 Dart 化。
@immutable
final class Track {
  /// 构造一条轨道。
  const Track({
    required this.id,
    required this.kind,
    this.title,
    this.language,
    this.codec,
    this.isDefault = false,
    this.isForced = false,
    this.isExternal = false,
    this.isSelected = false,
  });

  /// 轨道标识。
  final TrackId id;

  /// 轨道类型。
  final TrackKind kind;

  /// 轨道标题，来自容器元数据。
  final String? title;

  /// 语言代码，对应 `track-list/N/lang`，通常是 ISO 639。
  final String? language;

  /// 编码名，对应 `track-list/N/codec`。
  final String? codec;

  /// 容器是否把它标记为默认轨。
  final bool isDefault;

  /// 是否是强制字幕轨（外语对白的硬性字幕）。
  final bool isForced;

  /// 是否来自外挂文件而非容器内。
  final bool isExternal;

  /// 当前是否被选中。
  final bool isSelected;

  /// 给 UI 用的显示名。
  ///
  /// 优先级：标题 → 语言 → 编码 → 轨道号。三者皆无时至少还有个轨道号，
  /// 不会在菜单里出现一行空白。
  String get displayName =>
      title ?? language ?? codec ?? '轨道 ${id.number ?? id.mpvValue}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Track &&
          other.id == id &&
          other.kind == kind &&
          other.title == title &&
          other.language == language &&
          other.codec == codec &&
          other.isDefault == isDefault &&
          other.isForced == isForced &&
          other.isExternal == isExternal &&
          other.isSelected == isSelected);

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    language,
    codec,
    isDefault,
    isForced,
    isExternal,
    isSelected,
  );

  @override
  String toString() => 'Track(${kind.name} ${id.mpvValue} $displayName)';
}
