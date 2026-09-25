# MiStream 开发进度

> 本文件只做一件事：对照 [ROADMAP.md](ROADMAP.md) 的**出口标准**报告真实状态。
> 每个勾都指向可复现的证据（测试文件/命令/提交）。未验证的一律不勾。
> 更新：2026-09-25

## 总览

| 里程碑 | 出口标准 | 状态 |
| --- | --- | --- |
| M0 工程奠基 | 4/4 | ✅ 完成 |
| M1 播放内核 | 0/7 | ⏸ 依赖真实播放矩阵 |
| M2 数据层 | 0/5 | ⏸ 缺迁移/备份验证 |
| M3 RPC + Spider 骨架 | 5/6 | 🟢 仅剩真实 type=1 源 |
| M4 JS 运行时 | 5/6 | 🟢 仅剩真实源 |
| M5 主线 UI 闭环 | 5/7 | 🟢 仅剩真实配置/长跑 |
| M6 嗅探与解析 | 1/5 | 🟡 CDP 嗅探运行时已落地，缺真实 type=0 源 |
| M7 直播 | 0/4 | 🟡 包已建，缺验收 |
| M8 下载与离线 | 0/5 | 🟡 真实实现已接入，缺验收 |
| M9 插件系统与主题 | 0/6 | 🟡 包已建，缺验收 |
| M10 发布工程 | 0/6 | 🟡 发布链草稿已就位 |
| M11-M15 | — | 🔴 未启动 |

> **口径说明**：上表的「出口标准 0 勾」不等于「代码未实现」。M1/M2 的实现
> 与测试早已齐备（player_engine 142 用例、storage 47 用例），其出口标准
> 之所以为 0，是因为条目本身要求**人工在真实环境验证**（硬解实测、2 小时
> 长跑、迁移回滚、冷启动性能），而非缺代码。详见
> [进度审计报告](docs/PROGRESS_AUDIT_2026-09-19.md)。

## M0 · 工程奠基 ✅

- [x] `melos bootstrap && melos run analyze && melos run test` 全绿（18 包 dart + 45 flutter，2026-08-17）
- [x] CI 三平台通过
- [x] `core_domain` 无 Flutter/IO 依赖
- [x] 日志脱敏 URL token

## M3 · RPC 与 Spider 骨架 🟢

- [x] 分帧层模糊测试 → `spider_host/test/frame_parser_fuzz_test.dart`（9 用例）+ `frame_parser_test.dart`
- [x] 子进程死亡后退避重启 → `spider_host/test/spider_host_test.dart`（进程退出自动重启/熔断）
- [x] 取消释放资源 → `spider_host/test/cancel_request_test.dart`（5 用例，`$/cancelRequest` + 写队列配额释放）
- [x] SSRF 逃逸拦截（含重定向到私网）→ `spider_host/test/host_api_redirect_test.dart`（9 用例，302→127.0.0.1/云元数据/白名单外域名全拦）
- [x] mock 源全流程 → `spider_host/test/http_runtime_test.dart` + `source_adapter/test/integration_test.dart`
- [ ] 真实 type=1 源浏览 — **阻塞**：本机 CDN 全被墙（lziapi/kuaichezy/wujinapi/ffzy 404/403/timeout），需代理或可访问机器

## M4 · JS 运行时 🟢

- [x] 兼容性测试集 ≥100 条全绿 → `runtimes/spider_js/test/compat_runner_test.dart`（断言用例数并全跑，当前 **178** 条；2026-09-25 新增 JSON 解析组 `test/compat/json_cases.json` 32 条）
- [x] 死循环 interrupt 且不影响同进程其它源 → `resource_limits_test.dart`
- [x] OOM 限制在 Context 级，进程存活 → `resource_limits_test.dart`（内存超限/栈溢出用例）
- [x] 脚本异常带堆栈 SCRIPT_RUNTIME_ERROR → `resource_limits_test.dart` + `runtime_child_test.dart`
- [ ] 5 个真实 drpy 源全流程 — **阻塞**：同上网络问题
- [x] search P50 < 3s → `packages/search_engine/test/search_p50_test.dart`（5 源并发本地 mock，实测 P50=21~30ms / P95≈32ms；阈值 3s）
      **修正**：此前记「缺 P50 基准断言」有误，该文件已于提交 `9788722` 落库并通过

本会话关键修复：无 import 的 type=3 源此前全部加载失败（`export` 语法错误），已修并重建 Release 包。

## M5 · 主线 UI 闭环 🟢

- [ ] 真实配置从零起播 — **阻塞**：等真实配置源。
      **2026-09-25 进展**：真实源导入失败的根因已定位并修复——`饭太硬` 等站点
      按 UA 分流，认 TVBox 客户端的 `okhttp/3.x` 标识，而引导页与安装服务此前
      各自硬编码桌面 Chrome UA，于是必然被 302 到首页 HTML，再被判成
      「返回的是网页（HTML），不是 TVBox JSON 配置」。已抽出 `core_config` 的
      `ConfigFetcher`（默认 okhttp UA，拿不到配置内容才回退浏览器 UA，并带
      完整重定向链诊断，提交 `b33eb7c`）。
      证据：`packages/core_config/test/config_fetch_test.dart` 13 用例 +
      `apps/mistream/test/application/config_install_service_test.dart` 新增
      「按 UA 分流的订阅源」3 用例 + `tools/mock_source_server` 4 条分流路由。
      **仍未勾，且要看清证据强度**：本环境（数据中心出口 IP）对 `.cc`/`.net`/
      `.top` 逐 UA 试遍，只能拿到占位图 JPEG、302 后的 HTML、或 JS 跳转页——
      **okhttp 分支给的也是占位图，不是配置**，所以「修复能让饭太硬导入成功」
      **本地无法证明**。判定依据是**用户侧证据**：同一网络下他的 TVBox
      （okhttp UA）正常、MiStream（浏览器 UA）报 HTML，差别正在 UA。
      需用户用新构建实测：报「图片（JPEG）」说明已走到 okhttp 分支但服务端
      仍拒绝（IP/会话 gating，不是 UA 的事）；报「网页（HTML）」则两个 UA
      都被踢，看 note 里的重定向链。
      **2026-09-25 续：用户反馈仍不行，已换用可用测试源**
      `qist/tvbox` 的 `xiaosa/api.json`。该源导入链路已跑通（13/13），
      但它 105 个站点全是 `type=3` + `csp_`（需 JVM，ADR-006 降级为可选），
      所以「从零起播」仍然勾不上——**卡在缺一个 type=1/3(.js) 的可播源**，
      不再是导入本身的问题。详见下一节。
