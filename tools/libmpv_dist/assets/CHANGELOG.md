# libmpv 锁定版本升级记录

依据 docs/03-技术选型.md §2，libmpv 锁版本 + SHA256。每次升级必须：

1. 选一个确定来源（本仓库用 media_kit 的 `libmpv-win32-video-build` release）。
2. 记录归档 SHA256 与解包后 `libmpv-2.dll` 的 SHA256。
3. 跑一遍 `melos run libmpv:install` 验证能下能验。
4. 用新 DLL 跑通 MediaKitEngine 契约测试与媒体矩阵（ROADMAP M1 出口标准）。

| 版本 | 归档 SHA256 | libmpv-2.dll SHA256 | 说明 |
| --- | --- | --- | --- |
| 2023-09-24 | `DCE982...E97572` | `D5F0694B...A5FC` | media_kit 1.2.6 默认锁定的版本 |