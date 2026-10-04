# sniffer

无头浏览器嗅探，统一走 CDP。用完即杀，不持久化 cookie。

设计见 [docs/05-Spider引擎](../../docs/05-Spider引擎.md) §6，
独立进程与 CDP 的理由见 [ADR-005](../../docs/adr/005-嗅探独立进程-cdp.md)。

## 用法

```dart
final runtime = SnifferRuntime();
final outcome = await runtime.sniff(
  'https://example.com/vod/123',
  headers: {'Referer': 'https://example.com/'},
);

if (outcome.isHit) {
  print('命中 ${outcome.url}（${outcome.media!.type.extension}）');
} else {
  print('未命中：${outcome.failure!.constant} ${outcome.detail}');
}
```

接入播放链路时用 `CdpSnifferLauncher`（实现 `play_engine` 的
`SnifferLauncher`）：

```dart
final launcher = CdpSnifferLauncher();
final url = await launcher.sniff(pageUrl, headers);
```

## 内核

**本项目不随包浏览器内核**（体积预算与 npm 依赖树的取舍见 ADR-005 备选方案）。
运行时按序探测本机已装的 Edge → Chrome → Chromium → Brave：

- 命中即用，`--user-data-dir` 指向一次性临时目录
- 全都没有时返回 `SNIFFER_UNAVAILABLE`（-32300），提示用户安装或指定路径
- 也可以在 `SnifferKernelLocator(explicitPath: ...)` 里显式指定；
  **显式路径不会回退到探测**，写错了就是不可用，不会静默换别的内核

## 分层

```text
SnifferRuntime        门面：内核发现 -> 启进程 -> 连 CDP -> 嗅 -> 杀干净
  ├─ SnifferKernelLocator   找内核
  ├─ SnifferKernelProcess   跑内核、解析 DevTools 端点、一次性 profile
  ├─ CdpClient              协议：id 配对、事件分发、超时
  │    └─ CdpTransport      传输：WebSocket，可注入
  └─ SniffSession           策略：什么算命中、何时放弃
```

分层是为了**可测**：整条链路需要真实浏览器 + 回环连接，两者在 CI 与受限
环境里都不可靠。拆开后协议与策略用内存传输完整覆盖，只有内核启动依赖
真实环境（没有浏览器时自动跳过，跳过数会体现在报告里）。

媒体判定规则（`MediaDetector` / `SnifferRule`）复用 `packages/media_sniffer`，
保证 CDP 路径与 HTTP 路径只有一份命中标准。

## 错误码

对应 [docs/08-RPC协议](../../docs/08-RPC协议.md) §7.5：

| 常量 | 码 | 含义 |
| --- | --- | --- |
| `SNIFFER_UNAVAILABLE` | -32300 | 未找到可用内核 |
| `SNIFF_TIMEOUT` | -32301 | 超时未命中 |
| `SNIFF_NO_MATCH` | -32302 | 页面加载完成但无媒体流 |
| `SNIFF_PAGE_ERROR` | -32303 | 页面加载失败 |

## 测试

```bash
cd runtimes/sniffer && dart test
```

- `cdp_client_test.dart` —— 协议层（id 配对、超时、错误、事件分发）
- `sniff_session_test.dart` —— 嗅探策略（命中判定、排除规则、错误码）
- `kernel_locator_test.dart` —— 内核发现与降级路径
- `kernel_process_test.dart` —— **真实内核**启动、端点解析、清理
- `sniffer_runtime_test.dart` —— 门面编排与可用性查询
