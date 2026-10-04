# spider_host

Spider 子进程的宿主侧：生命周期管理与 JSON-RPC over stdio。

**状态**：已落地。`SpiderHost` 管启动/握手/心跳/退避重启/熔断，`HostApi` 服务
子进程反向发来的 `host.*`（脚本里的 `req` / `local.*`），`SpiderRuntimeFactory`
按站点类型分发到 HTTP / JS / JVM 三种运行时。

协议见 [docs/08-RPC协议](../../docs/08-RPC协议.md)，进程模型见
[docs/02-系统架构](../../docs/02-系统架构.md) §2 与
[ADR-001](../../docs/adr/001-spider-独立子进程.md)。

## 生命周期契约（`SpiderHost`）

- `start()` 拉起进程并握手；失败按 1s→2s→4s→8s→16s 退避重启，5 次后**熔断**
  （`isTripped`），等 `reset()` 手动重试。
- `call()` 在未就绪时**不排队**，直接回 `RUNTIME_NOT_READY`。
- **`isReady == false` ≠ 这个宿主废了**。心跳判失联、进程崩溃、按计划换新都会
  先关停再退避重启，这段窗口内 `isReady` 就是 false，而同一个子进程马上会回来。
  想复用它请 `await waitReady()`；只有它返回 false（熔断 / 已释放 / 超时）才该
  弃掉重建。把 `isReady == false` 当成「废了」而另起一个，会并存两个子进程、
  两套实例，旧的还在后台重启——谁都不知道对方存在。
- **按计划换新**：这份 vendored `libquickjs.dll` 上释放 runtime 会断言 abort，
  只能「释放 context + 弃用 runtime」，而 context 释放并不真还内存（每源约
  10MB）。所以 `SpiderHost` 每收掉 `kSourceTearDownsPerProcess`（默认 8）个源、
  且当前无活实例时，发 `runtime.shutdown` 让子进程干净退出再拉起，由 OS 回收。
  见 [runtimes/spider_js/README.md](../../runtimes/spider_js/README.md)。

## 测试注入

`SpiderHost` 收 `launcher`（默认 `Process.start`），`SpiderRuntimeFactory` 收
`jsLauncher` / `jvmLauncher`。JS 路径的 `spider.create` 参数拼装、换新窗口行为
都发生在真子进程之前，靠这两个注入口用假进程覆盖——本机 `Process.start` 被
命名管道缺陷挡住（`CreateFile failed 231`）时这是唯一的覆盖手段。