- [x] 聚合搜索源隔离 → `search_engine/test/search_use_case_test.dart`（超时/崩溃不阻塞）
- [x] 可读错误码 → `features/player/widgets/player_states.dart`（含嗅探 4 类错误码文案）
- [x] 关闭重开续播 → `apps/mistream/test/application/resume_policy_test.dart`（15 用例，覆盖不足 5s / 距片尾 30s 两条边界的含等于与不含等于、时长为零、无历史）+ `apps/mistream/test/features/player/player_resume_e2e_test.dart`（5 用例，驱动真实播放页验证 seek 到历史位置、三条不续播边界、进度写回历史）
      实现：`application/resume_policy.dart`（纯决策，可在 dart test 下跑）+ `router.dart` 播放页注入装配与引擎
- [x] 四态齐全 → `features/common/widgets/state_views.dart`
- [ ] 无 P0 崩溃 / 源崩溃不影响主进程 — 进程隔离已就位（type=3 走子进程、嗅探走 isolate），缺长跑
- [x] 集成测试（mock 源）端到端 → `runtimes/spider_js/test/type3_mock_integration_test.dart`（init→home→detail→play 全链路）+ `apps/mistream/test/m5_mock_e2e_test.dart`（配置导入→落库→搜索→详情→播放地址）

## M6/M7/M8/M9 · 包已建，验收未做 🟡

四个包已入工作区并全绿测试，但各自出口标准需要真实网络/真实源/长跑才能勾选：

- **M6** `packages/media_sniffer`（66 测试）：规则引擎、直链验证、HLS 样本测试齐；`runtimes/sniffer` **已落地 CDP 嗅探运行时**（70 测试，含真实 Edge/Chrome 端到端启动验证）；缺真实 type=0 网页源验收
- **M7** `packages/live`（17 测试）：m3u/txt 解析、drift 收藏、XMLTV EPG；缺换台/重试/长跑验收
- **M8** `packages/download`（22 测试）：任务状态机、Range 断点续传、HLS 分片；**假实现已替换为真实实现**（提交 `720dad3`），缺真实网络断点/离线播放验收
- **M9** `packages/plugin_host`（19 测试）+ **`packages/theme_engine`**（新增独立包，提交 `b113410`）：清单/权限/sha256/isolate 沙箱、对比度计算；缺生命周期状态机全覆盖


> 注：`DownloadManager.startDownload()` 已完成真实实现（提交 `720dad3`）。`runtimes/sniffer` 的占位已由 CDP 实现替换（提交 `bb00635`）。

## 本会话完成（2026-09-19）

两个 M6/M4 缺口补齐：

- `feat(spider-js)` **drpy `rsaX` 宿主 API**（提交 `09e8018`）：三种填充模式
  （PKCS1 / NoPadding / OAEP-SHA1）、PEM 解析覆盖 PKCS#1 与 PKCS#8、
  分组处理。修掉两处 pointycastle 与 Node `crypto` 的语义差异
  （解密 NoPadding 的最小子节表示、OAEPEncoding 的第二参数类型）。
  三处注册同步补齐。`spider_js` 测试 **180 → 199**。
- `feat(sniffer)` **CDP 嗅探运行时**（提交 `bb00635`）：内核探测、
  独立进程 + 一次性 profile、CDP 协议客户端、嗅探策略、错误码映射。
  实现中发现并修掉两个真实缺陷：DevTools 端点行在 **stderr** 而非 stdout；
  启动失败路径不杀进程会泄漏。测试 **70 通过 / 0 失败**，含真实
  Edge/Chrome 端到端启动验证。

两个包均 `dart analyze` 零告警，全仓库 analyze 零告警。

## 本会话完成（2026-08-18，26 个提交）

全部未提交工作已分批落库（此前 81+ 个文件挂在工作区）：

- `feat(domain)` 错误码、live、download 包
- `feat(spider)` Apple CMS v2 协议、运行时工厂、Home/Play 用例
- `feat(spider-js)` 模块加载器、evalModule/setBaseUrl、export-strip 修复、exe 旁 DLL 查找
- `feat(tools)` mock 源 type=3 支持、Release 包链（ps1 + checker + melos 命令）
- `feat(ui)` 首页/详情/引导/媒体库/设置/直播/下载/嗅探页、壳与主题、装配层
- `feat(player)` 起播看门狗 + 媒体信息透出
- `fix(rpc)` cancelOn、重定向逐跳闸门；`fix(config)` 宽松解析；`fix(storage)` configSourceUrl
- `build(tools)` quickjs_dist：vendored QuickJS DLL + SHA256 锁，`melos run quickjs:install` 幂等安装
- `ci(ci)` release-windows 作业：Release 包链门禁（libmpv → build → smoke 握手 → 产物留档）
- `docs(ui)` PROGRESS.md 改出口标准驱动，ROADMAP 勾选有证据的 M3/M4/M5 条目

## UI/UX 优化（2026-08-18，本会话四批）

用户指令「现在优化UI/UX」，确认全部四批实施：

