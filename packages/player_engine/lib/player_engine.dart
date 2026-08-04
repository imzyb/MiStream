/// 播放内核抽象与实现。
///
/// **本包在 M1 落地**，当前只占位。
///
/// 计划中的公共 API（见 `docs/04-播放器设计.md` §3）：
///
/// - `PlayerEngine`：抽象接口。`MediaKitEngine`（一期）与 `NativeMpvEngine`
///   （M15，dart:ffi 直连 libmpv）跑同一套契约测试
/// - `PlayerState` / position / duration / buffered / `MediaInfo` 状态流
/// - 硬解优先级链与自动降级，降级后向 UI 发出可见提示
/// - 轨道管理：视频 / 音频 / 字幕切换，外挂字幕加载
///
/// 抽象层不是为了「将来也许能换」，而是 [ADR-004] 的既定退路：media_kit 没有
/// 暴露全部 mpv 选项，自研 FFI 绑定是写进 ROADMAP 的计划而非假设。
///
/// [ADR-004]: ../../docs/adr/004-播放器分两期实现.md
library;
