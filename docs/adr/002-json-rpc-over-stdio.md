# ADR-002：进程间通信用 JSON-RPC over stdio

**状态**：已接受

## 背景

[ADR-001](001-spider-独立子进程.md) 决定把 Spider 放进子进程后，必须选一种 IPC 机制。约束：

- **不能触发防火墙弹窗**——桌面用户看到「MiStream 想要接受网络连接」会直接怀疑软件在偷传数据
- 需要**双向调用**：Host 调 Spider 的方法，Spider 也要调 Host 的宿主 API（`req` / `local` / `sniff`）
- 需要**取消**语义（用户改搜索词时中止在途请求）
- 跨 Windows / macOS / Linux 行为一致
- 运行时可能用多种语言实现（Dart、Python、Java），协议要易于在各语言实现

## 决策

我们将使用 **JSON-RPC 2.0 over stdio**，采用 LSP 风格的 `Content-Length` header 分帧。

- 子进程的 `stdin`/`stdout` 作为双向信道，`stderr` 留给运行时自身的致命错误输出
- 请求、响应、通知三种消息形态；双向对称（两侧都可发起请求）
- `$/cancelRequest` 通知实现取消
- 单条消息上限 32MB；Host 侧写队列上限 64 条，超出返回 `RUNTIME_BUSY`

## 备选方案

| 方案 | 优点 | 放弃原因 |
| --- | --- | --- |
| gRPC | 强类型、成熟、双向流原生支持 | 需要 protoc 工具链与多语言代码生成，给「用任意语言写运行时」增加了高门槛；默认走 TCP，回到防火墙问题；依赖重（体积预算敏感） |
| TCP / WebSocket on localhost | 实现简单、工具丰富 | **触发防火墙弹窗**；端口冲突与端口扫描风险；需要额外的认证机制防止本机其它程序连入 |
| Unix domain socket / 命名管道 | 无防火墙问题、性能好 | 三平台 API 不一致（Windows 命名管道 vs Unix socket），需要两套实现；相比 stdio 没有实质收益 |
| 共享内存 + 信号量 | 性能最好 | 复杂度高、跨平台难、需要自己做同步；瓶颈根本不在传输（单次调用几十 KB） |
| 换行分隔的 JSON（JSONL） | 分帧实现最简单 | JSON 内容含换行时需转义，大 payload 下逐字节扫描分隔符代价高；LSP 已验证 `Content-Length` 方案更稳健 |

## 后果

**正面**

- 零端口占用、零防火墙提示、零端口冲突
- 用任何语言实现运行时的门槛极低：能读写 stdio 和解析 JSON 即可
- LSP 生态已经把这套分帧方案验证了很多年，坑都是已知的
- 消息是人类可读的 JSON，录制下来就是可回放、可 diff 的测试用例
- 双向调用让宿主 API 的实现变得自然：`req()` 就是子进程向 Host 发的一个请求

**负面**

- JSON 序列化开销高于二进制协议。对大响应（几 MB 的分类列表）有可测量的成本
  - 缓解：响应体在缓存层用 gzip 存储；必要时对特定方法引入二进制附件通道
- 需要自己实现分帧、背压、超时、取消——这些 gRPC 本可以白送
- 无编译期类型检查，schema 不匹配只能在运行时发现
  - 缓解：Host 侧对所有返回值做 schema 校验，不匹配返回 `INVALID_RESULT_SCHEMA` 并列出具体字段
- stdio 被占用后，子进程不能再用 `print` 调试——所有日志必须走 `runtime.log` 通知
  - 这实际是好事：强制了结构化日志

## 参考

- [08-RPC协议](../08-RPC协议.md) 完整协议定义
- [ADR-001](001-spider-独立子进程.md)
- Language Server Protocol 的 base protocol（分帧方案来源）
