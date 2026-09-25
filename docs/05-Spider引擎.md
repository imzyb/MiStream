# 05 · Spider 引擎

Spider 引擎是 MiStream 最复杂、风险最高的子系统。它要做三件事：**统一接口**、**多运行时**、**沙箱隔离**。

## 1. 统一 Spider 接口

所有运行时对上层暴露同一组方法。语义对齐 `com.github.catvod.crawler.Spider`，但参数与返回值改为强 schema 的 JSON。

| 方法 | 入参 | 返回 | 说明 |
| --- | --- | --- | --- |
| `init` | `{extend, config}` | `{ok, capabilities}` | 初始化，返回该源实际支持的能力位 |
| `homeContent` | `{filter: bool}` | `{classes[], filters{}, list[]}` | 首页分类与筛选项 |
| `homeVideoContent` | `{}` | `{list[]}` | 首页推荐内容（可空） |
| `categoryContent` | `{tid, page, filter, extend}` | `{list[], page, pageCount, limit, total}` | 分类翻页 |
| `detailContent` | `{ids[]}` | `{list[VodDetail]}` | 详情 + 剧集列表 |
| `searchContent` | `{key, quick, page}` | `{list[]}` | 搜索 |
| `playerContent` | `{flag, id, vipFlags[]}` | `{parse, url, header{}, playUrl, jx, danmaku}` | 播放地址 |
| `liveContent` | `{url}` | `{groups[]}` | 直播频道 |
| `isVideoFormat` | `{url}` | `{ok}` | 嗅探时判定是否媒体流 |
| `manualVideoCheck` | `{}` | `{ok}` | 是否需要人工确认嗅探结果 |
| `action` | `{action, value}` | `{type, payload}` | 源自定义动作（弹窗/输入/刷新） |
| `destroy` | `{}` | `{}` | 释放资源 |

### 核心数据模型

```jsonc
// VodItem —— 列表项
{
  "vodId": "string",         // 必填，源内唯一
  "vodName": "string",       // 必填
  "vodPic": "string",        // 封面 URL
  "vodRemarks": "string",    // 角标：更新至 12 集 / HD
  "vodYear": "string",
  "vodArea": "string",
  "typeName": "string"
}

// VodDetail —— 详情
{
  "vodId": "string",
  "vodName": "string",
  "vodPic": "string",
  "typeName": "string",
  "vodYear": "string",
  "vodArea": "string",
  "vodRemarks": "string",
  "vodActor": "string",
  "vodDirector": "string",
  "vodContent": "string",
  "vodPlayFrom": ["线路1", "线路2"],        // flag 列表，$$$ 分隔的原始形态在解析层已拆开
  "vodPlayUrl": [                          // 与 vodPlayFrom 一一对应
    [{"name": "第1集", "url": "..."}, ...],
    [...]
  ]
}

// PlayResult
{
  "parse": 0,                 // 0=直链 1=需解析
  "url": "string",            // parse=0 时为直链；parse=1 时为待解析页面地址
  "header": {"User-Agent": "...", "Referer": "..."},
  "jx": 0,                    // 是否允许走解析接口
  "danmaku": "string",        // 可选弹幕地址
  "subs": [{"name":"", "url":"", "format":"srt"}]  // 可选外挂字幕
}
```

上层 Domain 模型与此**不共用类型**：`core_config` 负责把源返回的松散 JSON 归一化、校验、填默认值后再映射为 Domain 实体。源返回缺字段、类型不对、URL 是相对路径，都在这一层兜住。

## 2. 四类运行时对比

| | JS | HTTP | Python | JVM |
| --- | --- | --- | --- | --- |
| 生态占比 | **最高**（drpy 系） | 中 | 低 | 中（存量 jar） |
| 实现难度 | 高（宿主 API 多） | **最低** | 中 | **最高** |
| 分发成本 | 随包 ~10MB | 0 | 可选下载 ~30MB | 需外部 JRE |
| 隔离性 | 好（QuickJS 可限内存/时间） | 最好（本来就在远端） | 中 | 中 |
| 优先级 | **P0** | **P0** | P2 | P3（探索） |

