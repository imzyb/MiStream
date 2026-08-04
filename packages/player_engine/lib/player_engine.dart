/// 播放内核抽象与实现。
///
/// `PlayerEngine` 是 UI 与编排层唯一依赖的接口；`MediaKitEngine`（M1）与
/// `NativeMpvEngine`（M15，`dart:ffi` 直连 libmpv）跑同一套契约测试。设计见
/// `docs/04-播放器设计.md`，分两期实现的理由见 [ADR-004]。
///
/// 抽象层不是为了「将来也许能换」，而是 [ADR-004] 的既定退路：media_kit 没有
/// 暴露全部 mpv 选项，自研 FFI 绑定是写进 ROADMAP 的计划而非假设。因此接口
/// 的参照系是 mpv 的原生能力——轨道用 `vid`/`aid`/`sid` 的取值语义、硬解是
/// 有序的降级链而不是布尔开关、`MediaInfo` 的字段直接对应 mpv 属性。
///
/// 测试替身在 `package:player_engine/testing.dart`，与生产代码分开导出。
///
/// [ADR-004]: ../../docs/adr/004-播放器分两期实现.md
library;

export 'package:player_engine/src/aspect_ratio_mode.dart';
export 'package:player_engine/src/duration_range.dart';
export 'package:player_engine/src/hwdec.dart';
export 'package:player_engine/src/media_info.dart';
export 'package:player_engine/src/media_source.dart';
export 'package:player_engine/src/player_config.dart';
export 'package:player_engine/src/player_engine.dart';
export 'package:player_engine/src/player_error.dart';
export 'package:player_engine/src/player_log.dart';
export 'package:player_engine/src/player_state.dart';
export 'package:player_engine/src/track.dart';
export 'package:player_engine/src/video_filter_settings.dart';
