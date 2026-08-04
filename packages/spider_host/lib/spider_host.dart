/// Spider 子进程的宿主侧实现。
///
/// **本包在 M3 落地**，当前只占位。
///
/// 计划中的公共 API（见 `docs/08-RPC协议.md`）：
///
/// - `SpiderHost`：子进程生命周期、进程池、握手、心跳、退避重启、熔断
/// - `StdioRpcChannel`：LSP 风格分帧（`Content-Length` header + JSON body）、
///   双向调用、`$/cancelRequest`、写队列背压
/// - `HostApi`：`host.fetch`（域名白名单、SSRF 拦截、代理、超时、大小上限）、
///   `host.storage`、`host.env`
/// - `SpiderRuntime`：统一 Spider 接口的 Dart 侧定义与返回值 schema 校验
/// - `RpcRecorder` / `RpcReplayer`：录制与回放，回放会话直接作为回归用例
///
/// 分帧与背压是自研清单第 4 项（`docs/03-技术选型.md` §3）：半包、粘包、
/// 超大包、畸形数据都必须扛住，这是 M3 的出口标准之一。
library;