### 2.1 HTTP 运行时（先做，用于打通端到端）

源本身是一个远端 HTTP 服务，客户端只做请求转发：

```
POST {api}/  { "method": "searchContent", "params": {...} }
→ { "list": [...] }
```

无子进程、无沙箱问题。它的价值是让 M3 阶段就能端到端跑通「搜索 → 详情 → 播放」，把 UI 与编排层的问题先暴露出来，而不是等 JS 运行时做完。

### 2.2 JS 运行时（主战场）

- 引擎：QuickJS，跑在 `spider_js` 子进程内。
- 每个源一个独立 JS Context；Context 之间不共享全局对象。
- 资源限制：单次调用超时（默认 15s）、内存上限（默认 256MB）、JS 栈深度限制。
- 超时靠 QuickJS 的 interrupt handler 中断，而不是靠杀进程——避免影响同进程其它源。

**宿主 API 实现现状**（drpy 兼容层，兼容性的成败在此）：

| 类别 | API | 状态 |
| --- | --- | --- |
| 网络 | `req(url, options)` — method/headers/body/timeout/redirect/withHeaders/buffer/postType | 已实现（过宿主 RPC） |
| HTML 解析 | `pdfh(html, rule)`、`pdfa(html, rule)`、`pd(html, rule, baseUrl)`、`pdfl(...)` | 已实现 |
| JSON 解析 | `jsonpath.query(jsonObject, path)`、`pjfh`/`pj`/`pjfa` | 已实现 |
| 存储 | `local.get/set/delete`（按源隔离命名空间，落 SQLite） | 已实现（过宿主 RPC） |
| 编码 | `base64Encode/Decode`、`gbkDecode`、`urlencode`、`md5`、`sha1`、`sha256` | 已实现 |
| 加密 | `aes(mode, encrypt, input, inBase64, key, iv, outBase64)`、`rsaX(mode, pub, encrypt, input, inBase64, key, outBase64)`、`hmac256` | 已实现，签名按位置参数对齐 |
| 工具 | `console.log/warn/error`（转发到 RPC 日志通道）、`joinUrl` | 已实现 |
| 环境 | `getProxy()` | **未实现**，见下 |

关于上表的三个更正（2026-09-25 对着 `hjdhnx/dr_py` 的 `libs/drpy.js` 与
`libs/drpy2.min.js` 实测得出，此前文档写的是推测值）：

- **`print` / `log` 不需要壳子提供**。drpy2 自己定义（内部走 `console.log`），
  宿主只需给 `console`。
- **`setTimeout` / `getUA` / `getAppVersion` 在两个参考实现里出现 0 次**，不属于
  「必须实现的宿主 API」。真实源若用到它们会报 `not defined`，届时再按需补。
- **`getProxy` 是可选的**。全仓唯一调用点是 `getProxyUrl()`，且带
  `typeof getProxy==="function"` 守卫，取不到时回落
  `http://127.0.0.1:9978/proxy?do=js`（TVBox 本地代理端口）。不实现只是拿不到
  本应用的代理地址，不会让源崩掉。真要做时注意它收一个布尔参数。

**微任务必须被泵**（这一条不是「锦上添花」，缺了会静默丢数据）：

`JS_Eval` 只执行脚本的同步部分。Promise 回调是挂在 runtime 队列上的 *job*，
C API 不会自己跑它——没有 `JS_ExecutePendingJob` 时，`p.then(cb)` 永远不调 `cb`，
`async function f(){ return 1 }` 的返回值永远不落地，`JSON.stringify(f())` 得到
`"{}"`。表现是**源能加载、能调用、返回空数据、全程不报错**，属于最难查的一类。

对策分三层，缺一不可：

1. `native/quickjs_wrapper.c` 导出 `qs_drain_jobs(rt, ctx, max_jobs)`，内部循环
   `JS_ExecutePendingJob` 直到队列空（`libquickjs.dll` 导出该符号；缺失时返回
   `-2`，由 Dart 如实报错而不是假装成功）。