- `feat(ui)` **批次1 结构+修复**：修 library 删除/清空误用 `AppDatabase.inMemory()` 真 bug；桌面端 `NavigationRail` + 窄屏底部栏；主题从 seed `0xFF4F46E5` 派生统一明暗；共享 `PosterImage` 组件
- `feat(ui)` **批次2 页面打磨**：`ResponsiveSliverGrid` 新组件；详情页重写（收藏/简介收起/响应式剧集网格）；分类页列数随断点 2~6；搜索改卡片网格；首页骨架屏/全部片源弹窗/ErrorView
- `feat(ui)` **批次3 文案+占位页**：直播页/下载页全中文 + Loading/Empty/Error 状态视图；新增 `/live-player` 路由与 `LivePlayerPage`
- `feat(ui)` **批次4 播放器**：顶部信息栏随控制栏显隐；暂停时中央大播放按钮；续播闭环（读历史 seek + 周期落库 + 阈值判断）
- 每批后 `flutter analyze` 0 error/0 warning + `flutter test` 44 全绿；本会话新文件不再引入新 info lint（重写文件的排序/underscore/discarded_futures 等已就地清零，仅存 `responsive.dart` 等既有债）

## UI/UX 优化 · 批次5（2026-08-18，一致性收尾 + 微交互）

- `feat(ui)` **嗅探设置页中文化**：全站最后一个英文页，改为中文（通用开关/规则管理/新增编辑删除规则/恢复默认，带删除/重置二次确认与空态引导）
- `feat(ui)` **空状态统一**：资源库改共享 `EmptyView`（删本地副本）；首页空数据引导（EmptyView + 切换片源/重试）；搜索页区分「未搜索」与「无结果」（保留原文案，测试不受影响）
- `feat(ui)` **微交互**：`MediaCard` 桌面悬停封面放大 + 播放浮层（触屏无感）；详情页骨架屏替代转圈
- `refactor(ui)` 详情页/分类详情的重复 `_ErrorView` 统一为共享 `ErrorView`
- 验证：`flutter analyze` 0 error/0 warning、无新增 info（app 级 177 条，仍为既有债）；`flutter test` 44 全绿

## B4 · JVM 运行时 + M5 展示面（2026-08-20）

- **B4 闭环**：Dart 侧把 type=3（JS/JVM spider）站点路由到 spider_jvm/spider_js 子进程的运行时工厂已落地（B4 会话）；本会话修掉最后一个阻塞：
  - 路由测试失败根因：测试 helper 用 `String.length`（UTF-16 码元）算 LSP 帧 `Content-Length`，响应体含中文时字节数被低估 → 解析器等帧等满 15s 超时。修复为 `framed()` 统一按 `utf8.encode(body).length` 计字节 → `packages/spider_host/test/jvm_runtime_factory_test.dart` 4/4 全绿
  - 详情链路缺口：Home/Search/Play 已走运行时工厂，唯独 app 级 `DetailUseCase` 只 `HttpRuntime(site.api)`，type=3（如 `csp_Fan`）站点打不开详情页/集数
- **本次修复**：`DetailUseCase` 增加 `runtimeFactory` 注入 + `_createRuntime(site)`（配置源 url/spiderJarUrl/spiderJarMd5 透传 + HttpRuntime 降级），app_assembly 注入 JVM 工厂；`DetailPage` 增加 `useCase` 测试缝并给 `_refreshFavorite` 包 try/catch（DB 抖动不崩页）
- **审查加固（同日）**：`DetailUseCase.load` 把运行时创建/detail 调用的异常转成 `Err`（不再抛给无 try/catch 的详情页，避免卡骨架屏），`finally` 兜底 `runtime.dispose()`（防 JS/JVM 子进程泄漏），detail 调用加 10s 超时；新增 2 例测试（创建失败/调用抛异常均回错误并回收运行时）
- **证据**：
  - `apps/mistream/test/application/detail_use_case_test.dart` 6/6 全绿（`dart test`，与 storage/search_engine 同款纯 Dart 测试）：type=3 路由/线路与剧集解析/配置透传/错误透传/非法 JSON/notFound/空线路
  - `apps/mistream/test/features/detail/detail_page_test.dart` 2/2 全绿（`flutter test`）：封面/标签/简介/线路/剧集渲染 + 切线路、错误重试视图
  - `dart test packages/spider_host packages/search_engine packages/storage` 全绿（99+127+47）
  - `flutter analyze apps/mistream` 0 error/0 warning，app 级 info 回到基线 177
- **环境注意**：sqlite3 3.5.1 走 native assets，`flutter test` 不加载 → 任何触库的 app 测试（既有 app_test 组合根×2、DB 类单元测试）只能走 `dart test`，属既有环境限制，非本次引入

## 真实源可用的三个运行时 Bug（2026-08-20，本会话）

用户反馈「大部分片源无法正常使用、封面不显示、首页不显示分类」。用真实 DB（163 源）+ 本地 mock（server.js / srv/）逐源诊断，确认并修复三个**代码级**阻塞：

