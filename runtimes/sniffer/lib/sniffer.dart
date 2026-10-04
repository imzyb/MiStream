/// 无头浏览器嗅探（M6）。
///
/// 设计见 [docs/05-Spider引擎](../../docs/05-Spider引擎.md) §6，
/// 独立进程与 CDP 的理由见 [ADR-005](../../docs/adr/005-嗅探独立进程-cdp.md)。
///
/// ## 分层
///
/// ```text
/// SnifferRuntime        门面：内核发现 -> 启进程 -> 连 CDP -> 嗅 -> 杀干净
///   ├─ SnifferKernelLocator   找内核（Edge / Chrome / Chromium / 自定义）
///   ├─ SnifferKernelProcess   跑内核、解析 DevTools 端点、一次性 profile
///   ├─ CdpClient              协议：id 配对、事件分发、超时
///   │    └─ CdpTransport      传输：WebSocket，可注入
///   └─ SniffSession           策略：什么算命中、何时放弃
/// ```
///
/// 分层不是为了好看，是为了**可测**。上一版把进程、协议、策略、WebSocket
/// 揉在一个 `CdpSniffer` 里，结果每个方法都停在注释上——因为整条链路需要
/// 真实浏览器 + 回环连接才能跑，而这两者都有环境依赖。拆开后，协议与策略
/// 可以注入内存传输完整测试，只有内核启动需要真实环境。
///
/// ## 关于内核
///
/// 本项目**不随包浏览器内核**（体积预算与依赖树的取舍见 ADR-005 备选方案）。
/// 运行时按序探测本机已装的 Edge / Chrome / Chromium，全都没有时返回
/// `SNIFFER_UNAVAILABLE`（-32300）并提示用户安装或指定路径。
///
/// ## 与 WebView 版的关系
///
/// `packages/media_sniffer` 里的 `WebViewSniffer` / `CdpSniffer` 是接口占位与
/// 规则引擎所在地；本包提供**可运行**的 CDP 实现。判定规则（媒体扩展名、
/// Content-Type、`SnifferRule`）复用 `media_sniffer`，两边只有一份标准。
///
/// ## 静态页快速路径
///
/// 需要 JS 执行的页面才值得起浏览器。纯静态页由
/// [IsolateSniffer]（`media_sniffer`）走 HTTP + 规则匹配即可，
/// 它是嗅探链路里排在 CDP 之前的一环。
library;

export 'package:media_sniffer/media_sniffer.dart'
    show
        IsolateSniffer,
        // 媒体判定类型是 sniffer 公共 API 的一部分：调用方要构造自定义规则、
        // 也要读取命中结果的类型与 header。
        MediaDetector,
        MediaType,
        SnifferResult,
        SnifferRule;

export 'src/cdp/cdp_client.dart'
    show CdpClient, CdpCommandException, CdpEvent, CdpTimeoutException;
export 'src/cdp/cdp_transport.dart'
    show CdpFrame, CdpTransport, CdpTransportException, WebSocketCdpTransport;
export 'src/cdp_sniffer_launcher.dart' show CdpSnifferLauncher;
export 'src/kernel/kernel_locator.dart'
    show
        SnifferKernel,
        SnifferKernelKind,
        SnifferKernelLocator,
        SnifferUnavailableException;
export 'src/kernel/kernel_process.dart'
    show KernelLaunchException, SnifferKernelProcess;
export 'src/session/sniff_session.dart'
    show CdpSniffFailure, CdpSniffOutcome, SniffSession;
export 'src/sniffer_runtime.dart' show SnifferRuntime;