2. `JsRuntime._evalWithTimeout` **每次求值后都泵一次**。空闲时只多一次
   `JS_IsJobPending` 判断，代价可忽略。
3. `JsRuntime._wrap` 发现返回值是 thenable 时，挂上 `then/catch` 把结果暂存到
   `__qs_*` 全局并回一个待定标记；泵完之后用 `_asyncReadback` 取回。
   排空后仍是 pending 的源（在等一个永不到来的事件）**报错**，不返回空值。

`runtime_child` 生成的所有调用表达式因此一律写成 `await` 形式
（`(async function () { ... return JSON.stringify(await home(...)); })()`），
并且 `home()` / `homeVod()` 的返回值**字符串与对象都接受**——drpy 约定返回 JSON
字符串，但直接返回对象的源也不少。

> 注意：这条依赖 `qs_drain_jobs`，wrapper DLL 是本地构建产物、不入库。
> 旧的 DLL 会让所有源都报「Promise 无法读取」，重跑 `native/build.bat` 即可。

`pdfh` 的选择器语法是简化伪 XPath（形如 `body&&.list&&a&&href`、`.title&&Text`、`img&&src`），**不是标准 XPath 也不是标准 CSS**。这是整个项目里最容易出错、最需要靠回归测试保证的部分。

**兼容性回归测试集**：在 `runtimes/spider_js/test/compat/` 下维护一组固定的 `(html 快照, 规则, 期望输出)` 三元组，覆盖真实源里出现过的写法。每次改动跑全量。这套测试集的规模，直接决定 JS 源兼容率。

### 2.3 Python 运行时

- 嵌入 CPython，跑在 `spider_python` 子进程。
- 提供与 JS 侧对等的宿主 API（`req` / `pdfh` / `local` 等），语义一致。
- 限制：禁用 `os` / `subprocess` / `socket` 直接访问，网络必须走宿主 `req`。
- 作为**可选下载组件**，不进基础安装包。

### 2.4 JVM 运行时（探索项，明确降级）

存量 jar spider 的现实障碍：

1. 多数产物是 **Dex 字节码**（Android 格式），不是标准 JVM class → 需 `dex2jar` 类转换，且转换后未必能跑。
2. 大量 jar 直接调用 `android.util.Base64`、`android.text.TextUtils`、`android.content.Context`、`WebView` → 需要一层 android 兼容 shim。
3. 部分 jar 依赖 Android WebView 执行 JS 挑战 → 需转接到 sniffer 进程。
4. jar 本身是**闭源二进制**，无法审计，安全风险最高。

**结论与承诺边界**：

- 不进 v1.0 出口标准。
- 做成可选组件：用户自行安装 JRE 17+，MiStream 提供 `spider_jvm` 进程 + 有限的 android shim。
- 只承诺「纯 Java 逻辑 + 已 shim 的 android API 子集」可跑，**不承诺任意 jar 可用**。
- UI 中对 jar 源标注「实验性 · 二进制不可审计」并要求用户显式确认后才加载。

这条降级要在 ROADMAP 与 README 里都写清楚，避免用户预期错位。

## 3. 生命周期与进程池

```
[未加载] ──load()──> [初始化中] ──init成功──> [就绪] ──调用──> [就绪]
                          │                      │
                       init失败                空闲超时/内存超限
                          ↓                      ↓
                      [失败]                  [已回收]
                          │                      │
                      重试(退避)              下次调用重新 load
                          ↓
                  连续失败 N 次 → [熔断] （UI 标红，用户可手动重置）
```

- **进程复用**：同类型运行时共用一个子进程，源之间靠 Context 隔离。进程数不随源数增长。
- **空闲回收**：源 10 分钟无调用 → 销毁其 Context；进程内无 Context 且 5 分钟无活动 → 退出进程。
- **崩溃恢复**：子进程异常退出 → SpiderHost 检测到管道关闭 → 标记所有在途请求失败 → 按退避重启（1s/2s/4s/8s，上限 5 次）。
- **熔断**：单源连续失败 5 次进入熔断，60 秒后半开重试。熔断状态在源列表 UI 上可见。

