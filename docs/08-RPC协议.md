# 08 · RPC 协议

主进程（Host）与运行时子进程（Runtime）之间的通信协议。

## 1. 传输层

- **信道**：子进程的 `stdin` / `stdout`。`stderr` 保留给运行时自身的致命错误输出（崩溃堆栈），不参与协议。
- **不用**：TCP/本地 socket（会触发防火墙弹窗、端口冲突）、gRPC（依赖重、跨语言生成链复杂）。
- **分帧**：LSP 风格的 header + body。

```
Content-Length: 234\r\n
\r\n
{"jsonrpc":"2.0","id":1,"method":"spider.search","params":{...}}
```

body 为 UTF-8 编码的 JSON。不使用换行分隔（JSON 内容可能含换行，且大 payload 下逐行扫描代价高）。

**约束**：

- 单条消息上限 32MB，超出直接判错并断开该运行时。
- Host 写入必须处理 `stdout` 背压：子进程读得慢时，Host 侧的写队列上限 64 条，超出则对最旧的请求返回 `RUNTIME_BUSY`。
- 子进程必须**立即 flush**，禁止行缓冲导致的死锁。

## 2. 消息层：JSON-RPC 2.0

三种消息形态：

```jsonc
// 请求（需要响应）
{ "jsonrpc": "2.0", "id": 42, "method": "spider.search", "params": {...} }

// 响应
{ "jsonrpc": "2.0", "id": 42, "result": {...} }
{ "jsonrpc": "2.0", "id": 42, "error": { "code": -32001, "message": "...", "data": {...} } }

// 通知（无响应，双向）
{ "jsonrpc": "2.0", "method": "runtime.log", "params": {...} }
```

- `id` 由发起方分配，单调递增，Host 与 Runtime 各自维护独立的 id 空间。
- **双向调用**：Runtime 也能向 Host 发请求（这是宿主 API 的实现方式，见 §4）。
- 不支持批量请求（batch）——增加实现复杂度，收益为零。

## 3. Host → Runtime 方法

### 3.1 运行时管理

| 方法 | params | result |
| --- | --- | --- |
| `runtime.handshake` | `{protocolVersion, appVersion, features[]}` | `{protocolVersion, runtimeVersion, features[]}` |
| `runtime.ping` | `{}` | `{ts}` |
| `runtime.shutdown` | `{graceMs}` | `{}` |
| `runtime.stats` | `{}` | `{rssBytes, contexts, pendingCalls, uptimeMs}` |

### 3.2 Spider 实例管理

| 方法 | params | result |
| --- | --- | --- |
| `spider.create` | `{instanceId, script?, scriptPath?, extend, config, limits}` | `{capabilities[]}` |
| `spider.destroy` | `{instanceId}` | `{}` |
| `spider.reload` | `{instanceId}` | `{capabilities[]}` |

`limits`：`{timeoutMs, memoryMB, storageQuotaMB, allowedHosts[]}`。

### 3.3 Spider 调用

所有方法带 `instanceId`，语义见 [05-Spider引擎](05-Spider引擎.md) §1：

`spider.home` · `spider.homeVideo` · `spider.category` · `spider.detail` · `spider.search` · `spider.play` · `spider.live` · `spider.isVideoFormat` · `spider.manualVideoCheck` · `spider.action`

### 3.4 取消

| 方法 | params | 说明 |
| --- | --- | --- |
| `$/cancelRequest` | `{id}` | 通知。Runtime 应尽力中断该请求，并以 `REQUEST_CANCELLED` 响应原请求 |

搜索场景下用户快速改词，取消能力直接决定资源占用是否失控——**必须实现，不是可选项**。

## 4. Runtime → Host 方法（宿主 API）

这是 Spider 脚本能力的来源。脚本调用 `req(...)` 时，实际是运行时向 Host 发一条 RPC。

| 方法 | params | result | 权限检查 |
| --- | --- | --- | --- |
| `host.fetch` | `{instanceId, url, method, headers, body, timeoutMs, redirect, responseType}` | `{status, headers, body, finalUrl, elapsedMs}` | 域名白名单、协议白名单、私网拦截、大小上限、并发上限 |
| `host.storage.get` | `{instanceId, key}` | `{value}` | 命名空间隔离 |
| `host.storage.set` | `{instanceId, key, value}` | `{}` | 配额检查 |
| `host.storage.delete` | `{instanceId, key}` | `{}` | — |
| `host.sniff` | `{instanceId, url, headers, timeoutMs, rules}` | `{url, headers}` | 需 network 权限 |
| `host.proxy` | `{instanceId}` | `{httpProxy, httpsProxy, noProxy}` | — |
| `host.env` | `{instanceId}` | `{appVersion, platform, defaultUA, locale}` | — |