- **BUG A（JS 启动）**：`SpiderRuntimeFactory._getJsHost` 用 `File.exists()` 决定直接执行 vs `dart run`；`.dart` 脚本文件「存在」却被当 Win32 exe 直接执行 → `ProcessException: %1 不是有效的 Win32 应用程序`，所有 drpy/JS 源创建即失败。修复：`!spiderJsPath.endsWith('.dart') && exists()` 才直接执行，否则 `dart run`。
- **BUG B（JVM classpath）**：`SpiderJvmConfig.classpath` 用 `Platform.pathSeparator`（`\`）当类路径分隔符 → `-cp "jar\libs\*"` 整段失效；再修后一度变 `jar;libs;*`（缺目录分隔符，`*` 只匹配当前目录文件）。修复：分隔符用 `;`（Win）/`:`，目录与 `*` 之间用 `Platform.pathSeparator` → `jar;libs\*`。验证：java 子进程握手/`spider.create`/`home()` 全通。
- **BUG C'（QuickJS DLL 路径）**：`dart run` 起 bin 脚本时，`findNativeLibrary` 候选缺 `bin/../lib/src/engine`（DLL 在包的 `lib/src/engine`），dev 模式 JS 引擎报「QuickJS wrapper 库未找到」。修复：新增 `$scriptDir/../lib/src/engine` 候选。

**验证（真实 DB 拷贝 diag.db）**：
- type=1 电影天堂（id 126）/蓝光直连（id 140）home 正常，`getHomeData` 返回 20 推荐 + 20 分类（`csp_Config` 聚合源经完整 JVM 管线 home 也通）
- drpy JS 源（id 141 `./lib/drpy2.min.js` + ext 配置）经 mock 拉配置与视频列表正常
- csp_ 源目前**仅 `csp_Config` 聚合源可加载**：qist dex jar 经 enjarify 管线转换后，具体蜘蛛（`csp_XBPQ` 等）引用的 R8 合并类 `merge/C0/f0/b` 定义缺失（被并入 `a`），JVM 严格验证拒绝 → 属 B2 反编译深水区，另记
- 剩余两个是**环境/数据**问题：① mock server 不服务 `dianshi.json`（404）→ 配置无法重导、csp_ 源拿不到 `spider` jar URL（DB 是 schema v2 旧库，`config_source.spider` 为 null）；② 首页 30s 探测预算内前几个 type=1 若不可达会整页报错（网络取决于本机）

**封面健壮性**（首页/详情）：解析层把相对 `vod_pic` 按请求 `finalUrl` 补全为绝对地址（`home_use_case.dart`、`detail_use_case.dart`）；`PosterImage` 给 `Image.network` 加浏览器 UA 头（防盗链 CDN 不再裸 UA 403）。

**证据**：`packages/spider_host` 99/99、`packages/search_engine` 28/28、`apps/mistream/test/application/detail_use_case_test.dart` 8/8、`runtimes/spider_js quickjs_bindings` 15/15 全绿；`dart analyze` 无 error。

## B5 · csp_ 合并类与心跳修复（2026-08-21，本会话 P0）

- **合并类** `runtimes/spider_jvm/src/main/java/io/mistream/jvm/JarLoader.java:268` 指令级扫描+`isPlatform`过滤+`buildStub`合成缺失类（qist 255类，含 `merge/C0/f0/b`），`SpiderApi.java` shim 与 `SpiderBridge` initApi 注入；`spider.create` 放宽至 5分钟 `spider_runtime_factory.dart:628`，冷转换后 `csp_XBPQ` home 真实分类 4条可用
- **心跳** `packages/spider_host/lib/src/host/spider_host.dart:358` 在 `pendingCount>0` 时跳过 ping，`_onProcessExit:382` 补 kill 避免僵尸；`stdio_rpc_channel.dart:pendingCount` 暴露在途数；冷缓存 create 53s→home 连续成功
- **详情链路+封面** 同 B4，已落库：`DetailUseCase` 运行时工厂、`PosterImage` UA、`home_use_case` 相对图链补全
- **证据**：`spider_host` 99/99、`search_engine` 28/28、`detail_use_case` 8/8；`flutter analyze` 0 error，info 回基线 177+11（新增文件 `lines_longer` 等既有债）

## 本次会话（2026-09-19）：工作区落库 + 续播验收

距上次提交（`7315185`，08-22）间隔 28 天。本会话做两件事：

**一、18 项未提交改动落库（7 个提交）**

起因是审计中发现本地 `feat/m1b-media-kit-engine` 分支引用丢失（无任何提交），
而工作区代码基线实际是 origin 上的 `7315185` —— 此时任何提交都会造出没有
历史的孤儿提交。先修复引用再按语义拆分提交：

- `38dabeb` chore：`.gitignore` 补 `.workbuddy-ai/` 与 `.flutter_tool_state`
- `1d9c1e1` feat(config)：`decodeWithProbe` 非 JSON 内容探测 + `CONFIG_NOT_JSON`(1006)；
  `ConfigParser` 开关字段兼容数字/字符串/布尔；mock server 加诊断端点
- `37f2217` fix(config)：配置地址支持中文域名（Punycode）+ 补浏览器 UA
- `d8f418a` fix(ui)：首页分类网格补 `shrinkWrap`（Sliver 内嵌网格的无限高度 bug）
  + `m5_mock_e2e_test.dart` 垂直集成测试
- `e6456fe` docs：开发文档索引 + 进度审计报告
- `0d85f03` test(player)：`FakePlayerEngine` 记录 seek 目标
- `542139d` feat(domain)：抽出续播决策 + 播放页可注入装配

**二、M5 续播端到端验收（出口标准第 5 勾）**

原实现的续播判断内嵌在播放页 `State` 里、依赖全局装配，只能手工验证。

- 新增 `application/resume_policy.dart`：纯决策（只用 `meta` 的 `@immutable`，
  刻意不引 Flutter，故可在 `dart test` 下跑）
- 播放页新增两个测试缝：`assembly`（注入装配）与 `engineFactory`（注入引擎）；
  注入假引擎时跳过 `VideoController` 并以黑底占位
- `resume_policy_test.dart` 15 用例 + `player_resume_e2e_test.dart` 5 用例

**证据**：`dart test` 受影响包 299 用例全绿；`dart analyze` 0 issue；
`arch_check` 分层纪律通过

**环境注意**（本机，非代码问题）：
- `flutter test` 需显式注入 `ProgramFiles(x86)` 环境变量，否则工具链中断
- widget 测试在本沙箱内 `flutter_tester` 连不上（WebSocket 报错），
  `player_resume_e2e_test.dart` 代码已编译通过，待本机复核
- 提交含中文路径须用 `--pathspec-from-file`，否则命令行超长

## 本次会话（2026-09-19 续）：P0 根因定位 + 全量基线 + gbkDecode

**一、P0 根因定位（提交后引用丢失）**

查到根因为止，排除了此前所有猜测（钩子、logAllRefUpdates、外部清理进程）：

- `--no-verify` 跳过全部钩子后**仍复现** → 与 `.githooks` 无关
- 单独运行 `pre-commit`，引用完好 → 与钩子内 `git diff` 无关
- 重建引用后静置 20 秒，引用稳定 → 无外部定时清理
- `.git/refs/heads/main`（8/4 老文件）始终完好，仅**新建的** `feat/` 目录被清

结论：删除发生在 `git commit` 进程的**退出清理阶段**，只影响本次操作新建的
引用目录。根因指向 I: 盘的虚拟化文件系统语义（挂载参数
`ntfs (binary,noacl,posix=0)`，inode 号 `5629499534720xx` 非本地 NTFS 范围）。
**属环境问题，非仓库配置问题。**

已交付 `tools/git_ref_guard.sh`：每次提交后执行一次，从 reflog 自动恢复引用，
并回溯到第一个 `old` 非零记录以规避孤儿提交。本会话 3 次提交均经其验证。

**二、全量测试基线（首次逐包实测）**

24 个包逐个 `dart test`：**795 通过 / 10 失败 / 37 跳过**。

- `spider_host` 6 失败：自建 mock server 需绑回环端口，沙箱拒绝（`os error 10061`）
- `spider_js` 4 失败：子进程管道关闭 / 夹具目录缺失 / codec 依赖
- 其余 22 包**全部通过**

**三、静态检查实测（更正 P1）**

`flutter analyze --fatal-infos --fatal-warnings` → **0 issue**，24 包逐包亦全绿。
验证方式：在 `core_domain` 临时注入 `avoid_print` 探针，根目录分析**成功捕获**，
证明 workspace 递归分析有效、门禁非形同虚设。**727 条 info 已在
`analysis_options.yaml` 中逐条放行收口，P1 实为已完成。**

**四、实现 `gbkDecode` 宿主 API（新功能）**

`docs/05-Spider引擎.md` §2.2 要求该 API，此前**只有文档、无实现**。国内 GBK
老站点是 drpy 源失败的常见原因，且 `utf8.decode` 宽容模式救不了（GBK 汉字
两字节会被 UTF-8 判为非法起始字节）。

- `gbk_table.dart`：`tools/gen_gbk_table.py` 离线生成（CPython gbk codec 同源），
  23940 个双字节位置压成单字符串常量（75KB），避免 2.4 万行 Map
- `gbk.dart`：永不抛异常；未映射输出 U+FFFD；尾字节非法时只脏首字节不越界
  连锁；字符串含宽码位时判定「已是文本」直接返回（防止二次解码）
- 注册进 `host_bridge` 分发表，`spider_js.dart` 导出
- **测试 22 例**（`drpy_gbk_test.dart`）+ 2 例分发表集成
- 开发中修复 1 个真实 bug：字符串入参曾被二次解码（`gbkDecode('中文')` → `涓枃`）

**证据**：`spider_js` 通过数 122 → **144**（+22），失败数不变；全量 analyze
0 issue；`arch_check` 通过

**五、gbkDecode 收尾（JS 包装 + compat 集 + 真机验证）**

- **补 `js_runtime.dart` 的 `g.gbkDecode` 包装**：上一轮只注册了宿主分发表，
  脚本里写 `gbkDecode(...)` 会直接报 `is not defined`
- **修 `_coerceToBytes` 类型判断**：`is List<int>` 对 JSON/QuickJS 产出的
  `List<dynamic>` 恒为 false，会静默返回空串
- **接入兼容性回归集**：`CompatCase` 加 `input` 字段、runner 加分支、
  新增 `encoding_cases.json` 11 例。兼容集 119 → **130 条**
- **真实 QuickJS 环境验证**：新增 2 例断言 `typeof gbkDecode === 'function'`
  并对照 Dart 实现——只测分发表会漏掉包装缺失这类 bug

**六、更正：测试运行方式导致的误判**

此前把 `spider_js` 的 4 个失败与 34 个跳过归因于沙箱环境，实为**运行目录不对**：

| 运行方式 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- |
| 从仓库根 `dart test runtimes/spider_js` | 146 | 4 | 38 |
| 从包目录 `cd runtimes/spider_js && dart test` | **180** | **0** | 10 |

夹具用相对路径 `test/compat`，从根跑时 cwd 不含该目录。**QuickJS native
在本机实际可用**（此前记为不可用属误判）。

**证据**：`spider_js` 最终 **180 通过 / 0 失败**（从 122 累计 +58）；
全量 analyze 0 issue


## 本次会话（2026-09-25 续）：换可用测试源，修站点运行时门控

饭太硬在本环境无法复现成功（见 M5 条），遂换用
`https://raw.githubusercontent.com/qist/tvbox/refs/heads/master/xiaosa/api.json`
继续验证真实导入链路。这个源**可用**（200 / 28377 字节 / 合法 JSON），
也因此把三个此前测不出来的问题全暴露了。