## 4. 沙箱与权限

分层防护，不依赖单一机制：

| 层 | 措施 |
| --- | --- |
| 进程 | 独立子进程；Windows 用 Job Object 限制内存与子进程创建；不继承主进程句柄 |
| 文件系统 | 子进程工作目录限定在 `%APPDATA%/MiStream/sandbox/{runtimeId}/`；运行时层面不暴露文件 API |
| 网络 | 所有网络必须经宿主 `req`，由主进程统一发起 → 可施加协议白名单（仅 http/https）、私网地址拦截（防 SSRF）、超时、大小上限、代理与 DoH |
| 内存/CPU | QuickJS 内存上限 + interrupt 超时；进程级 RSS 监控，超限杀掉重启 |
| 数据 | `local` 存储按源命名空间隔离，单源配额（默认 5MB） |

**SSRF 防护是硬要求**：源脚本可以请求任意 URL，必须在宿主 `req` 里拦截 `127.0.0.1` / `10.` / `172.16-31.` / `192.168.` / `169.254.` / IPv6 私网段，以及 `file://` `ftp://` 等非白名单协议。

## 5. TVBox 配置兼容层

### 5.1 解码链

实现位于 `packages/core_config/lib/src/config_decoder.dart`，两条入口：

**`decode(raw, {aesKey})` —— 三条解码路径依次尝试**

```
原始字节
 ├─ 明文 JSON（utf8 解码后 jsonDecode 成功）→ format=plain
 ├─ Base64（decode 后重入 JSON 解析）→ format=base64
 └─ AES-128-ECB（需调用方提供 aesKey，16/24/32 字节）→ format=aes
      └─ 都不匹配 → configDecodeFailed
```

**`decodeWithProbe(raw, {aesKey})` —— 解码失败后探测内容类型，给出可读错误**

三条路径失败后，按魔数/标记探测原始字节，命中即返回 `configNotJson`（`ErrorCode(1006)`）：

| 魔数 / 标记 | 判定 | message 前缀 |
| --- | --- | --- |
| `FF D8` | 图片（JPEG） | 图片（JPEG） |
| `89 50 4E 47` | 图片（PNG） | 图片（PNG） |
| `47 49 46` | 图片（GIF） | 图片（GIF） |
| `42 4D` | 图片（BMP） | 图片（BMP） |
| `<!doctype` / `<html`（大小写不敏感） | 网页（HTML） | 网页（HTML） |
| 其它 | 不明 | 回退 `configDecodeFailed` |

这一层探测的动机：现实中不少源的「接口地址」其实指向导航页，或对非 TVBox 客户端 UA 返回占位图（JPEG 伪装 `image/x-ms-bmp`）。让用户在引导页立刻看到「返回的是图片（JPEG），不是接口地址」，而不是困惑于笼统的「解码失败」。`ConfigImportService.import` 已默认走 `decodeWithProbe`。

**现实配置普遍是 JSONC**：字段后面跟一行免责声明、备用地址或分隔线是常态（实测某源配置含 29 行 `//` 注释）。`ConfigParser` 与 `ConfigDecoder` 都容忍 `//`、`/* */` 注释与尾逗号；注释被替换为**等量换行**而非直接删除，这样解析报错时的行号仍能对上原文。详见 `config_decoder.dart` 的 `normalizeJsonc`。

### 5.2 抓取层（ConfigFetcher）

实现位于 `packages/core_config/lib/src/config_fetch.dart`。

解码链之上还有一层「把字节拿回来」。它独立成类不是洁癖，而是因为**同一个地址对不同 UA 会给出完全不同的响应**——这个差异必须一次性收敛掉，否则引导页与安装服务会各写一份、各修一次 bug（本项目就吃过这个亏，见 §5.2.1）。

