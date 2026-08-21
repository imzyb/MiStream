# MiStream 开发进度

> 本文件只做一件事：对照 [ROADMAP.md](ROADMAP.md) 的**出口标准**报告真实状态。
> 每个勾都指向可复现的证据（测试文件/命令/提交）。未验证的一律不勾。
> 更新：2026-08-21

## 总览

| 里程碑 | 出口标准 | 状态 |
| --- | --- | --- |
| M0 工程奠基 | 4/4 | ✅ 完成 |
| M1 播放内核 | 0/7 | ⏸ 依赖真实播放矩阵 |
| M2 数据层 | 0/5 | ⏸ 缺迁移/备份验证 |
| M3 RPC + Spider 骨架 | 5/6 | 🟢 仅剩真实 type=1 源 |
| M4 JS 运行时 | 4/6 | 🟢 仅剩真实源 + P50 基准 |
| M5 主线 UI 闭环 | 4/7 | 🟢 仅剩真实配置/续播/长跑 |
| M6 嗅探与解析 | 0/5 | 🟡 引擎已建，缺真实 type=0 源 |
| M7 直播 | 0/4 | 🟡 包已建，缺验收 |
| M8 下载与离线 | 0/5 | 🟡 包已建，缺验收 |
| M9 插件系统与主题 | 0/6 | 🟡 包已建，缺验收 |
| M10 发布工程 | 0/6 | 🔴 未启动 |
| M11-M15 | — | 🔴 未启动 |

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

- [x] 兼容性测试集 ≥100 条全绿 → `runtimes/spider_js/test/compat_runner_test.dart`（断言用例数并全跑）
- [x] 死循环 interrupt 且不影响同进程其它源 → `resource_limits_test.dart`
- [x] OOM 限制在 Context 级，进程存活 → `resource_limits_test.dart`（内存超限/栈溢出用例）
- [x] 脚本异常带堆栈 SCRIPT_RUNTIME_ERROR → `resource_limits_test.dart` + `runtime_child_test.dart`
- [ ] 5 个真实 drpy 源全流程 — **阻塞**：同上网络问题
- [ ] search P50 < 3s — type=3 e2e 已跑通（`type3_mock_integration_test.dart`），缺 P50 基准断言

本会话关键修复：无 import 的 type=3 源此前全部加载失败（`export` 语法错误），已修并重建 Release 包。

## M5 · 主线 UI 闭环 🟢

- [ ] 真实配置从零起播 — **阻塞**：等真实配置源
- [x] 聚合搜索源隔离 → `search_engine/test/search_use_case_test.dart`（超时/崩溃不阻塞）
- [x] 可读错误码 → `features/player/widgets/player_states.dart`（含嗅探 4 类错误码文案）
- [ ] 关闭重开续播 — 实现已落地（`router.dart` `_PlayerPageWrapper` 读历史 seek + 每 5s/dispose 落库），待端到端验收
- [x] 四态齐全 → `features/common/widgets/state_views.dart`
- [ ] 无 P0 崩溃 / 源崩溃不影响主进程 — 进程隔离已就位（type=3 走子进程、嗅探走 isolate），缺长跑
- [x] 集成测试（mock 源）端到端 → `runtimes/spider_js/test/type3_mock_integration_test.dart`（init→home→detail→play 全链路）

## M6/M7/M8/M9 · 包已建，验收未做 🟡

四个包已入工作区并全绿测试，但各自出口标准需要真实网络/真实源/长跑才能勾选：

- **M6** `packages/media_sniffer`（33 测试）：规则引擎、直链验证、HLS 样本测试齐；缺真实 type=0 网页源、WebView2 原生集成
- **M7** `packages/live`（17 测试）：m3u/txt 解析、drift 收藏、XMLTV EPG；缺换台/重试/长跑验收
- **M8** `packages/download`（22 测试）：任务状态机、Range 断点续传、HLS 分片；缺真实网络断点/离线播放验收
- **M9** `packages/plugin_host`（15 测试）：清单/权限/sha256/isocate 沙箱；缺逃逸测试、生命周期状态机全覆盖、主题引擎

> 注：`DownloadManager.startDownload()` 目前是 `Future.delayed(1s)` 假实现；`runtimes/sniffer` 只有 18 行占位。这两处是 M8/M6 出口标准的硬缺口。

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

## 下一步（按优先级，2026-08-21 审计）

1. **P1 门禁** `melos run analyze --fatal-infos` 仍红（727 info，`public_member_api_docs`为主），需机械清债或短期忽略该 rule
2. **P2 稳定性** 抽 `codec` 公共编解码、拆 `JarLoader` 三职责、`isPlatform` 补 `kotlin/`、下载重试+进度
3. **P3 体验** 首页并发预取与缓存、P50 基准断言、续播/长跑验收
4. **P4 债务** `libs/*.jar` 改 `tools/jvm_dist` 按需拉取、契约/迁移/长跑测试、全局装配去 `globalHomeAssembly`
