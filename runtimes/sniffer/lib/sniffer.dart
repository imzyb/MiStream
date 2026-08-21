/// 无头浏览器嗅探子进程（M6）。
///
/// M6 已落地最小可用实现：`IsolateSniffer`（`packages/media_sniffer`）把
/// `SnifferResolver` 放进 isolate 跑，超时可杀、不残留 cookie，满足
/// ROADMAP M6 的两条硬约束。WebView2/CDP 的完整头浏览器实现见
/// `docs/05-Spider引擎.md` §6，差异后续收敛在 CDP 抽象之后。
///
/// 平台差异：当前 isolate 版覆盖静态页 80% 场景，需 JS 执行的站点后续
/// 由 `runtimes/sniffer` 的 WebView2 子进程接管，接口保持 `SnifferLauncher`。
library;

export 'package:media_sniffer/media_sniffer.dart' show IsolateSniffer;