#### 5.2.1 UA 策略：首选 okhttp，浏览器 UA 仅作回退

| 常量 | 值 | 用途 |
| --- | --- | --- |
| `kConfigFetchUserAgent` | `okhttp/3.15.0` | 默认首选 |
| `kConfigFetchBrowserUserAgent` | Chrome 120 桌面串 | 拿不到配置内容时回退一次 |

TVBox 客户端跑在 Android 上、走 OkHttp，服务端据此识别「这是 TVBox 客户端」。所以**拉配置要装成 okhttp**。

> ⚠️ 这与媒体请求的取向**正好相反**：媒体/封面请求要装浏览器（见 `docs/04` 的 headers 透传，否则 CDN 拒绝）。两处不要互相「统一」，也不要把 UA 抽成一个全局常量。

实测（2026-09-24）：

| 域名 | `okhttp/3.15.0` | Chrome 桌面 / Dalvik / curl / 空 |
| --- | --- | --- |
| `www.饭太硬.cc`（`xn--sss604efuw.cc`） | `200` · 19683 字节 · `image/x-ms-bmp`，首 4 字节 `ff d8 ff e0` = **JPEG 占位图** | `302` → `http://www.xn--sss604efuw.cc/` → `200 text/html` 首页 |
| `www.饭太硬.net`（`xn--sss604efuw.net`） | 同一张占位图 | **与 okhttp 结果相同**（`ETag: "6ab16dd5-4ce3"`） |
| `饭太硬.top`（`xn--sss604efuw.top`） | 连不上 | `200 text/html` |

两条可确认的结论：

1. **`.cc` 确实按 UA 分流**：`okhttp` 走一条分支（`200`），其余一律 `302` 到首页。
   也就是说**用浏览器 UA 打它必然拿到 HTML**——随后被 `probeNonJson` 判成
   「网页（HTML）」。错误文案本身没错，但根因在抓取层，不在解码层。
2. **本环境（数据中心出口 IP）拿不到该源的可用配置**：`okhttp` 分支返回的也是
   占位图而非配置，补试 TVBox 的完整请求头组合（`Accept` /
   `Accept-Encoding: gzip` / `Connection`）也无改善；`.net` 更是对所有 UA 都
   给同一张图。这指向**出口 IP 被整体拒绝**——UA 只决定你拿到哪种拒绝形态。
   故「装了 okhttp UA 就能导入成功」在本环境**无法验证**，只能靠真实用户网络。

中文域名在代码里应存 punycode 形式（`Uri` 会自行转换）。

#### 5.2.2 `fetch(url)` 流程

```
userAgent 显式给定 ──> 单次尝试
未给定 ──> okhttp 试一次 ──成功──> 返回
              │
            失败
              ↓
        浏览器 UA 试一次 ──成功──> 返回
              │
            失败
              ↓
        两次结果都写进错误 message 与 diagnostics
```

**判据可注入**（`ConfigBodyVerdict`）：默认 `defaultConfigVerdict` = 「空响应」+ `ConfigDecoder.probeNonJson`。只排除「明显不是配置」的内容，是因为**能不能解码是解码层的事**——抓取层不该替它下结论，否则将来放宽解析器时会误杀合法内容。

**重定向手动跟随**（`followRedirects = false`）：目的不是拿最终地址，而是**留下整条链**。排障时「302 到哪儿去了」比「最终 200」有用得多。相对 `Location` 按当前 URL `resolve`，`Location` 缺失/成环时终止（`maxRedirects` 默认 5）。

**诊断字段**（`ConfigFetchDiagnostics`）：`requestedUrl` / `userAgent` / `statusCode` / `contentType` / `byteLength` / `redirectChain` / `note`；`describe()` 产出单行摘要，`toDetail()` 产出结构化 map 供 §5.5 源诊断面板使用。示例：

```
HTTP 200 · text/html · 12486 字节；重定向 http://…/tv → http://…cc/
```

**失败文案保留原 `ErrorCode`，只追加 note**：

