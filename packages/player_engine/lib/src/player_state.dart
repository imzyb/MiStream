/// 播放状态机。
library;

/// 播放器所处的状态。
///
/// 取值对齐 `docs/04-播放器设计.md` §3 的 `stateStream` 说明。语义以 mpv 的
/// 属性为参照系而不是某个封装库的枚举：[buffering] 对应 `core-idle == true &&
/// paused-for-cache == true`，[ended] 对应 `eof-reached`，[idle] 对应
/// `idle-active`。这样二期换 `NativeMpvEngine` 时，映射关系是一一对应的查表，
/// 不需要重新定义「什么算在播」。
///
/// 合法迁移（由契约测试强制）：
///
/// ```text
/// idle ──open()──> opening ──> buffering ⇄ playing ⇄ paused
///  ↑                                          │
///  └──────────── close() ─────────────────────┤
///                                             ↓
///                                           ended
/// 任意状态 ──不可恢复的失败──> error ──open()/close()──> …
/// ```
enum PlayerState {
  /// 没有加载任何媒体。引擎已 `initialize` 但空闲。
  idle,

  /// 已收到 `open()`，正在解析地址、建连、探测容器与轨道。
  ///
  /// 与 [buffering] 分开是因为它们的失败原因完全不同：这一段失败通常是 404、
  /// 403 缺 Referer、DNS 失败；[buffering] 失败则是带宽或源限速问题。UI 的
  /// 加载态要显示「连接中」还是「缓冲中」，靠的就是这两个状态的区分
  /// （`docs/09-UI规范.md` §5.5）。
  opening,

  /// 已确定可播，正在等待足够的数据。
  buffering,

  /// 正在播放。
  playing,

  /// 已暂停。
  paused,

  /// 播放到结尾。
  ended,

  /// 播放因不可恢复的错误终止，详情在 `errorStream` 上。
  error;

  /// 是否已加载媒体（即不是 [idle]，也不是失败终止）。
  bool get hasMedia => this != PlayerState.idle && this != PlayerState.error;

  /// 是否处于「正在推进播放」的状态。
  ///
  /// [buffering] 算在内：用户视角里缓冲是播放的一部分，控制栏的播放/暂停按钮
  /// 此时应显示为「暂停」而不是「播放」。
  bool get isPlaying =>
      this == PlayerState.playing || this == PlayerState.buffering;

  /// 是否是终态——再不会自行改变，只能靠新的 `open()` 或 `close()` 脱离。
  bool get isTerminal => this == PlayerState.ended || this == PlayerState.error;
}