**关键设计**：所有网络请求收敛到 Host 的 `host.fetch`，运行时进程本身不发起网络。好处：

- 统一施加白名单、SSRF 拦截、代理、DoH、cookie jar、超时、限速
- 统一的请求日志与耗时统计，源诊断面板才有数据
- 运行时进程不需要网络权限，可进一步限制（未来可用 AppContainer / seccomp 收紧）

## 5. 通知（Notification）

### 5.1 Runtime → Host

| 方法 | params | 说明 |
| --- | --- | --- |
| `runtime.log` | `{level, scope, instanceId, message, detail}` | 脚本 `console.*` 与运行时内部日志统一走这里，落 `app_event` 表 |
| `runtime.progress` | `{id, phase, percent?}` | 长任务进度，用于 UI 显示「解析中/嗅探中」 |
| `runtime.fatal` | `{code, message, stack}` | 运行时即将退出，Host 据此提前标记在途请求失败 |

### 5.2 Host → Runtime

| 方法 | params | 说明 |
| --- | --- | --- |
| `host.settingsChanged` | `{instanceId, changed}` | 源设置变更 |
| `host.networkChanged` | `{online, proxy}` | 网络状态或代理变化 |

## 6. 心跳与超时

| 机制 | 参数 | 行为 |
| --- | --- | --- |
| 心跳 | Host 每 15s 发 `runtime.ping` | 连续 3 次无响应（45s）→ 判定失联 → 杀进程 → 重启 |
| 请求超时 | 默认 15s，`spider.search` 8s，`host.sniff` 20s | 超时 → Host 发 `$/cancelRequest` → 2s 内无响应则该请求本地判错 |
| 握手超时 | 启动后 5s 内必须完成 `runtime.handshake` | 否则判定运行时损坏，不重试，报「运行时不可用」 |
| 优雅退出 | `runtime.shutdown{graceMs:3000}` | 3s 内未退出则强杀 |

**重启退避**：1s → 2s → 4s → 8s → 16s，连续 5 次失败后停止自动重启，UI 显示「运行时不可用」+ 手动重试按钮。

## 7. 错误码

沿用 JSON-RPC 保留区间，业务错误用 `-32000` 以下自定义区间。

### 7.1 标准（JSON-RPC 2.0）

| Code | 名称 |
| --- | --- |
| -32700 | Parse error |
| -32600 | Invalid Request |
| -32601 | Method not found |
| -32602 | Invalid params |
| -32603 | Internal error |

### 7.2 运行时层 `-32000 ~ -32099`

| Code | 常量 | 含义 | 建议动作 |
| --- | --- | --- | --- |
| -32000 | `RUNTIME_NOT_READY` | 握手未完成 | 等待或重启 |
| -32001 | `RUNTIME_BUSY` | 队列已满 | 退避重试 |
| -32002 | `RUNTIME_CRASHED` | 进程已退出 | 重启后重试 |
| -32003 | `INSTANCE_NOT_FOUND` | instanceId 无效 | 重新 create |
| -32004 | `PROTOCOL_VERSION_MISMATCH` | 版本不兼容 | 提示升级 |
| -32005 | `MESSAGE_TOO_LARGE` | 超过 32MB | 判错，不重试 |

### 7.3 Spider 层 `-32100 ~ -32199`

| Code | 常量 | 含义 |
| --- | --- | --- |
| -32100 | `SCRIPT_LOAD_FAILED` | 脚本加载/语法错误 |
| -32101 | `SCRIPT_RUNTIME_ERROR` | 脚本执行抛异常（`data.stack` 带堆栈） |
| -32102 | `SCRIPT_TIMEOUT` | 执行超时 |
| -32103 | `MEMORY_LIMIT_EXCEEDED` | 内存超限 |
| -32104 | `METHOD_NOT_IMPLEMENTED` | 该源未实现此方法（如不支持搜索） |
| -32105 | `INVALID_RESULT_SCHEMA` | 返回值不符合 schema（`data.errors` 列出字段） |
| -32106 | `EMPTY_RESULT` | 正常执行但无数据（非错误，供 UI 区分） |
| -32107 | `REQUEST_CANCELLED` | 被取消 |

### 7.4 权限/网络层 `-32200 ~ -32299`