```
返回的是网页（HTML），不是 TVBox JSON 配置；请确认接口地址（两次 UA 都试过；浏览器 UA 的结果：HTTP 200 · text/html · 12486 字节；重定向 …/tv → …cc/）
```

`AppError` 是 sealed，`_withNote` 用 `switch` 覆盖全部子类——**将来新增错误类型会编译报错**，强制把 note 逻辑补上，不会静默丢诊断。

**调用方**：引导页（`onboarding_page.dart`）与安装服务（`config_install_service.dart`）都走 `ConfigFetcher`，不再各自持有 HTTP 客户端与 UA 常量。安装服务允许注入 `ConfigFetcher` 以便测试；未注入时自建并在 `finally` 里 `close()`。

### 5.3 字段映射

| TVBox 字段 | MiStream 领域模型 | 说明 |
| --- | --- | --- |
| `spider` | `SpiderBundle{url, md5}` | 全局 jar 地址，带 md5 校验；jar 不可用时不阻塞其它源。**md5 是拼在 URL 后面的**（`<url>;md5;<hash>`），不是另起一个键；拆分见 `parseSpiderField`。非标准的 `spider_md5` 键作为兜底 |
| `sites[]` | `SourceSite` | 见下方 type 映射 |
| `sites[].ext` | `SourceSite.extend` | 可能是内联 JSON、URL 或 base64，需二次解析 |
| `lives[]` | `LiveGroup` / `LiveChannel` | 支持 m3u 与 txt 两种订阅格式 |
| `parses[]` | `ParseRule{name, type, url, ext}` | type: 0=嗅探 1=JSON接口 2=聚合 3=WebView |
| `flags[]` | `List<String>` | 解析器适用的播放线路 |
| `rules[]` | `SnifferRule` | 嗅探规则：`host` + `regex` 命中/排除 |
| `wallpaper` | `AppConfig.wallpaperUrl` | 可选 |
| `doh[]` | `DohProvider` | 映射到 Dio 的 DNS 层 |
| `ijk[]` | — | **忽略**（ijkplayer 专有），必要时映射到 mpv 选项 |

### 5.4 site type 映射

判定只有一处实现：`core_domain` 的纯函数
`classifySiteRuntime({typeCode, api})`（`packages/core_domain/lib/src/site/site_runtime.dart`）。
分发（`spider_host` 的 `SpiderRuntimeFactory.create`）、UI 灰显
（`search_engine` 的 `SourceOption.hasRuntime`）、落库
（`apps/mistream` 的 `ConfigInstallService`）三处**都必须调它**，
不要各写一份 switch——实测就是因为三把尺子不一致，105 个站点被误判为全部可用。

| type | 语义 | `SiteRuntimeKind` | 实际运行时 |
| --- | --- | --- | --- |
| `0` | XPath / CSP 网页解析 | `js` | JS，**用内置通用脚本**（`type0Script`）。`api` 是站点基础地址而非脚本路径，宿主无从加载，故由子进程用 `builtin: 'type0'` 兜底 |
| `1` | JSON API（苹果 CMS 风格） | `http` | HTTP（内置 API 适配器，零脚本） |
| `3` | Spider，**要看 `api`** | `api` 以 `csp_` 开头 → `jvm`；否则 → `js` | JVM（jar 类名）或 JS 脚本 |
| `4` | JSON API 变体 | `http` | HTTP |
| 其它 | 未知 | `unsupported` | 不创建，UI 灰显并说明原因 |

**注意**：`type=3` 且 `api` 为 `csp_XXX` 的，需要从全局 `spider` jar 中加载类 → 走 JVM 运行时 → 属于降级范围（ADR-006，JVM 是可选组件）。**只看 `typeCode` 分不出这一类**，所以 `api` 必须一起看。UI 上要能一眼看出哪些源因运行时缺失而不可用。