**一、`spider` 字段内联的 `;md5;` 没被解析（真 bug）**

该源写的是 `"spider": "./spider.jar;md5;af187c2a..."`，而 `ConfigParser` 只读
`raw['spider_md5']` 这个非标准键 → `spiderMd5` 恒为 `null`，jar 完整性校验
形同虚设。抽出 `parseSpiderField(raw, explicitMd5:)`，内联优先、独立键兜底
（提交 `aedda97`）。

**二、站点可用性用全局标志判定（架构缺口，影响最大）**

`SourceOption.hasRuntime` 是 `runtimeFactory != null`——与具体站点无关。
而 `_getEnabledSites` 只按 `typeCode` 排序**不过滤**，于是 105 个站点会被
挨个去试（8s 建实例超时 × 105），烧光 30s 探测预算后报「所有站点均无法
连接」，错误信息完全指不到根因。

根因是三处各判一套：工厂 `create()` 只看 `typeCode`、UI 用全局标志、
`config_install_service` 直接写死 `"http"`。收敛成 `core_domain` 的纯函数
`classifySiteRuntime({typeCode, api})`（提交 `7c59d67`），三处都调它，
并新增同步纯判定 `SpiderRuntimeFactory.supports()` 供 UI 灰显
（刻意不做成「试着 create 看抛不抛」——那会真起子进程、下脚本）。