| Code | 常量 | 含义 |
| --- | --- | --- |
| -32200 | `PERMISSION_DENIED` | 未授予该权限 |
| -32201 | `HOST_NOT_ALLOWED` | 域名不在白名单（`data.host`） |
| -32202 | `PRIVATE_ADDRESS_BLOCKED` | 私网/回环地址被拦截 |
| -32203 | `PROTOCOL_NOT_ALLOWED` | 非 http/https |
| -32204 | `QUOTA_EXCEEDED` | 存储配额超限 |
| -32205 | `RATE_LIMITED` | 请求频率超限 |
| -32210 | `NETWORK_TIMEOUT` | 网络超时 |
| -32211 | `NETWORK_DNS_FAILED` | DNS 解析失败 |
| -32212 | `NETWORK_TLS_ERROR` | 证书错误 |
| -32213 | `HTTP_ERROR` | 非 2xx（`data.status`） |
| -32214 | `RESPONSE_TOO_LARGE` | 响应超过大小上限 |

### 7.5 嗅探层 `-32300 ~ -32399`

| Code | 常量 | 含义 |
| --- | --- | --- |
| -32300 | `SNIFFER_UNAVAILABLE` | 嗅探组件缺失（如 Linux 未装 CEF） |
| -32301 | `SNIFF_TIMEOUT` | 超时未命中 |
| -32302 | `SNIFF_NO_MATCH` | 页面加载完成但无媒体流 |
| -32303 | `SNIFF_PAGE_ERROR` | 页面加载失败 |

### 7.6 本地错误码（正数区间，不走 RPC）

宿主进程自己产生的失败也需要错误码——UI 要按码给文案，日志要按码归类，
诊断报告要按码统计。它们与 RPC 错误共用 `AppError.code` 这一个取值空间，
因此**用符号区分来源**：负数来自子进程，正数是宿主本地，永不出现在 RPC 报文里。

合成一张表而不是两套体系，是为了让上层只认一个 `code`。否则每个 `switch`
都要先判断「这码是谁给的」，而这个判断没有任何业务价值。

| 区段 | 范围 | 归属 |
| --- | --- | --- |
| 配置 | `1000` ~ `1099` | TVBox 配置抓取、解码、解析、校验 |
| 存储 | `1100` ~ `1199` | 数据库、迁移、备份 |
| 播放 | `1200` ~ `1299` | 播放器 |
| 插件 | `1300` ~ `1399` | 插件系统 |
| 更新 | `1400` ~ `1499` | 自动更新 |
| 通用 | `1900` ~ `1999` | 兜底 |

| Code | 常量 | 含义 |
| --- | --- | --- |
| 1000 | `CONFIG_FETCH_FAILED` | 配置地址拉取失败 |
| 1001 | `CONFIG_DECODE_FAILED` | 明文/Base64/AES 三条解码路径全部失败 |
| 1002 | `CONFIG_PARSE_FAILED` | 解码成功但 JSON 结构非法 |
| 1003 | `CONFIG_SCHEMA_INVALID` | 必填缺失、type 非法、协议不在白名单 |
| 1004 | `CONFIG_UNSUPPORTED_VERSION` | 配置格式版本不受支持 |
| 1005 | `CONFIG_EMPTY` | 解析成功但无可用站点 |
| 1100 | `DB_OPEN_FAILED` | 数据库打开失败 |
| 1101 | `DB_MIGRATION_FAILED` | 迁移失败，须回滚并拒绝启动 |
| 1102 | `DB_BACKUP_FAILED` | 迁移前备份失败，迁移不得继续 |
| 1103 | `DB_SCHEMA_TOO_NEW` | 库版本高于本版本支持（用户从新版回退）|
| 1104 | `DB_QUERY_FAILED` | 查询或写入失败 |
| 1105 | `BACKUP_EXPORT_FAILED` | 备份导出失败 |
| 1106 | `BACKUP_IMPORT_FAILED` | 备份导入失败 |
| 1107 | `BACKUP_VERSION_UNSUPPORTED` | 备份文件版本过新 |
| 1200 | `PLAYER_INIT_FAILED` | 播放引擎初始化失败 |
| 1201 | `PLAYER_LIBMPV_MISSING` | 找不到 libmpv 或 hash 校验不过 |
| 1202 | `PLAYER_OPEN_FAILED` | 打开媒体失败 |
| 1203 | `PLAYER_UNSUPPORTED_FORMAT` | 容器或编码不受支持 |
| 1204 | `PLAYER_HWDEC_FALLBACK` | 硬解不可用已降级软解（非失败，需提示）|
| 1205 | `PLAYER_SUBTITLE_LOAD_FAILED` | 外挂字幕加载失败 |
| 1206 | `PLAYER_NO_PLAYABLE_SOURCE` | 回退链走完仍无可播地址 |
| 1300 | `PLUGIN_MANIFEST_INVALID` | manifest 缺字段或版本不受支持 |
| 1301 | `PLUGIN_INTEGRITY_FAILED` | sha256 校验不通过 |
| 1302 | `PLUGIN_SIGNATURE_INVALID` | 签名验证不通过 |
| 1303 | `PLUGIN_INCOMPATIBLE` | 与当前应用版本不兼容 |
| 1304 | `PLUGIN_INSTALL_FAILED` | 安装失败 |
| 1305 | `PLUGIN_ROLLBACK_FAILED` | 回滚失败（版本目录已不一致，最严重）|
| 1306 | `PLUGIN_PERMISSION_REVOKED` | 所需权限已被撤销 |
| 1400 | `UPDATE_CHECK_FAILED` | 检查更新失败 |
| 1401 | `UPDATE_DOWNLOAD_FAILED` | 下载更新包失败 |
| 1402 | `UPDATE_CHECKSUM_MISMATCH` | SHA256 与 feed 声明不一致 |
| 1403 | `UPDATE_SIGNATURE_INVALID` | 更新包签名不通过 |
| 1404 | `UPDATE_APPLY_FAILED` | 原子替换失败 |
| 1405 | `UPDATE_ROLLBACK_FAILED` | 更新失败后的回滚也失败 |
| 1900 | `UNKNOWN` | 兜底。出现在日志里即说明该补专用码 |
| 1901 | `INVALID_STATE` | 调用顺序不对或对象已释放 |
| 1902 | `INVALID_ARGUMENT` | 参数非法 |
| 1903 | `NOT_FOUND` | 目标不存在 |
| 1904 | `CANCELLED` | 被主动取消 |
| 1905 | `TIMEOUT` | 本地操作超时 |
| 1906 | `UNSUPPORTED_PLATFORM` | 当前平台不支持该能力 |
| 1907 | `IO_FAILED` | 文件系统读写失败 |
| 1908 | `LOCAL_PERMISSION_DENIED` | 本地文件或目录权限不足 |