**实测（2026-09-25，`qist/tvbox` 的 `xiaosa/api.json`）**：105 个站点全部是
`type=3` + `csp_`，未装配 JVM 时 `listSources()` 判为可用 **0** 个，
`getHomeData()` **2ms** 返回「无可用站点」。修复前它会挨个去建运行时
（8s 超时 × 105），烧光 30s 探测预算后报「所有站点均无法连接」——
错误信息完全指不到根因。

**type=0 内置脚本的 `ext` 约定**（`runtimes/spider_js/lib/src/drpy/type0_script.dart`）：

`type=0` 的 `api` 是站点基础地址，不是脚本路径，所以子进程用内置的
`type0Script` 兜底，规则全部由源配置的 `ext` 字段驱动：

```json
{
  "homeUrl": "https://example.com",
  "homeRule": "body&&.list&&a&&href",
  "listTitleRule": ".list&&span&&Text",
  "listPicRule": ".list&&img&&src",
  "listRemarksRule": ".list&&em&&Text",
  "classes": [{"type_id": "1", "type_name": "电影"}],
  "categoryUrl": "https://example.com/list/{tid}-{pg}.html",
  "categoryRule": "body&&.list&&a&&href",
  "nextPageRule": "a.next&&href",
  "detailRule": {
    "vodName": "h1&&Text",
    "vodPic": "img&&src",
    "vodContent": ".desc&&Text",
    "vodPlayFrom": ".playlist&&h3&&Text",
    "vodPlayUrl": ".playlist&&a&&href",
    "vodPlayUrlName": ".playlist&&a&&Text"
  },
  "searchUrl": "https://example.com/search?wd={wd}",
  "searchRule": "body&&.list&&a&&href"
}
```

`classes` 也接受 drpy 的字符串写法 `名称$值#名称$值`。`categoryUrl` / `searchUrl`
里的 `{tid}`/`{pg}`/`{wd}` 是占位符，另外接受 `{id}`/`{cateId}`/`{page}`/`{catePg}`/
`{key}` 等别名。

约定与坑（**每一条都是实测踩过的**，改动前先看 `type0_end_to_end_test.dart`）：

- **入口函数名必须是 `home`/`category`/`detail`/`search`/`play`**。脚本一度只有
  `homeContent`/`categoryContent`/…（drpy 内部名），而宿主取的是 `home`，两边都
  不报错，结果是源能加载、能调用、首页永远空白。
- **输出字段必须是 snake_case**：`vod_id`/`vod_name`/`vod_pic`/`vod_remarks`/
  `vod_content`/`vod_play_from`/`vod_play_url`/`type_id`/`type_name`。解析方在
  `search_engine` 的 `home_use_case.dart` 与 `apps/mistream` 的 `detail_use_case.dart`。
- **`req` 返回 `{content, headers, code, url}`，不是裸字符串**。把整个对象喂给
  `pdfh`，跨到宿主那边会被 `toString()` 成 Dart Map 的 `{content: …}`，一条都抽不出来。
- **列表里的链接与封面要补成绝对地址**（`joinUrl(页面地址, 相对地址)`），
  否则 `vod_id` 是相对路径，详情页请求会打到错误的主机。
- **`ids` 是按字符串传的**（TVBox 约定，多 id 逗号分隔），不是数组。写 `ids[0]`
  拿到的是首字符。
- **刻意不定义 `homeVod()`**：宿主的 `spider.home` 把 `home()` 与 `homeVod()` 的
  结果合并、后者覆盖前者，两个都定义会让首页抓两次且列表被后一次覆盖。
- **播放地址只抽一条线路**。通用 XPath 规则分不出「哪些链接属于哪条线路」，
  多线路源需要源专属脚本。

落库的 `sites.runtime` 列是上面这张表的**冗余缓存**（写 `SiteRuntimeKind.wireName`），
不是输入。运行时实际按 `typeCode` + `api` 现算，所以这一列与代码不一致时以代码为准。


### 5.5 源诊断面板

一个专门的设置页，对每个源显示：运行时类型、状态（就绪/熔断/不支持）、最近一次调用耗时与错误、`init` 返回的能力位、以及一个「测试」按钮跑 `homeContent + search("测试")`。这是用户和源作者排障的主入口，必须进 v1.0。