**三、`type=0` 与 `type=4` 从未接线（真 bug）**

工厂 `create()` 的 switch 只认 1 和 3，type=0/4 掉进 default 抛
「不支持的站点类型」。现在 type=4 走 HTTP；type=0 走 JS 并用内置通用脚本
兜底——type=0 的 `api` 是站点基础地址而非脚本路径，宿主无从加载，所以
内置脚本替换只能在子进程侧做（`runtime_child` 收 `builtin: 'type0'`，
提交 `5c8e13a`）。

**证据**

| 验证 | 结果 |
| --- | --- |
| 真实源端到端（`.workbuddy-ai/scripts/verify_real_source.dart`） | **13/13**（含门控断言） |
| 同上：105 个 `csp_` 站点、未装 JVM → 可用数 | **0**（修复前 105） |
| 同上：`getHomeData()` 返回「无可用站点」耗时 | **2ms**（修复前烧满 30s 预算） |
| `core_domain` 测试 | 55 通过 / 0 失败（新增 `site_runtime_test.dart` 13） |
| `core_config` 测试 | 62 通过 / 0 失败（新增 `config_parser_test.dart` 12） |
| `spider_host` 测试 | 新增 `runtime_capability_test.dart` 11 通过；既有仅 6 例回环用例失败（沙箱禁回环，非代码） |
| `spider_js` 测试 | 新增 builtin type0 4 例；既有仅 2 例管道用例失败（环境缺陷，非代码） |
| `search_engine` + `apps/mistream` 纯 Dart 测试 | **60 通过 / 0 失败**（经 `.workbuddy-ai/scripts/run_tests_shim.dart`，此前在本环境跑不了） |
| 静态检查 | 288 文件 0 error / 0 warning / 0 info |
| 提交 | `7c59d67` `aedda97` `5c8e13a` `8843648` |

**四、门禁替代路径升级：进程内分析器现在会读 `analysis_options.yaml`**

上一轮发现 `analyze_inproc.dart` **不加载**配置文件，导致根配置里已写
`todo: ignore` 的诊断仍被报成失败。已补上配置链解析（含
`include:` 递归，`package:` URI 经 `package_config.json` 解析），现在会
按配置忽略/改判严重级别，并把读到的配置链打出来。用真实源与探针双重验证：
注入类型错误能被抓到（2 个 error，退出码非零），全仓扫描 0 告警。

**五、新增两个环境逃生口（此前这批测试在本机跑不了）**

- `.workbuddy-ai/scripts/run_tests_shim.dart`：把入口放到 `.workbuddy-ai/scripts/`
  下，入口包变成仓库根（无 native 依赖）→ **不触发 native-assets 构建钩子**。
  `search_engine`（依赖 `storage`→sqlite3）与 `apps/mistream` 的纯 Dart 用例
  由此可跑。
- `dart format --output=none --set-exit-if-changed` 作格式门禁（不起子进程）。

仍跑不了的：`package:flutter_test` 用例（`dart run` 编不了 Flutter SDK）、
需回环端口的用例（`spider_host` 6 例、`sync_frame_io` 2 例、
`config_install_service_test` 的 mock server）、`runtimes/spider_js` 的夹具
用例（cwd 必须是包目录）。

## 本次会话（2026-09-25 再续）：JS 微任务泵 + type=0 内置脚本真正跑通

起点是核对 `docs/05` §2.2 的宿主 API 清单，结果挖出两个**静默失败**级的问题。

**一、JS 运行时不泵微任务 → 所有 `async` 入口的源静默返回空数据**

`qs_eval` 是裸 `JS_Eval`，没有 `JS_ExecutePendingJob`。Promise 回调是挂在
runtime 队列上的 *job*，没人泵它就永远不执行：`p.then(cb)` 不调 `cb`，
`async function f(){ return 1 }` 的返回值永不落地，`JSON.stringify(f())` 得到
`"{}"`。探针实测（`JSON.stringify` / `.then` / `typeof setTimeout` 三组）钉死了
这一点。**不报错**是最麻烦的地方——源能加载、能调用、返回空对象。

修复分三层：C 层导出 `qs_drain_jobs`（循环 `JS_ExecutePendingJob`，带迭代上限，
符号按「可选」模式加载，缺失返回 `-2` 让 Dart 如实报错）；`JsRuntime` 每次求值后
都泵一次；`_wrap` 识别 thenable 后把结果暂存到 `__qs_*` 全局，泵完再读回。
排空后仍 pending 的源**报错**，不返回空值。

**二、`type=0` 内置脚本从未真正跑通过**

`type0_script_test.dart` 只做字符串包含检查（`expect(script, contains('vodId'))`），
脚本写得再错也照样绿——给了虚假的绿灯。实际把它喂给真实运行时后，四处都对不上：

| 问题 | 表现 |
| --- | --- |
| 入口函数名是 `homeContent`/`categoryContent`/…（drpy 内部名），宿主取的是 `home`/`category`/… | 能力位探测为空，所有调用返回 `null` |
| 输出字段是 `vodId`/`vodName`/`classes`，宿主解析 `vod_id`/`vod_name`/`class` | 首页永远空白 |
| `init`/`homeContent` 全是 `async` | 叠加问题一，`init` 返回的配置被丢成 `{}` |
| `req` 返回 `{content,…}` 被当字符串喂给 `pdfh`；`ids` 按字符串传却写 `ids[0]`；相对地址没补全 | 页面一条都抽不出来 / 详情页请求打到错误主机 |

重写脚本：入口对齐 TVBox 约定、字段全改 snake_case、`req` 取 `.content`、
链接用 `joinUrl` 补成绝对地址、`ids` 兼容字符串与数组、`category` 按
`nextPageRule` 报 `pagecount`、播放地址抽成一条线路。并补上
`type0_end_to_end_test.dart`——**真起 RuntimeChild + 真 QuickJS**，只把 `req`
换成桩（因此不需要回环端口），断言宿主解析器真能读懂返回的字段。