实现在 `packages/core_domain/lib/src/error/error_code.dart`，本表与代码里的
`ErrorCode.known` 一一对应，改动时两边一起改（有单测断言取值与常量名唯一、
且无一落在区段之外）。

**未知错误码**：对端可能比本端新。解码时按区段归类合成占位码而不是抛异常，
见 `docs/compatibility.md` §2。合成码一律 `retryable: false`——不认识的失败
反复重试只会把一次报错放大成一串。

### 7.7 错误对象统一形态

```jsonc
{
  "code": -32101,
  "message": "TypeError: Cannot read property 'url' of undefined",
  "data": {
    "instanceId": "site-12",
    "method": "spider.detail",
    "stack": "at parseDetail (index.js:88:20)\n...",
    "elapsedMs": 340,
    "retryable": false
  }
}
```

`retryable` 字段让上层编排层无需硬编码错误码表就能决定是否重试。

## 8. 版本协商

```jsonc
// Host → Runtime
{"method":"runtime.handshake","params":{
  "protocolVersion": 1,
  "appVersion": "1.0.0",
  "features": ["cancel","sniff","progress","storage"]
}}

// Runtime → Host
{"result":{
  "protocolVersion": 1,
  "runtimeVersion": "1.0.0",
  "engine": "quickjs-2024-01",
  "features": ["cancel","sniff","progress","storage","gbk"]
}}
```

规则：

- `protocolVersion` 不一致 → 直接失败，报 `PROTOCOL_VERSION_MISMATCH`。协议是 breaking change 才升主版本。
- `features` 取交集。Host 不得调用不在交集里的能力。
- 新增方法/字段属于向后兼容变更，不升 `protocolVersion`；靠 `features` 协商。

## 9. 调试支持

- **协议录制**：开发模式下把所有收发消息写入 `logs/rpc-{runtime}-{ts}.jsonl`，可回放。
- **回放测试**：录制的会话可作为集成测试用例，无需真实网络。
- **可视化**：源诊断面板提供「实时 RPC」视图，显示每条调用的方法、耗时、大小、错误。
- **注入延迟/错误**：测试模式下可对指定方法注入超时、错误码、畸形返回，用于验证上层降级路径。

## 10. 测试策略

| 层次 | 内容 |
| --- | --- |
| 分帧 | 半包/粘包/超大包/畸形 header/非法 UTF-8，全部不得导致进程崩溃 |
| 协议 | 每个错误码的产生路径都有用例 |
| 生命周期 | 子进程被 kill -9、卡死不响应、启动即崩，Host 行为符合预期 |
| 背压 | 灌入 1000 条并发请求，验证队列上限与 `RUNTIME_BUSY` |
| 取消 | 取消在途请求，验证资源确实释放 |
| 回放 | 录制的真实会话作为回归用例 |

## 11. 相关文档

- 调用语义 → [05-Spider引擎](05-Spider引擎.md)
- 权限来源 → [06-插件系统](06-插件系统.md)
- 日志落库 → [07-数据库设计](07-数据库设计.md) §3.13