## 6. 嗅探器（Sniffer）

用于 `parse=1` 且无解析器命中、或 `type=0` 网页源的场景。

```
sniffer 进程（WebView2 / WKWebView / CEF）
 → 通过 CDP 加载目标页面
 → 监听 Network.responseReceived / Network.requestWillBeSent
 → 按规则匹配 URL：
     命中扩展名 (.m3u8/.mp4/.flv/.mkv) 或 Content-Type (video/*, application/vnd.apple.mpegurl)
     排除规则（广告域名、统计脚本、缩略图）
 → 命中即返回 URL + 该请求的完整 header
 → 超时（默认 20s）或页面加载完成仍无命中 → 失败
```

- 进程用完即杀，不复用 profile，不持久化 cookie（除非源显式要求）。
- 规则来自配置的 `rules` 字段 + 内置的通用广告过滤名单。
- 嗅探过程对用户可见（可选的调试窗口），便于源作者调规则。
- 嗅探永远是最后手段：慢、不稳定、资源开销大。

## 7. 聚合搜索的并发控制

```
全局并发上限：8（可配置 1–32）
单源超时：8s（可配置）
单源结果上限：50 条（防止某源刷屏）
去重：标题归一化（去空格/全半角/常见后缀）+ 年份 → 同一作品的多源结果合并为一张卡片
排序：源优先级 → 标题相关度 → 有封面优先
```

结果通过 `Stream` 增量吐给 UI，不等全部完成。慢源的结果晚到即插入，不打断已显示内容的滚动位置。

## 8. 缓存

| 内容 | 键 | TTL | 存储 |
| --- | --- | --- | --- |
| `homeContent` 分类 | `(sourceId)` | 6h | SQLite |
| `categoryContent` 列表 | `(sourceId, tid, page, filterHash)` | 30min | SQLite |
| `detailContent` | `(sourceId, vodId)` | 2h | SQLite |
| `searchContent` | `(sourceId, key, page)` | 10min | 内存 |
| `playerContent` | 不缓存 | — | — |
| 封面图 | URL | 7d | 磁盘（LRU，上限 500MB） |

播放地址**绝不缓存**——多数源的直链带时效签名，缓存必然导致播放失败。

## 9. 错误分类

RPC 错误码详见 [08-RPC协议](08-RPC协议.md)，此处是语义分类：

| 类别 | 示例 | UI 表现 |
| --- | --- | --- |
| 配置错误 | 无法解析配置、type 不支持 | 导入时即报，指出具体字段 |
| 运行时缺失 | 需要 JVM 但未安装 | 源灰显 + 「安装运行时」按钮 |
| 脚本错误 | JS 抛异常、语法错误 | 源诊断面板显示堆栈，可复制 |
| 网络错误 | 超时、DNS 失败、403 | 显示状态码，提示检查网络/代理 |
| 数据错误 | 返回空、字段缺失、格式不符 | 「该源未返回结果」，不当作崩溃 |
| 资源超限 | 内存超限、执行超时 | 熔断该源并提示 |

## 10. Spider SDK（v1.5 目标）

给源作者的开发工具，是插件市场能否长起来的前提：

- **类型定义**：`spider.d.ts`，含全部宿主 API 的 TypeScript 声明。
- **本地调试器**：`mistream spider dev ./my-spider.js`，起一个 REPL，可单独调用任一方法并打印结构化结果与耗时。
- **测试脚手架**：录制真实 HTML 快照 → 生成回归用例，源站改版时能快速定位。
- **校验器**：`mistream spider lint`，检查返回值 schema、必填字段、常见反模式（同步死循环、无超时请求）。
- **文档站**：API 参考 + 从零写一个源的教程。

## 11. 相关文档

- 进程协议 → [08-RPC协议](08-RPC协议.md)
- 插件形态的源分发 → [06-插件系统](06-插件系统.md)
- 起播编排 → [04-播放器设计](04-播放器设计.md) §7