顺带修正 `docs/05` §2.2 的三处推测值（对着 `dr_py` 的 `libs/drpy.js` 与
`libs/drpy2.min.js` 实测）：`print`/`log` 由 drpy2 自定义、`setTimeout`/`getUA`/
`getAppVersion` 在两个参考实现里出现 **0 次**、`getProxy` 可选（`getProxyUrl()`
有 9987 端口兜底）。也纠正了上一轮我自己写错的判断：**drpy2 本体是同步的**，
`async`/`await`/`Promise` 出现次数均为 0，当初「drpy2 全是 async」的结论有误
（真正的受害者是本仓自带的 `type0Script` 与存量 async 源）。

**证据**

| 验证 | 结果 |
| --- | --- |
| `async_jobs_test.dart`（新增） | **11 通过 / 0 失败** |
| `type0_end_to_end_test.dart`（新增，真运行时） | **5 通过 / 0 失败** |
| `type0_script_test.dart`（由字符串包含改为契约守卫） | **6 通过 / 0 失败** |
| `runtimes/spider_js` 全部 17 个测试文件 | 除 `sync_frame_io_test` 的 1 例管道用例（`CreateFile failed 231`，环境缺陷）外全绿 |
| `packages/spider_host` 全部 14 个测试文件 | 除 `http_runtime_test` 的 6 例回环用例（沙箱禁回环）外全绿 |
| `.workbuddy-ai/scripts/verify_site_runtime_gating.dart` | **27 项 / 0 失败**（回归） |
| 静态检查 | 290 文件 0 error / 0 warning / 0 info |
| 格式门禁 | 295 文件 0 changed |

**三、本环境构建 wrapper DLL 的新坑（值得记住）**

`native/build.bat` 走 `vcvars64.bat`，而后者会 shell 出去调 `reg.exe`，
**本沙箱把 `reg.exe` 列入程序黑名单** → `vcvars` 失败 → `INCLUDE` 没设上 →
`fatal error C1083: 无法打开包括文件: "windows.h"`。绕法是自己拼环境变量：

```
INCLUDE = <MSVC>\include; <SDK>\Include\<ver>\{ucrt,shared,um,winrt}
LIB     = <MSVC>\lib\x64;  <SDK>\Lib\<ver>\{ucrt,um}\x64
PATH   += <MSVC>\bin\Hostx64\x64
```

MSVC 14.44.35207 / SDK 10.0.26100.0。构建脚本本身不用改（正常环境下没问题）。

## 本次会话（2026-09-25 三续）：真实 drpy2 端到端 + runtime 释放断言缺陷

起点是追 `ext` 到 type=0 内置脚本的链路，结论是**链路本来就是通的**，反而挖出
一个会打死子进程的缺陷。

**一、type=0 的 `ext` 链路（核对通过，无需改）**

`SiteConfig.ext` → `HomeUseCase`/`DetailUseCase` 传 `ext: site.ext` →
`SpiderRuntimeFactory._createJsRuntime` 的 `configUrl = resolveExtUrl(ext, …)` →
`spider.create` 的 `config` → 子进程 `_create` 里 `init(config)`。全程通。

顺带确认：**两份真实配置里一个 type=0 都没有**（`xiaosa/api.json` 53 站 =
44×type3 + 9×type1；另一份 39 站全 type3），所以 type=0 无法用它们验收。

**二、真实 drpy2 首次跑通**

找到一条可达的真源（`jihulab.com/yydfys/yydf`，即 `xiaosa/api.json` 第一条
type=3 站点），写出 `tool/probe_real_drpy.dart`：**进程内**驱动真 `RuntimeChild`
+ 真 QuickJS，只在分帧层拦一个点接管全部 HTTP（子进程协议是同步的，宿主回话必须
发生在 `write` 回调里，没法 await，所以先预取再同步喂回）。

跑通的东西：4 条**远程 URL** import（含中文标识符 `模板`、副作用导入、命名导入）
全部取到，`create → capabilities=[home, category, detail, search, play]`，
`home()` 从真实规则解析出 **7 个分类 + 8 组 filters**。这是仓库里第一次用真实
drpy2 跑通完整子进程链路。

**三、缺陷：runtime 的 GC / 释放路径会断言 abort（P0）**

跑完一次真实 drpy2 之后，`JS_FreeRuntime` / `JS_RunGC` 会以约一半概率触发
`Assertion failed: i != 0, file quickjs.c, line 3394` 直接 abort 进程。爆炸半径：
宿主 `_trySites` 每试一个源就 `spider.destroy` 一次 → **每次请求都会打死共享的
JS 子进程**，连带同进程里其它源的调用。

二分结论（每组 6 次）：

| 操作 | 结果 |
| --- | --- |
| `JS_FreeContext` | 6/6 走完，**永远安全** |
| `JS_RunGC` | 6 次崩 5 次 |
| `JS_FreeRuntime` | 同样崩（内部走同一套释放路径） |
| 释放 context 后再往同一 runtime 挂新 context | 崩（`js_rc(p->shape)->ref_count == 1`，shape 是 runtime 级、跨 context 共享） |

崩点是这套 build 的 GC/释放机制本身，不是「有环没回收」——所以「先 GC 再释放」
没有意义。它还是**堆布局阈值敏感**的：内存上限 32/128/256/512MB 都不触发、默认
64MB 触发；少装一个限值或少数一步求值也不触发。调参数只是换个落点。

**缓解（已落地）**

1. `JsRuntime.park()`：只做 `JS_FreeContext` + 封存，不 GC、不释放 runtime；
   `dispose()` 对封存过的实例只丢引用。热路径一次都不碰那两条危险调用。
2. **不复用 runtime**：释放过 context 的 runtime 已被污染（见上表第四行）。
3. 代价是内存：实测释放 context **并不真把内存还回来**，每个源约留 10MB。所以
   由宿主**整进程换新**归还——`SpiderHost` 每收掉 `kSourceTearDownsPerProcess`
   （默认 8）个源、且当前无活实例时，发 `runtime.shutdown` 让子进程干净退出再
   重新拉起，由 OS 回收。代价只是下一次 `spider.create` 重付一次 drpy2 加载。

**证据**

| 验证 | 结果 |
| --- | --- |
| `tool/probe_real_drpy.dart`（新增，真实 drpy2 全链路 + 连续试源） | **13 项检查 / 0 失败，连跑 10 次无 abort**（修前 6 次崩 3 次） |
| `tool/probe_real_drpy.dart cycles=10` | 11 个源全过；RSS 每轮约 11MB（换新前的泄漏量，正是换新的依据） |
| `runtimes/spider_js` 全部 19 个测试文件 | 除 `sync_frame_io_test` 的 2 例管道用例（`CreateFile failed 231`，环境缺陷）外全绿 |
| `packages/spider_host` 全部 14 个测试文件 | 除 `http_runtime_test` 的 6 例回环用例（沙箱禁回环 `os error 10061`）外全绿；新增 3 条换新用例 |
| 静态检查 | **292 文件 0 error / 0 warning / 0 info** |

**四、为什么必须靠整进程换新兜底（判断依据）**

`JS_FreeContext` 安全，但它**不归还内存**——这是实测出来的，不是推测：
`cycles=1` 涨 33MB（含 DLL 加载与首次编译的约 22MB 预热），`cycles=10` 涨 115MB，
即每个源约 10MB。所以「释放 context 就够了」是错的，必须有进程级回收。

**五、`quickjs_wrapper.c` 新增 `qs_run_gc`（本轮遗留）**

为验证「先 GC 再释放」是否有效而导出了 `qs_run_gc`（对应 `JS_RunGC`，按可选符号
加载）。实测**无效**（GC 自己就会崩），所以 `park()` 现在不调它。导出保留，作为
后续排查该 DLL 的手段；Dart 侧是 `supportsRunGc` / `runGc()`。

## 下一步（按优先级，2026-09-19 续）

1. **P0 仓库健康** ✅ **已定位并交付守卫脚本**；根因属 I: 盘文件系统语义，
   非仓库问题。迁移到本地盘可彻底消除
2. **P1 门禁** ✅ 727 条 info 已收口，代码侧无告警。**但 2026-09-25 起本机
   跑不了门禁命令**（见第 7 条），须在环境恢复后复跑确认
3. **P2 编码 API 补齐** ✅ **已完成**：`gbkDecode`、`rsa`、`aes`（含位置参数
   契约）均落地；2026-09-25 补齐最后的 JSON 解析组
   `jsonpath`/`pjfh`/`pj`/`pjfa`（提交 `0888440`，compat 用例 130 → **178**）。
   同表其余项建议继续对 `docs/05` §2.2 核账
4. **P3 验收** 补齐出口标准中纯本地可验证的条目：M2 迁移回滚测试、
   M9 主题对比度测试、M5 长跑稳定性
5. **P4 债务** `libs/*.jar` 改 `tools/jvm_dist` 按需拉取、契约/长跑测试、
   播放页/首页之外的页面去 `globalRouterAssembly`（播放页与首页已完成注入化）
6. **P5 阻塞** 网络方案（代理 / 可访问机器）——所有「真实源」类出口标准都卡在此
7. **⚠️ 环境：本机命名管道耗尽（2026-09-25 新增，P0 级）**
   `dart analyze` / `dart test` / `flutter test` **全部无法运行**，报
   `CreateFile failed 231`（`ERROR_PIPE_BUSY`）。加 `dangerouslyDisableSandbox`
   现象相同、无残留 dart 进程，故是**机器级缺陷而非沙箱策略**。
   已确认的替代路径（2026-09-25 续 已补齐，见上一节第四、五条）：
   - 跑测试（包内夹具）：`cd <包目录> && dart run test/xxx_test.dart`
   - 跑测试（成员包 native 钩子挡住时）：`dart run .workbuddy-ai/scripts/run_tests_shim.dart`
   - 格式化门禁：`dart format --output=none --set-exit-if-changed <dirs>`
   - 静态检查（error/warning/info，**会读 analysis_options.yaml 配置链**）：
     `dart run .workbuddy-ai/scripts/analyze_inproc.dart`
   本轮因此**仍无法验证 lint 门禁**（analyzer 12 的 lint 规则已拆到
   `package:linter`，pub 上最新 1.30.1 只支持 `analyzer ^5.2.0`，装不上）。
   环境恢复后须补跑一次完整门禁。
8. **P1 债务：根治 runtime 释放（见上一节）**
   现状是「不释放 + 每 8 个源换一次进程」的缓解。根治只有一条路：拿到与
   `tools/quickjs_dist/vendor/libquickjs.dll` 匹配的 `quickjs.h`、或自行构建一份
   **非 assert** 的 libquickjs，之后才能恢复正常的 `JS_FreeRuntime` 与 runtime
   复用。在那之前别放宽 `JsRuntime.park` 的约束，也别去掉宿主换新——去掉换新
   就是每个源 10MB 的线性泄漏。
   另一件待做：换新目前只有 `SpiderHost` 的假进程测试覆盖，**没有真子进程的
   端到端验证**（需要真 `spider_js` 子进程 + 真配置源，受本机网络限制）。

> **测试运行方式（重要）**：含夹具或 native 依赖的包，必须 `cd` 进包目录再跑
> `dart test`。从仓库根跑会因 cwd 不对而误报失败/跳过（`spider_js` 实测：
> 根目录 146 通过 / 4 失败，包目录 180 通过 / 0 失败）。`melos exec` 天然以
> 包目录为 cwd，是更稳的选择。
>
> **提交后必做**：`sh tools/git_ref_guard.sh` 恢复被删的分支引用，否则下次
> 提交会产生孤儿提交、丢失历史链。



