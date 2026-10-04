# MiStream 开发进度

> 本文件只做一件事：对照 [ROADMAP.md](ROADMAP.md) 的**出口标准**报告真实状态。
> 每个勾都指向可复现的证据（测试文件/命令/提交）。未验证的一律不勾。
> 更新：2026-10-01

## 总览

| 里程碑 | 出口标准 | 状态 |
| --- | --- | --- |
| M0 工程奠基 | 4/4 | ✅ 完成 |
| M1 播放内核 | 0/7 | ⏸ 依赖真实播放矩阵 |
| M2 数据层 | 4/5 | 🟢 迁移/备份/导入导出均已自动化验证；冷启动 50ms 阈值待基准机确认 |
| M3 RPC + Spider 骨架 | 5/6 | 🟢 仅剩真实 type=1 源 |
| M4 JS 运行时 | 5/6 | 🟢 仅剩真实源 |
| M5 主线 UI 闭环 | 6/7 | 🟢 仅剩真实配置源 |
| M6 嗅探与解析 | 1/5 | 🟡 CDP 嗅探运行时已落地，缺真实 type=0 源 |
| M7 直播 | 3/4 | 🟡 配置→频道列表、多线路重试、50 次长跑均已验；缺真实网络（换台 P50） |
| M8 下载与离线 | 1/5 | 🟡 持久化/恢复/续传已接入并有证据，其余卡真实网络与播放器 |
| M9 插件系统与主题 | 6/6 | 🟢 出口标准全勾；交付物仍缺主题包安装链路/插件中心 UI |
| M10 发布工程 | 0/6 | 🟡 发布链草稿已就位 |
| M11-M15 | — | 🔴 未启动 |

> **口径说明**：上表的「出口标准 0 勾」不等于「代码未实现」。M1/M2 的实现
> 与测试早已齐备（player_engine 142 用例、storage 54 用例），其出口标准
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
      **2026-10-02 更正：上面这个判断是错的，`csp_` 那条路本来就该能走。**
      用户实测截图报「所有站点均无法连接（共尝试 106 个：城市影视:
      spider jar 不存在: ./spider.jar）」——不是缺可播源，是**这批 `csp_`
      站点全被一个相对路径 bug 挡住了**：配置根级 `spider` 写成
      `"./spider.jar;md5;…"`，而 `SiteRepository.configSourceSpider` 原样返回，
      下游 `JvmRuntimeFactory._ensureJar` 见它不是 http(s) 就当**本地文件路径**
      去找。已修（见文末「本次会话（2026-10-02）· 二」）。修后该配置
      105 个站点全部解析出可下载的绝对 URL，链路证据 14/14。
      仍未勾「从零起播」的唯一原因变成了**本机起不了 java 子进程**
      （命名管道缺陷），需在用户机器上实测。
- [x] 聚合搜索源隔离 → `search_engine/test/search_use_case_test.dart`（超时/崩溃不阻塞）
- [x] 可读错误码 → `features/player/widgets/player_states.dart`（含嗅探 4 类错误码文案）
- [x] 关闭重开续播 → `apps/mistream/test/application/resume_policy_test.dart`（15 用例，覆盖不足 5s / 距片尾 30s 两条边界的含等于与不含等于、时长为零、无历史）+ `apps/mistream/test/features/player/player_resume_e2e_test.dart`（5 用例，驱动真实播放页验证 seek 到历史位置、三条不续播边界、进度写回历史）
      实现：`application/resume_policy.dart`（纯决策，可在 dart test 下跑）+ `router.dart` 播放页注入装配与引擎
- [x] 四态齐全 → `features/common/widgets/state_views.dart`
- [x] 无 P0 崩溃 / 源崩溃不影响主进程 — 进程隔离已就位（type=3 走子进程、嗅探走 isolate）。
      **2026-09-28 工装落地，2026-09-29 00:21 完成 2 小时真机长跑** ——
      `packages/spider_host/test/host_soak_test.dart` 用**真子进程**反复 SIGKILL，
      断言「每轮崩溃恰好换一个新进程、被换掉的老进程真的退出、主进程存活、宿主 RSS
      不无界增长」，并覆盖「持续崩溃 → 退避重启 → 熔断 → `reset` 恢复」与
      「启动阶段抛异常也退避重试」。规模可放大：`MISTREAM_SOAK_CYCLES=N` 定轮数、
      `MISTREAM_SOAK_SECONDS=N` 定时长（2 小时 =
      `MISTREAM_SOAK_SECONDS=7200 dart run test/host_soak_test.dart`，须 `cd` 进包目录）。
      **实测（2026-09-28 启动 → 09-29 00:21 结束）**：**11155 轮 / 7200s 全绿**，
      `EXIT=0`，全程零报错，主进程始终存活。宿主 RSS 基线 275.5MB → 结束
      **43.1MB**（增长 **−232.4MB**；阶梯下降：3000 轮 286.4MB → 3500 轮 186.2MB
      → 5000 轮 159.4MB → 7000 轮 45.5MB → 11155 轮 43.1MB）。**RSS 单调不增 =
      无泄漏**。
      第一版跑到第 8660 轮曾判红，**根因是环境不是宿主**（I: 盘的
      `.dart_tool/package_config.json` 被系统拒绝访问，子进程起不来），已修
      `start()` catch 分支不自愈的缺口、并把桩搬出 I: 盘，详见下方三续。
- [x] 集成测试（mock 源）端到端 → `runtimes/spider_js/test/type3_mock_integration_test.dart`（init→home→detail→play 全链路）+ `apps/mistream/test/m5_mock_e2e_test.dart`（配置导入→落库→搜索→详情→播放地址）

## M6/M7/M8/M9 · 包已建，验收未做 🟡

四个包已入工作区并全绿测试，但各自出口标准需要真实网络/真实源/长跑才能勾选：

- **M6** `packages/media_sniffer`（66 测试）：规则引擎、直链验证、HLS 样本测试齐；`runtimes/sniffer` **已落地 CDP 嗅探运行时**（70 测试，含真实 Edge/Chrome 端到端启动验证）；缺真实 type=0 网页源验收
- **M7** `packages/live`（**206 测试**，2026-10-01 由 17 → 89 → 144 → 206）+
  app 层 `live_import_e2e_test`（9 例）+ `live_source_fetcher_test`（4 例）+
  `live_sort_settings_test`（6 例）：
  m3u/txt 解析、drift 收藏、EPG（XMLTV + JSON 两条链路）、多线路换台、
  编码探测、频道排序、数字键跳台与方向键换台。
  **2026-09-30 修掉 8 处解析缺陷并打通「配置 → 频道列表」**：
  - `live_parser` 重写。用**真实源**（`live.zbds.top/tv/iptv4.txt` 前 11 行 +
    常见 m3u）写探针 12 例，**修前 8 例不符**，其中「m3u 标准写法（名字在
    `#EXTINF` 行末逗号之后）完全失效、只出 1/3 频道」是最严重的一处；其余为
    `分组,#genre#` 标记行被当成频道、`#` 多地址不拆、尾随 `#`/`,` 产生死地址、
    URL 里的 `&amp;` 被 `;` 拆成 4 段垃圾、`channelsByGroup` 丢未分组频道、
    `favoriteChannels` 命名与实现不符（实现是「groupId 为空」，与收藏无关，
    已改名 `ungroupedChannels`）。
  - `DriftLiveRepository` 两处持久化缺陷：`groupId` 是 NOT NULL 而旧实现遇到
    `groupId == null` 直接 `continue`，**未分组频道在「全部」里也一起消失**；
    `urls_json` 只写主地址，**备用线路在落库这一步就断掉**（列名本就是复数，
    设计意图是多地址）。改为 JSON 数组存储并兼容旧库的裸 URL 形态。
  - 新增 `LiveSubscription` / `resolveLiveUrl`（真实配置里 `lives[].url` 有
    `./list.txt` 这种相对路径）/ `LiveImporter`（多源串行、单源失败不中断、
    全军覆没不写库）/ `LiveChannelSwitcher`（多线路按序重试 + 当前线路）。
  - **接线**：`ConfigInstallService.install` 顺带导入 `lives`（此前
    `LiveConfig` 解析了但零消费方，「配置 → 频道列表」是断的）；`LivePage`
    改用 `AppScope` 里的 `DriftLiveRepository`（此前是 `InMemoryLiveRepository`，
    永远是空的）。
  - 反向验证 **38 项全部变红**（`.workbuddy-ai/scripts/rev_verify_live.py`，
    三个 runner：直播垫片 / `core_config` / `text_codec`）。
  - ⚠️ **`type` 字段不可靠**：文档说 `0 = M3U / 1 = TXT`，但实测真实配置
    `{"type": 0, "url": "./list.txt"}` 拉回来的是**纯 txt**。所以导入一律按
    内容嗅探（`#EXTINF` 判定），`type` 只做诊断。这条是拉真实配置验出来的，
    不是照文档写的。
  - ⚠️ **未覆盖**：UI 渲染（本环境 widget 测试不可用）；换台 P50（需真实网络
    与真实源）；播放器/引擎侧的泄漏（需真实起播放器）。
  - **2026-09-30 续：修补 5 处缺口**
    - **收藏跨重建保留**：整体重建频道表会让行主键全变，此前收藏必然丢失。
      改为按**频道名**恢复 —— 用户收藏的是「这个台」，源换了线路还是同一个台，
      按地址恢复等于每次换源都丢收藏。
    - **logo 模板接线**：真实配置里 `lives[].logo` 是含 `{name}` 的模板，
      不是能直接请求的图标地址；自带 `tvg-logo` 的频道不覆盖。
    - **EPG 从空壳变成真实实现**：此前 `XmltvParser.parse` 与
      `EpgFetcher.fetchFromSource` 都是注释 + `return {}` —— 本文件早先写的
      「XMLTV EPG 已有」**失实**，已改。现在 XMLTV 与 JSON 两条链路都通，
      且 `epg` 模板随配置导入落库（`live.epg_templates`），重启后自动恢复：
      配置原文不入库，不单独存一份的话重启后节目单永远是空的。
      播放页标题显示「正在播 <节目>」。
    - **GBK 编码的直播源**：码表抽到独立的 `packages/text_codec`（此前只在
      `runtimes/spider_js`，而拉取层不该为一份纯数据去依赖 QuickJS FFI）。
      拉取层按「响应头 charset > 内容嗅探」解码。顺带修掉生成器的两处
      不可复现问题（Windows 上写出 CRLF、首行缩进与仓库那份不一致）。
      ⚠️ 实测发现 **Dart 的 `utf8.decode` 自己就会剥 UTF-8 BOM**，所以显式
      剥 BOM 只对 GBK 路径有意义 —— 用例已按这个事实重写（原来的写法测的是
      Dart 而不是本项目代码）。
    - **50 次换台长跑**：原判据「需 app 层 widget 测试」**是错的** —— 泄漏点
      在 `LiveChannelSwitcher` 的引用持有上，纯逻辑即可验证。用
      `WeakReference` + GC 压力断言 50 次的频道与结果都不可达，并带一条对照例
      防「`WeakReference` 恒为 null、断言其实是空的」。
  - **2026-10-01：M7 交付物收尾**
    - **频道排序**：`LiveChannelSortOrder`（源顺序 / 名称自然序 / 收藏优先），
      稳定排序、不改动入参，偏好落库 `live.channel_sort`。刻意不做「按频道号」
      —— 那条链路上没有生产者，档位会永远退化成源顺序。
    - **数字键跳台与方向键换台**：定位（`LiveChannelNavigator` + 数字缓冲）、
      规则（`resolveLiveKey`，`LiveKey` 与 Flutter 解耦）、翻译（app 层对照表）
      三层切开，前两层是纯 Dart 因而有用例。↑/↓ 换台（环绕）、数字键超时或
      Enter 跳台、`Esc` 仅在缓冲非空时接管、组合键让位给播放器（音量退路）。
    - 详见本文件末尾「本次会话（2026-10-01）」。
  - ⚠️ **仍未做**：换台时保留上一路画面直到新流首帧（需双播放器 + 首帧回调）、
    低延迟缓冲策略 —— 两者都要真实播放器/真实流才能验证；换台 P50 需真实网络。
- **M8** `packages/download`（**126 测试**，2026-10-01 由 22 → 104 → 109 → 126）：
  任务状态机、Range 断点续传、HLS 分片解析/并发/合并，**外加 2026-10-01 补上的
  持久化与恢复**：
  - `download` / `download_segment` 两张表此前**建了却零使用**，任务只活在
    `DownloadManager` 的内存 `Map` 里 —— 「杀进程后重启状态恢复」与「断点续传」
    两条出口标准因此不可能成立。新增 `DownloadRepository`（抽象 + 内存实现）与
    `DriftDownloadRepository`，管理器每次状态变化都落库。
  - `DownloadTask.id` 由 `String` 改 `int`。旧 id 是「当前毫秒的十六进制」，
    **同毫秒内建多个任务会互相覆盖**（探针实测建 5 个只活下来 2 个，UI 上表现为
    「点了新建下载，列表里没出现」）。
  - 真实队列：并发上限（默认 3）、优先级降序出队、`pending` 状态真正被调度。
    旧实现是「谁先调 `startDownload` 谁先跑，且调用方要 `await` 到底」。
  - HLS 分片续传：按 `seq` 跳过已完成分片，且**校验分片文件还在盘上**（用户删过
    下载目录时只看记录会拼出中间缺一段的合并文件，不报错只是播到一半花屏）。
    分片写盘改为「先写 `.part` 再改名」，避免半截文件被当成完成品。
  - 合并改为 Dart 侧字节拼接（MPEG-TS / fMP4 分片首尾相接即合法）。原来生成的
    `ffmpeg -i "concat:a|b|c"` **是错的** —— concat 协议不认 `|` 分隔多文件。
    合并前少了分片**报错**（`StateError`）而不是静默跳过，并把半成品 `merged.*`
    删掉 —— 跳过会照样返回 `success`，用户拿到一个播到一半花屏的成品却毫无提示。
  - 保存路径从硬编码 `/downloads/<标题>`（Windows 上落到**当前盘根目录**）改为
    应用数据目录下的 `downloads/`，并给删除操作加了「不得越出下载根目录」的边界。
  - 删掉 `DownloadService`（~122 行、**零调用方**的假实现：`// Simulate download
    progress` + `Future.delayed`）。
  - **下载接进主流程**（2026-10-01 三）：详情页剧集卡片右键/长按 → 「下载本集」。
    此前下载只有**一个入口**（下载页手动粘贴 URL），于是 `download` 表的
    `site_id` / `vod_id` / `episode_name` 三列**没有任何写入方** —— 下载列表分不清
    「同一部剧的第几集」，「已加入下载」也无从判断。新增应用层 `DownloadUseCase`
    收拢四件必须按序发生的事：解析真实地址（`vod_play_url` 可能是网页播放页）、
    透传反盗链头（播放有 mpv 帮忙设，下载器没有）、按「影片 / 集」两级分目录
    （HLS 分片名固定，多集共目录会互相覆盖）、落库后立即发车。同一集连点两次
    只建一条且**不再解析地址**；`cancelled` 不算已存在。
  - ⚠️ **仍未做**：直链多线程分段下载、速度/剩余时间统计、离线播放（需播放器）、
    真实网络下的断点续传端到端验收。
- **M9** `packages/plugin_host`（**90 测试**，2026-09-28 由 19 → 30 → 56，09-30 → 68 → 90）+ **`packages/theme_engine`**（**98 测试**，新增独立包，提交 `b113410`）：清单/权限/sha256、**路径穿越 guard**（2026-09-30 修掉两类真漏洞，见三续之后的四续）、**权限撤销的运行时降级**（2026-09-30 补通知链路与调用侧闸门，此前 `revoke` 只改账本、与 `PluginManager` 脱钩）、**畸形主题包的兜底**（2026-09-30 三：修掉「透明度绕过对比度校验」与「尺度越界原样生效」两处真漏洞）、对比度计算、**版本目录 + 指针切换的原子升级与回滚**（新增 `PluginStore`，26 例）。**生命周期状态机已补测**（提交 `68a163d`：`PluginState.error` 此前从未被赋值、属死状态，已让激活失败可进入 error 并补全迁移真值表）。仍缺**主题包的安装/启用链路**（从插件目录加载，现在只有解析与校验）
  - **记录更正（2026-09-30）**：此处原先写「isolate 沙箱」，**失实**。`PluginSandbox`
    从未 spawn 过 isolate（`_isolates` 表只在 `terminate` 里被读、从没写入，
    `isRunning` 因此恒为 false），已如实化为「并发闸门与登记表」并修掉计数 bug。
    真正的隔离在 `spider_host` 子进程（进程级）与嗅探 isolate，不在这个类。


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

## 本次会话（2026-09-25 四续）：换新窗口内的重复建宿主（自己引入的回归）

上一轮加了「宿主按源数量整进程换新」，但换新是**先关停、后退避重启**，
这段窗口内 `isReady` 是 false——而 `SpiderRuntimeFactory._getJsHost` 的判据
恰恰是 `if (_jsHost != null && _jsHost!.isReady) return _jsHost!;`。

后果：窗口内来一个 `spider.create` 就**新建第二个 `SpiderHost`**，旧的还在后台
重启。两个子进程、两套实例，互不知情；多出来的那个宿主没人驱动握手，随后以
`JS 运行时启动失败: 管道已关闭` 炸掉。JVM 路径同构。

**修法**

1. `SpiderHost.waitReady()`（新增）：已就绪立即返回 true；熔断 / 已释放 / 超时
   （默认 20s）返回 false。唤醒点是 `start()` 成功、熔断、`dispose()`，以及
   `start()` 抛异常（这条路径不会挂重启定时器、不会自愈，不能让调用方空等）。
2. `SpiderRuntimeFactory._reuseOrDiscard()`：未就绪且未熔断就**等同一个宿主**；
   熔断或超时才 `dispose()` 掉重建。`dispose()` 会取消挂着的重启定时器，所以
   「弃掉」不会留下孤儿进程。
3. `_getJsHost` / `_getJvmHost` 启动失败时摘掉并 dispose 宿主，不再留一个起不来
   的实例让下一个调用去撞它的超时。
4. 新增 `SpiderRuntimeFactory.jsLauncher` 注入点——JS 路径原先只有 `jvmLauncher`，
   `spider.create` 参数拼装、换新窗口行为**完全没法测**。现在能用假进程覆盖。
   代价是三个 `implements SpiderRuntimeFactory` 的测试假工厂要补一个 getter。

**证据**

| 验证 | 结果 |
| --- | --- |
| `packages/spider_host` 全部 15 个测试文件 | 除 `http_runtime_test` 的 6 例回环用例（`os error 10061`）外全绿 |
| `test/js_runtime_factory_test.dart`（新增，2 例） | 全绿。**把 `_reuseOrDiscard` 临时退回旧语义 → 用例在「窗口内不能新建宿主」这条断言上变红（进程数 1 → 2）**，改回即绿 |
| `test/spider_host_test.dart` | 14/14（新增 5 条 `waitReady` 用例：已就绪 / 换新窗口等待 / 熔断唤醒 / 超时 / dispose 唤醒） |
| 静态检查 | **293 文件 0 error / 0 warning / 0 info** |
| 提交 | `ac86873`，已推送，远端引用复核一致 |

## 本次会话（2026-09-25 五续）：修正两个错误环境结论 + http_runtime_test 全绿

**一、http_runtime_test 6 例失败 → 不是「沙箱禁回环」，是空路径 URL 被代理截走**

`HttpRuntime.call` 构造 `{baseUrl}?ac=...` 时，若 `baseUrl` 以 host 结尾
（如 `http://127.0.0.1:8080`），生成的 URI **路径为空** →
`http://127.0.0.1:8080?ac=videolist`。sandbox 透明代理**只截空路径的 URL**，
带 `/` 的（`/?ac=...`）和带路径的（`/x`）都直达本地服务器。代理截走后返回
502 + "upstream connect failed: 10061"——此前被误判为「沙箱禁回环」。

修：`Uri.replace` 时把空路径规范化成 `'/'`（RFC 7230 要求 origin-form 请求
目标至少为 `/`）。提交 `09dadb0`。

验证：`spider_host` **15 个测试文件全部 All tests passed**（`http_runtime_test`
6/6，其中 1 例网络错误测试在代理环境下合理 skip）。

**二、命名管道「耗尽」→ 不是数量问题，是 Dart VM 的 `Process.start` 实现特殊**

- 本机只有 423 个命名管道（Windows 支持数万），**不是数量耗尽**。
- Python `subprocess`（`CreatePipe` 同步匿名管道）**完全正常**；Dart FFI
  经 `CreateNamedPipeW` + `CreateFileW`（含 `FILE_FLAG_OVERLAPPED`）**也完全正常**。
- 只有 Dart VM 的 `process_win.cc` 失败；Node/libuv 同样失败（`EBUSY`）。
- **回环 TCP 可用**（`Socket.connect` 成功收发），可用「`inheritStdio` 起真子进程
  + 子进程回连 TCP」替代 stdio 管道。

**三、仍待做（更新）**

- ~~真子进程端到端验证~~ → **已打通**（见下「六续」）。
- `dart analyze` / `dart test` / `flutter test`：仍被 Dart VM 管道缺陷挡住。

## 本次会话（2026-09-25 六续）：真子进程端到端打通 + 修掉一个只有真进程能暴露的 bug

**一、真子进程端到端：TCP 回连 launcher**

本机 `Process.start` 建不了 stdio 管道，但 `inheritStdio`（不建管道）与回环
TCP 都可用，于是把传输层换成 TCP：

- `test/support/tcp_process_launcher.dart`：宿主先 `ServerSocket.bind(
  loopbackIPv4, 0)`，把端口作为 `--port=<n>` 追加到子进程参数，用
  `Process.start(mode: inheritStdio)` 起真进程，子进程主动回连。
  `SpiderHost.launcher` 本就可注入，**生产代码零改动**。
- `test/support/rpc_child.dart`：子进程桩（只用 dart:io/convert），说 LSP 分帧
  JSON-RPC，响应 handshake/ping/create/destroy，收到 `runtime.shutdown` 就退出。
- `test/real_process_host_test.dart`：4 例（握手 / 调用 / 换新 / 窗口复用）。

**二、bug：`_onProcessExit` 被调两次 → 换新后多起一个进程**

换新是「先主动关进程（`_recycleProcess` 调 `_onProcessExit`）、老进程随后真正
退出（`exitCode` 回调再调一次）」两步。假进程测试里两次几乎同时发生，被
`_restartTimer != null` 挡住；**真进程退出有延迟，第二次落在第一次重启之后，
于是又拉起一个进程**。

修：加 `_exitHandled` 幂等标记，`start()` 起新进程时重置。崩溃重启不受影响。
回归用例：「换新窗口内再调用」断言全程只有 2 个真进程（修前 3 个）。

**三、语义澄清**

`SpiderHost.call()` 在未就绪时**不排队**，直接回 `runtimeNotReady`；想复用
同一个宿主必须先 `waitReady()`。测试用例按此语义写。

**证据**

| 验证 | 结果 |
| --- | --- |
| `packages/spider_host` 全部 **16** 个测试文件 | 全部 All tests passed（新增 `real_process_host_test` 4 例） |
| 静态检查 | **297 文件 0 error / 0 warning / 0 info** |
| 提交 | `b05663e`，已推送，远端引用复核一致 |

## 本次会话（2026-09-26）：M9 主题引擎落地并接线到 UI

用户指令「先做UI/UX」。UI/UX 批次 1–5 早在 2026-08-18 做完，本次挑的是
**M9 出口标准里唯一能在当前环境完整自动验证**的那条，以及接线路上暴露的真
缺陷。

**一、令牌集补齐（对比度条目）**

诊断发现两个问题：① 现有对比度测试只覆盖 3 对前景/背景，而出口标准要求
「每对组合」；② 唯一接近边界的 `outline` 在四套主题上都是 1.18~1.72，远低于
WCAG 1.4.11 要求的 3:1。

处理：拆成两个职责单一的令牌——`outline`（装饰性分隔，注释里明确写出不受
1.4.11 约束）、`outlineStrong`（输入框/按钮轮廓/选中态描边，须达 3:1）。同时
按 `docs/09-UI规范.md` §2.1 把令牌集从 7 个补到 **10 个**，补上规范明确要求的
`onPrimary` / `primaryText` / `surfaceVariant` / `onSurfaceMuted`。

规范 §31 的「主色拆两个令牌」是关键：单一中亮度主色无法同时满足「白字压在它
上面」和「它压在深色背景上」，强行用一个值必然有一边不达标。深色主题里这个
窗口只剩 0.165~0.183 的亮度区间（几乎无解），改用 M3 深色主题的常规做法
**亮填充 + 深墨**（indigo-400 配 slate-900 墨），两个约束都宽松到 5.98 / 4.90。

断言矩阵集中到 `contrastRules()` 一处，内置主题测试与主题包校验共用——规范
§257 要求主题包跑的是「与内置主题同一套断言」，各写一份必然在某次加令牌后
悄悄分叉。

**二、主题包加载（规范 §9 健壮性）**

`ThemePackage.fromJson` → `applyTo` → `checkContrast` → 不达标回退。
未知 `color.*` 键告警、非颜色键静默忽略、非法值告警、形状不对只告警不抛；
不达标时回退内置主题并**说出具体是哪个令牌对**（用户要改主题包得先知道改哪）。

**三、接线 + 修掉「切换主题要重启」（规范 §9 明文禁止）**

原实现 `themeMode` 是 `main.dart` 一次性传给 `MiStreamApp` 的构造参数，设置页
改主题只写库 + 自己的 `setState` → **必须重启才生效**，直接违反规范第 239 条。
同时 `theme_engine` 这个包建了但**根本没接线**，四套主题（含 OLED）是死代码。

处理：
- `ThemeController extends ValueNotifier<AppThemeChoice>` + `ThemeScope`
  （`InheritedNotifier`），`main.dart` 读库建控制器，树根 `ValueListenableBuilder`
  监听 → 切换即时生效
- 新增 `AppThemeChoice`（system/light/dark/oled）与 `resolveTheme`，纯 Dart
  可测；**枚举前三位顺序即旧 `ThemeMode.index`，是兼容性契约，OLED 只能追加**
- 新增 OLED 纯黑主题选项（规范 §237 要求内置，此前不可达）
- 默认外观改为**深色**（规范 §237「深色（默认）」，原实现默认 system）
- 设置项标题「主题模式」→「外观」，四项各带说明副标题；对话框不再选完即关，
  用户可连点几下对比
- `ColorScheme` 映射：`outline` 槽位放 `outlineStrong`（M3 拿它画输入框与按钮
  轮廓，属于「识别组件所必需的视觉信息」），装饰性淡线退到 `outlineVariant`；
  `primaryText` 没有对应槽位，挂在 `AppColors` ThemeExtension 上

**四、顺带修掉 `main.dart` 的 9 个损坏字符**

`git log` 定位到损坏由 `131b2a4`（应用壳提交）引入，`ef bf bd`（U+FFFD）替换
掉了 桌/析/装 等字。注释已按 `1c7f1c2c` 的原文补回。
（另：`runtimes/spider_js/lib/src/drpy/gbk_table.dart` 里 2149 个 U+FFFD 是
**生成表里有意为之**的未映射码位占位，不是损坏，不要「修」。）

**证据**

| 验证 | 结果 |
| --- | --- |
| `packages/theme_engine` 3 个测试文件 | 全部 All tests passed（**29 例**，新增 21 例） |
| 反向验证 | 把 dark 的 outlineStrong 退回 0xFF334155 → 断言如期变红 |
| 静态检查（进程内分析器） | **302 文件 0 error / 0 warning / 0 info** |
| `dart format --set-exit-if-changed` | 0 changed |
| `flutter build windows` | **不可用**：flutter 工具自身撞管道缺陷（`git.exe`/`where.exe` 起不来），且本机未装 Visual Studio |

**仍未做（M9 剩余）**

- `mistream theme lint` 工具未实现（规范 §257 提到，主题作者本地自查用）
- 令牌集只覆盖颜色：`spacing` / `radius` / `elevation` / `font` 与
  `color.success/warning/error/overlay` 尚未建模
- 主题包的**安装/启用**链路未接（当前只有解析与校验，没有从插件目录加载）
- 生命周期状态机测试全覆盖、沙箱逃逸测试：仍缺
- app 侧 `buildThemeData` 的令牌→角色映射**无法自动验证**（widget 测试不可用），
  仅由分析器保证类型正确

## 本次会话（2026-09-26 续）：尺度与字体令牌落地

接着上一节，把规范 §2.2 / §2.3 从「只有一张表」变成有实现、有校验、能被主题包
覆盖的令牌。

**一、`theme_engine` 新增 `scale.dart`**

- `DesignScale`：`spacing.unit`(4)、`radius.sm/md/lg/full`(4/8/16/9999)、
  `elevation.card/dialog/overlay`(1/8/16)，附 `spacing(steps)` 换算
- `DesignTypography`：字号阶梯 display 28/600 → caption 12/400、字体族回退链、
  `font.scale`
- `validateScale` / `validateTypography` / `validateTheme`：圆角与投影必须单调
  递增、字号阶梯必须逐级递减、字重须是 100~900 的百位整数
- `font.scale` 按规范 §231 夹进 0.8×–1.5×（`effectiveScale`），越界告警但不
  算致命

**二、主题包能覆盖它们**

`spacing.unit` / `radius.*` / `elevation.*` / `font.family` / `font.scale` 全部
可覆盖，数值接受数字或字符串。另外认了 **`radius.card`** —— 这个名字只出现在
`06-插件系统.md` §9 的示例里，规范 §2.2 并没有它，但示例是主题作者最先照抄的
东西，映射到 `radius.md`。

**尺度/字体的问题不触发回退**，只告警后按**包里写的值**用。理由：圆角顺序反了
不会让界面不可读，而整包回退会把用户真正想改的那个圆角也丢掉——用户明明只想改
一个圆角，却被告知「主题包不可用」，那是更差的结果。

（原文此处写的是「按基准值用」，那是错的：`loadThemePackage` 回的是 `merged`，
包里那个不合规的 40 也是照用的。2026-09-26 的续作里把运行时的告警文案与 lint
的提示都改成了「仍按包里的值使用」。）

**三、接进 app**

- `AppColors` 扩成 `AppTokens`（颜色 + 尺度 + 字体），`AppScale`/`AppType`
  合并进来，少一层扩展
- `ThemeData` 的 `fontFamilyFallback` 按规范回退链填上——Flutter 默认字体在
  Windows 上不含中文字形
- 字号阶梯落到 M3 槽位：display→`headlineMedium`、title→`titleLarge`、
  subtitle→`titleMedium`、body→`bodyMedium`、caption→`bodySmall`
- 卡片圆角改用 `radius.md`（8，此前硬编码 12）、对话框用 `radius.lg`；
  关掉 M3 的高度着色，它在卡片底色上再叠一层主色，会改掉断言过的对比度
- `font.scale` 通过 `MaterialApp.builder` 叠在系统字号缩放之上。**内置主题
  都是 1.0，此时不碰 MediaQuery** —— 系统字号缩放是用户设的无障碍选项，
  没理由为一次恒等变换把它替换掉

**证据**

| 验证 | 结果 |
| --- | --- |
| `packages/theme_engine` 4 个测试文件 | 全部 All tests passed（**54 例**，本轮新增 25 例） |
| 静态检查（进程内分析器） | **304 文件 0 error / 0 warning / 0 info** |
| `dart format --set-exit-if-changed` | 0 changed |

**偏差（已知且写进规范了）**

- 字体**没有**校验是否真的存在——Flutter 不提供字体枚举，做不了。现在的做法
  是优先级回退链，缺字时由系统挑下一个

## 本次会话（2026-09-27）：动效令牌落地 + `theme lint` 工具 + 门禁根因

**一、`mistream theme lint` 真的有了**

`docs/06-插件系统.md` §9 早就承诺「主题作者可用 `mistream theme lint` 在本地提前
发现」，但此前只有运行时校验——作者得先把包装进客户端才知道哪一对令牌不达标。
新增 `tools/theme_lint`（薄 CLI + 可测 lib + 17 例测试，后扩到 23 例）：

- 校验分三级：清单结构 / WCAG 对比度 / 自洽与完整性
- 退出码 **0 通过 / 1 有 error / 64 用法错 / 66 文件不存在**，方便脚本与 CI 调用
- `--ratios` 打出 16 对实测比值，作者能看到「刚过线」的余量
- **关键不变式**：lint 的结论必须与运行时一致，否则会出现「本地过了、装进客户端
  被回退」这种最难查的情况。测试拿同一份 JSON 同时跑 `ThemeLinter.lint` 与
  `loadThemePackage`，断言 `hasError == fellBack`

**二、`arch_check` 的根因缺陷（门禁误报）**

`arch_check` 的 `_dartFiles` 递归扫全仓库，把 `.workbuddy-ai/` 下的一次性探针
脚本当项目源码要求——2026-09-25 的两个探针（没写 `// ignore:` 理由）已经实际把
M0 门禁顶红过一次，而那与产品代码的健康度无关。把 `.workbuddy-ai` 加进
`_isSkippedDirectory`，并补 5 条回归用例钉住「扫描范围」这个行为契约（含一条
控制组，防止「整棵树都没扫到」造成的假绿）。反向验证：摘掉该条件后 3 条用例
如期变红。

顺带确认 `schema_versions.dart` 是**目录**不是文件（drift 生成的 `schema.dart`
落在它下面），跳过列表的语义是自洽的。

**三、动效令牌（规范 §2.4）**

- `theme_engine` 新增 `motion.dart`：`MotionCurve`（**只收规范列出的四条**，
  没有 `linear`）、`MotionSpec`（时长 + 曲线）、`DesignMotion`（四档场景 +
  `reduceMotion`）、`validateMotion`
- 曲线只存**名字**，到 app 层才由 `curveOf` 映射成 Flutter 的 `Curve`——
  `theme_engine` 一旦引 Flutter 就只能跑 `flutter test`，而本环境
  `flutter_tester` 起不来，等于把唯一能自动验证 UI 面的地方关掉
- 主题包可覆盖 `motion.<场景>` 与 `motion.<场景>.curve`；**`motion.reduceMotion`
  会被当未知键拒掉**——那是无障碍选项，不是审美选项，主题包说了不算
- `validateMotion`：负值、超过 1000ms 上限、未开减少动效却是 0ms 都告警
  （不拒绝，与尺度/字体一致）
- 时长解析有上限保护：`(1e30 * 1000).round()` 会抛 `UnsupportedError`，而输入
  来自主题包这种用户数据。畸形包必须不崩

**四、接进 app**

- `AppTokens` 加 `motion`；新增 `MotionController` / `MotionScope`（与
  `ThemeController` 同构）与 `reduce_motion` 持久化键
- `app.dart` 的 `_applyFontScale` 重构成 `_applyAppearance`：**只组一次
  `MediaQuery`**。字号缩放与减少动效各写一个的话，后套上的那个会以外层 data 为
  底，把前一个塞进去的字段冲掉
- 减少动效走 `MediaQuery.disableAnimations`：这是 Flutter **自己的**无障碍通道，
  `AnimationController` 看到它会直接跳到终态，连没主动接线的框架动画（页面切换、
  SnackBar）也一并归零。令牌侧的 `effectiveXxx` 是给显式取时长的组件用的
- 设置页加「减少动效」开关
- 替换手写的硬编码动效：`player_page`（180ms/easeInOut，正好是规范值）与
  `media_card`（写的是 180ms，**规范要 120ms** —— 正是令牌要解决的漂移）。
  `poster_image` 的封面解码淡入 250ms 保留字面量：上表四档都不覆盖它，硬塞进
  某一档只会让那张表失去意义

**五、改掉三处说反的文案**

`validateTheme` 的问题只告警不回退，但**包里写的值照原样生效**（`loadThemePackage`
返回的是 `merged`）。运行时的告警、lint 的提示、README 里的「按基准值使用」
三处都说成了「会按默认值用」，全部改正。

**证据**

| 验证 | 结果 |
| --- | --- |
| `packages/theme_engine` 5 个测试文件 | 全部 All tests passed（**86 例**，本轮新增 32 例） |
| `tools/theme_lint` | All tests passed（**23 例**） |
| `tools/arch_check` | All tests passed（**20 例**，本轮新增 5 例） |
| 静态检查（进程内分析器） | **310 文件 0 error / 0 warning / 0 info** |
| `dart format --set-exit-if-changed` | 0 changed |
| `arch_check` 真实门禁 | 分层纪律检查通过 |

**仍未做**

- 页面切换那一档只暴露了令牌，没接管框架过渡（会丢掉平台原生过渡，代价大于
  收益；减少动效已由 `disableAnimations` 兜住）
- 主题包的**安装/启用链路**未接：只有解析与校验，没有从插件目录加载

## 本次会话（2026-09-27 续）：主链路审查 + 播放段边界修复

按「添加接口源 → 选择播放源 → 选择/搜索影片 → 播放影片」走了一遍端到端代码
审查（只读），完整报告见 **`docs/CODE_AUDIT_2026-09-27.md`**。四段的降级链都是
真实现，不是注释里的愿景；问题集中在**资源回收 / 环境探测 / 同一件事实现两遍**。

### 已修（10 项，均已反向验证或补了单测）

| 缺陷 | 位置 | 验证 |
| --- | --- | --- |
| **P0** `PlayUseCase` 创建的 runtime 从不回收，每播一集泄漏一个 JS/JVM 子进程 | `packages/search_engine/lib/src/play_use_case.dart` | 摘掉回收 → 新增 5 例中 **4 例变红** |
| **P1** `_resolveJavaPath` 只查 `JAVA_HOME`（注释却承诺 PATH 回退），导致 `csp_` 站点在未设该变量的机器上被整体判成「无运行时」 | `apps/mistream/lib/application/app_assembly.dart` | 摘掉回退 → 新增 8 例中 **3 例变红** |
| **P2** `parseDetail` 文档注释写「剧集以 `##` 分隔」，实现是 `#`（代码对、注释错） | `apps/mistream/lib/application/detail_use_case.dart` | 纯文档 |
| **P2** 搜索层无法选片源（`_goDetail` 只取 `sources.first`） | `apps/mistream/lib/features/detail/detail_page.dart` | 详情页新增「片源」切换 |
| **P3** 引导页导入失败提示在重试**之前**就显示（闪一下 + 多发一次请求），图片类内容还会被无意义地重试 | `apps/mistream/lib/features/onboarding/onboarding_page.dart` | 改为最后一次尝试才报错 |
| **P3** 引导页自建一套弱于 `ConfigDecoder.probeNonJson` 的 HTML 判定；Base64 导入丢 `sourceUrl`（相对路径脚本解析失败） | 同上 + `packages/core_config/test/config_decoder_test.dart` | 改用 `probeNonJson`，并补 **6 例直接单测**（此前只有间接覆盖） |
| **P2** 剧集序号在**生成端**与**消费端**各写一份且互不一致（详情端用「非空剧集计数」、播放端用 `split('#')` 下标），源里出现空段（`第1集$u1##第4集$u4`）就整体错位 | `apps/mistream/lib/application/detail_use_case.dart` + `packages/search_engine/lib/src/play_use_case.dart` | 摘掉真实下标 → 详情用例**变红** |
| **P2** 剧集越界**静默回退第 1 集**：多线路集数不等是常态，用户点第 5 集可能从另一条线路播出第 1 集，且进度记到错位置 | 同上 | 摘掉「跳过该线路」→ **2 例变红** |
| **P2** 历史/收藏的「继续播放」push 了 `detail` 而 extra 用的是播放路由的键名 → extra 被整个丢弃，实际只是打开详情页；`history.flag`（线路名）被当集号传；`episodeIndex` 从未落库 | `apps/mistream/lib/features/library/library_page.dart` + `apps/mistream/lib/app/router.dart` | 入口改走 `player` 并传 `episodeIndex`；UI 层无自动化测试，人工核对控制流 |
| **P3** 搜索结果网格全量重建：`_items..clear()..addAll()` 每次事件整列重建，卡片**无 key**，结果随源陆续返回而重排 → 同一格被当成「换了一部片」，封面重新加载淡入 | `packages/search_engine/lib/src/{models,search_use_case}.dart` + `apps/mistream/lib/features/common/widgets/responsive.dart` + `features/search/search_page.dart` | 身份键改回原始标题 / 去掉 sources 排序 → **各 1 例变红**；UI 层无自动化测试 |

P0 的修法是把「取详情 + 回收」收进 `_detailAndDispose`，成功 / 业务失败 / 抛异常
三条路径都 dispose，与 `DetailUseCase.load`、`HomeUseCase._trySites` 同一套纪律。
P1 的修法是把环境值显式收参（`resolveJavaPath({javaHome, pathValue})`）——进程内的
环境变量改不了，不收参则「PATH 回退」这条最关键的路径永远只能靠人工碰运气验证。
新增 `apps/mistream/test/application/app_assembly_test.dart`（13 例），已挂进
`run_tests_shim.dart`。

播放段边界的修法是把「第几集」收成一个值对象 `EpisodeIndex`（`core_domain`）：
生成端用 **`split('#')` 的真实下标**编码（此前用非空计数，跳过的空段会让后续序号
整体前移），消费端越界返回 `null` 而**不回退**——各线路集数不等是常态，回退会让
用户看错集却不自知，宁可明确报 `notFound`。`PlayResult` 顺带回填实际集号，播放页
据此落库 `episodeIndex`，并在续播前比对集号：历史按 `(siteId, vodId)` 唯一，切集后
那条记录里的进度属于**上一集**，拿来 seek 会让新一集从中间开始播。
新增 14 例值对象单测 + 7 例播放端用例 + 3 例详情端用例；垫片 **78 → 87**，
`core_domain` 独立跑 **14 例**。三处修复各做了一次反向验证，均按预期变红。

搜索结果网格的修法分两层：引擎侧给 `SearchItem` 补 `identityKey`（就是合并去重用的
`normalizeTitle` 键，因此天然唯一），UI 侧给卡片带 `ValueKey(identityKey)` 并让网格
支持 `findChildIndexCallback` —— **只加 key 不够**，sliver 得靠这个回调才能按 key
找到旧元素；两者齐备后重排只是「把卡片挪个位置」，不再整块重建。顺带发现
`SearchItem.sources` 的注释承诺「按源优先级排序」而实现只是 `append`，于是
`sources.first`（详情页与搜索页都用它决定「默认打开哪个源」）拿到的其实是**最先
命中**的源、由并发顺序决定；已改为在 `toSearchItem()` 里按优先级降序排。
新增 3 例引擎侧用例；垫片 **87 → 90**。

搜索层选源的实现顺带修掉一个隐性缺口：`DetailPage.item` 一直**声明了但从未使用**
（注释写着「用于即时展示标题/封面」），现在它成了片源列表的数据来源。切源用
`replaceNamed` 而非 `pushNamed`，并补 `didUpdateWidget` —— go_router 对同一路由模板
复用同一个 page key，不补的话换源后页面会停在上一部片上。

### 仍未修（进下一步清单，见下）

`_CategoryDetailPage` 用全局装配、选源口径不一致。

## 本次会话（2026-09-28）：插件生命周期状态机补全

接着上一节收尾「M9 剩余」。开工前先核账，发现两处记录失真（都已更正）：

- **「M2 缺迁移/备份验证」不成立**：`storage/test/migration_test.dart`（5 例，
  v1→v3 / v2→v3）、`backup_manager_test.dart`（含「迁移失败抛异常且备份仍在，
  库文件未被半迁移污染」）、`backup_exporter_test.dart`（导出/导入 6 例）、
  `perf_test.dart` 早已齐备。总览表 M2 由 `0/5 ⏸ 缺迁移/备份验证` 更正为
  `4/5 🟢`（仅冷启动 50ms 需基准机确认，测试里是 500ms 护栏）
- **「plugin_host 19 测试」没被真正跑过**：垫片 `run_tests_shim.dart` 里
  **从来没有 plugin_host 的入口**，该包两个测试文件一直是静默漏跑。已补进垫片

### 缺陷：`PluginState.error` 是死状态（提交 `68a163d`）

`plugin_api.dart` 声明了 4 个状态与 3 个迁移闸门（`canEnable` / `canDisable` /
`canUninstall`），但全仓核对的结果是：

- `PluginState.error` **从未被赋值**。`install` / `enable` 都是
  `await api.onActivate()` 裸调用 —— 激活失败时异常直接抛给调用方，
  **管理器里不留任何痕迹**：用户既看不到这个插件，也无从卸载它
- `canUninstall` **定义了却无人调用**，且语义是错的（`this != error` 意味着
  故障插件永远卸不掉）。已删除 —— 卸载本就不该设闸门

修法：

- `install` 改为**先登记后激活**，激活失败时插件以 `error` 态留在管理器里并
  发出事件；异常仍照常抛出（调用方据此提示「已安装但启用失败」，重试走 `enable`）
- `enable` 同样在激活失败时转入 `error`；`canEnable` 接纳 `error` —— 那是
  「重试激活」，否则故障插件只剩卸载重装一条路
- `disable` 失败时**保持 `enabled`**：插件实际仍在运行，标成已停用或故障
  都不符合事实
- `disposeAll` 逐个容错：一个坏插件的 `onDispose` 不该阻断其余插件的清理，
  更不该让事件流关不掉；清理完再把第一个异常抛出去，不静默吞掉

### 顺带修掉一个假覆盖

`install duplicate throws` 用的是 `expect(() => manager.install(...), throwsA(...))`。
`install` 是 `async` 函数，异常进的是 Future 而不是同步抛出，**闭包形式断言
不到** —— 已改为 `await expectLater(...)`，并补上「重复安装失败不破坏已装好的
那个」的断言。

### 验证

| 项 | 结果 |
| --- | --- |
| 垫片用例 | 90 → **120**（plugin_host 19 → 30） |
| `analyze_inproc` | 313 文件 **0 error / 0 warning / 0 info** |
| `dart format` | 0 changed |
| `arch_check` | 分层纪律检查通过 |
| 反向验证 | 摘掉 `canEnable` 的 error 分支 → 2 例红；还原 `install` 登记顺序 → 3 例红；还原 `disposeAll` 朴素循环 → 1 例红 |

**当时仍未做**：ROADMAP M9 交付物「版本目录 + 指针切换的原子升级与回滚」。
（`PluginManager` 只有 install/enable/disable/uninstall/disposeAll。）该条已于
**本次会话（2026-09-28 三续）**落地，见下；「生命周期状态机测试全覆盖」的
状态机部分算覆盖了现有 4 态的全部迁移。

## 本次会话（2026-09-28 续）：M5 长跑工装

做 M5 出口标准最后一条「无 P0 崩溃；源崩溃 100% 不影响主进程」。已有测试各自差
一截：`spider_host_test.dart` 用**假进程**（状态机能验，验不到真进程生命周期），
`real_process_host_test.dart` 用真进程但只走正常路径。补的是中间的空白。

### 一、工装 `packages/spider_host/test/host_soak_test.dart`

用真子进程（`support/tcp_process_launcher.dart` 的 TCP 回连）反复 SIGKILL：

- 每轮崩溃**恰好**换一个新进程（多了 = 重复建宿主，少了 = 崩溃没被发现）
- 被换下的子进程真的退出了（每轮就地回收，不留孤儿）
- 主进程存活（测试能跑完本身就是证据）
- 宿主 RSS 不无界增长
- 持续崩溃 → 退避重启 → 熔断 → `call` 返回 `runtimeNotReady`（不抛不挂）
  → `reset` 恢复；`dispose` 后不留孤儿

规模用环境变量放大（默认 8 轮约 14 秒）：`MISTREAM_SOAK_CYCLES=N` 定轮数、
`MISTREAM_SOAK_SECONDS=N` 定时长。**2 小时长跑**：

```bash
cd packages/spider_host
MISTREAM_SOAK_SECONDS=7200 dart run test/host_soak_test.dart
```

新增桩 `test/support/rpc_child_crash.dart`：**回连成功后再崩**。必须是「连上再崩」
而不是「起不来」—— `SpiderHost.start()` 的 catch 分支不挂 `_scheduleRestart`
（源码注释写明「不会自愈」），起不来的桩驱动不了退避重启与熔断那条链。

### 二、踩到的两个坑（都已修，都写进 SKILL.md）

**① `package:test` 默认单测只给 30 秒。** 第一次跑 150 秒配置直接失败，报
`TimeoutException after 0:00:30`，**看起来像宿主挂了，实际是测试没放宽超时**。
8 轮的短跑约 14 秒刚好躲过默认值，所以这个坑要跑到几十轮才暴露。已按配置算超时
预算（`soakTimeout`，留 120s 余量）。

**② RSS 测量被测试自己污染。** 第一版把每个 `LaunchedChild` 都留在列表里，而
`ProcessInfo.currentRss` 量的是**本测试进程** —— 686 轮测出增长 48.4MB，且三点
采样近似线性，差点据此判定「宿主每轮泄漏约 70KB、2 小时会 OOM」。改成每轮就地
回收并摘掉引用后重测，增长曲线是**收敛**的：

| 轮数 | 100 | 150 | 200 | 250 | 300 | 350 | 400 | 450 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RSS | 273.4 | 280.3 | 281.1 | 281.7 | 281.7 | 281.5 | 281.9 | 282.5 |

前 150 轮爬升到 281MB 后平台化，之后 300 轮只动 2.2MB 且上下抖动（GC 锯齿）。
**结论：宿主没有按崩溃轮数泄漏。** 判据写进 SKILL.md —— 增长随轮数线性 = 真泄漏；
收敛或抖动 = GC 滞后；单次绝对值不作数。

### 三、验证

| 项 | 结果 |
| --- | --- |
| 长跑实跑 | 223 轮 / 150s、463 轮 / 420s 全绿；主进程始终存活 |
| 反向验证 | 摘掉重启调度 → 2 例红；熔断阈值差一 → 1 例红；dispose 不杀进程 → 1 例红 |
| `analyze_inproc` | 315 文件 0 error / 0 warning / 0 info |
| `dart format` | 0 changed |
| `arch_check` | 分层纪律检查通过 |

**仍未勾**：ROADMAP 要求的 **2 小时真机长跑**未做（本机只跑到 7 分钟级 / 463 轮）。
工装与命令已就位，真机一条命令即可。

## 本次会话（2026-09-28 三续）：M9 原子升级/回滚 + 长跑工装加固

两件事并行：用户选定的 ③「2 小时长跑」出结果了但**红在第 8660 轮**，根因排查与
加固；同时开工早已同意但一直没做的 M9 `upgrade`/`rollback`。

### 一、2 小时长跑：8650 轮全绿，第 8660 轮红在环境层

第一版（`MISTREAM_SOAK_SECONDS=7200`）跑到 **第 8660 轮**失败，报：

```
Error: Error when reading '../../.dart_tool/package_config.json': 拒绝访问。
第 8660 轮崩溃后宿主没能自愈
```

**这不是「源崩溃影响了主进程」** —— 主进程全程存活。失败在**子进程启动阶段**：
每轮 `dart run` 都要读 I: 盘的 `.dart_tool/package_config.json`，8650 次之后被
系统拒绝访问，子进程起不来，宿主退避 5 次后按设计熔断，此后每轮都失败。

已排除资源耗尽：I: 盘余 709G、`%TEMP%` 仅 44 个条目、`.dart_tool` 仅 64 个文件，
**都不随轮数增长**。是那块盘的虚拟化文件系统语义（同源问题见 P0 那条）。

**RSS 曲线（重要，纠正了上一节的判断）**：阶梯式**下降**，不是增长 ——

| 轮数 | RSS |
| --- | --- |
| 50 | 276.1MB |
| 2950 | 285.1MB（高水位） |
| 3000 | **127.0MB** |
| 3450 | **65.7MB** |
| 6000 | 63.0MB |
| 8650 | **55.8MB** |

276 → 285MB 是「VM 堆按需扩张」的高水位，之后 major GC 分几次把内存**归还**给
OS，稳态比起点还低 220MB。上一节记的「463 轮结束 282.4MB」不是矛盾，只是 420 秒
的短跑停在**高水位段**就结束了。**RSS 单调不增 = 无泄漏**，这条结论比之前更硬。

### 二、修掉一个真缺口：`start()` 的 catch 分支不自愈

`_onProcessExit`（进程崩溃/握手失败）会挂退避重启，但 **launcher 自己抛异常时
（exe 不存在、权限被拒、端口耗尽）走的是 `start()` 的 catch 分支，那里只
`_notifyReady(false)` 就返回**，不挂 `_scheduleRestart` —— 源码注释里原本就写着
「不会自愈」。这与 docs/08 §6「失败退避重启」的承诺不符，也是长跑第 8660 轮之后
宿主永久失能的原因。

已改为走同一把 `_scheduleRestart`（退避与熔断语义与进程崩溃完全一致）。新增用例
`启动阶段就抛异常时也会退避重试，直到熔断` 覆盖这条路径（此前零覆盖）。

### 三、长跑工装加固：桩搬到本机 C 盘

新增 `packages/spider_host/test/support/child_staging.dart`：把子进程桩复制到
`%TEMP%` 再跑。桩只用 `dart:io`/`dart:convert`，而 dart 是按**脚本所在目录**向上
找 pubspec（实测：cwd 留在 I: 盘、脚本放 C: 盘也能跑通），所以放进一个没有
`pubspec.yaml` 的目录就完全不碰 pub 层 —— **I: 盘 `package_config.json` 的读取
次数从「每轮 1 次」降到「整轮 1 次」**。

### 四、M9 原子升级与回滚（`packages/plugin_host/lib/src/plugin_store.dart`）

磁盘布局 `<pluginsDir>/<id>/versions/<ver>/` + `<pluginsDir>/<id>/files/current`
（**文件**，内容就是版本号）。两条实测驱动的决策：

- **指针必须是文件**：`File.renameSync` 覆盖已存在文件 OK，而
  `Directory.renameSync` 覆盖非空目录抛 `PathExistsException`（Windows 实测）。
  用文件做指针，切换就是**一次 rename**，天然原子。
- **写入先落 `.staging_<ver>` 再换名**：同卷 rename 原子，磁盘上永远要么是完整的
  旧版本、要么是完整的新版本。

核心不变量：**任何失败路径都不能让用户失去当前能用的版本**。具体地：

- `upgrade` **新版本先在旧版本仍运行时激活**，成功才动指针；激活失败返回 `null`，
  指针与旧版本目录一个字节都不动
- 发布通知（`publishPointer` 钩子）失败时**保留新指针**并返回 `null` —— 磁盘上
  新版本才是真的，把指针写回旧版本会让它指向可能已被清理的目录
- 不设「拒绝降级」闸门（降级就是「升级到更低的版本号」）；重复投递同一版本由
  `alreadyCurrent` 短路
- `rollback` 只回到记录的上一个版本；目标目录已被清理时返回 `null`，**不假装成功**
- `pruneBrokenVersions` 在「从未发布过」时直接跳过，不误删刚下载好的版本
- `remove` 幂等（跑在 `uninstall` 里，也会被每个测试的 tearDown 走到）

### 五、验证

| 项 | 结果 |
| --- | --- |
| 新增用例 | **26**（store 15 + upgrade 11），`plugin_host` 包 30 → **56** |
| 全量垫片 | 120 → **146** 例 |
| 反向验证（M9） | `python .workbuddy-ai/scripts/rev_verify_plugin_upgrade.py` **7 项全部变红**，且每项只红对应那一条（覆盖精确） |
| 反向验证（长跑） | `python .workbuddy-ai/scripts/rev_verify_soak.py` **4 项全部变红**（第 4 项是新加的，专钉 `start()` catch 分支的自愈） |
| `analyze_inproc` | **320 文件 0 error / 0 warning / 0 info** |
| `dart format` | 0 changed |
| `arch_check` | 分层纪律检查通过 |

反向验证的 7 项：升级顺序（先激活后切指针）、发布失败回写指针、init 不清残留、
prune 不判无指针、版本比较退化成字符串、rollback 假装成功、upgrade 不检查产物存在。

### 六、长跑重跑：2 小时全绿（M5 出口标准最后一条已勾）

工装加固后重跑 `MISTREAM_SOAK_SECONDS=7200`，日志
`.workbuddy-ai/soak/soak-2h-rerun.log`（**该目录不入库**）：

```bash
cd packages/spider_host
MISTREAM_SOAK_SECONDS=7200 dart run test/host_soak_test.dart
```

**结果（2026-09-28 22:20 启动 → 2026-09-29 00:21 结束）：11155 轮 / 7200s 全绿**，
`EXIT=0`，**全程零报错**，4 条用例全过，主进程始终存活。

| 轮数 | 50 | 3000 | 3500 | 5000 | 7000 | 11155 |
| --- | --- | --- | --- | --- | --- | --- |
| RSS | 277.1 | 286.4 | 186.2 | 159.4 | 45.5 | **43.1** |

基线 275.5MB → 结束 43.1MB（**增长 −232.4MB**）。阶梯下降，**单调不增 = 无泄漏**。

对比第一版：第一版 94 分钟跑到 8650 轮就撞环境故障；重跑跑满 120 分钟、**11155 轮**
（多 2500 轮）且零报错 —— 桩搬出 I: 盘确实消除了那个故障。**M5 出口标准最后一条
据此勾选**。

## 本次会话（2026-09-30）：沙箱逃逸——修掉两类真漏洞 + 一处记录失真

M9 出口标准第一条是「沙箱逃逸测试全部被拦截（越权网络、SSRF、路径穿越、配额
超限）」。核账时发现这条既**没被验过**，实现里也**真有洞**。

### 一、路径穿越 guard：两个真漏洞（探针实测）

先写探针 `.workbuddy-ai/scripts/probe_path_guard.dart` 把各种形态跑一遍
（21 例，只 import `src/path_guard.dart`，避开 `plugin_host.dart` 导出面连带
的 `storage` native）。**修前 6 例不符**：

| 形态 | 输入 | 修前 | 应该 |
| --- | --- | --- | --- |
| **兄弟目录** | root=`/sandbox/plugin1`，req=`/sandbox/plugin10/secret` | 放行 | 拦 |
| 同上（相对） | req=`../plugin10/secret` | 放行 | 拦 |
| **绝对路径里的 `..`** | req=`/sandbox/plugin1/../../etc/passwd` | 放行 | 拦 |
| 同上 | req=`/sandbox/plugin1/../plugin2/x` | 放行 | 拦 |
| **Windows 盘符** | root=`C:\sandbox\plugin1`，req=`C:\sandbox\plugin1\data.json` | 拦 | 放行 |
| 同上（相对） | req=`data/file.json` | 拦 | 放行 |

两个根因：

1. **用字符串前缀比较判「在不在根下」**。`'/sandbox/plugin1'` 确实是
   `'/sandbox/plugin10'` 的字符串前缀，于是**去兄弟目录被判成在沙箱内** ——
   插件能读写同级插件的文件。
2. **绝对路径直接早退，`..` 从未被解析**。`/sandbox/p1/../../etc/passwd` 以根
   开头就放行，实际解析后是 `/etc/passwd`。
3. 附带一个**反向**的：root 不以 `/` 开头时（Windows 盘符），解析结果总以 `/`
   开头，`startsWith` 恒 false → **恒判逃逸**，Windows 上沙箱完全不可用。

修法：`path_guard.dart` 重写为**逐段解析 + 逐段比较**，真正消解 `..`，识别盘符，
`\` 与 `/` 同等对待，无法解析的输入一律拒绝。大小写语义按平台（Windows 不敏感），
并开一个 `caseSensitive` 参数让两种语义在任一平台都能测。修后 21 例全过。

同时把类文档写清边界：**这是字符串层防线，看不出符号链接**，真实 IO 前仍应
`resolveSymbolicLinks` 二次校验。

### 二、`PluginSandbox` 是空壳（记录失真）

`PROGRESS` 一直记着 `plugin_host` 有「isolate 沙箱」，但：

- 类文档写着「Runs plugin code in isolated Dart isolates」，而 `execute()` 里
  **根本没有 spawn isolate**，直接 `await task()` 在当前 isolate 跑
- `_isolates` 表**只在 `terminate` 里被读、从来没被写入** → `isRunning` 恒为
  false
- `execute` 里那个 `ReceivePort` 建了就扔、从未被监听
- `terminate` 无条件 `_activeIsolates--` → 计数可减成负数，限额彻底失效
- 全仓**无任何调用方**（只在导出面里）

处理：**如实化**，不假装。类文档改为「并发闸门与登记表」，写明「不是隔离执行器」
并指向真正的隔离（`spider_host` 子进程 / 嗅探 isolate）；实现改为按插件集合登记，
修掉计数与 port 泄漏；`terminate` 明确标注「只摘登记，不中断任务」。

**没有真实现 isolate 隔离**，理由：它无调用方、不在主链路、ROADMAP 出口标准不含
它，而真实架构里插件是 JS 脚本（跑在 `spider_host` 子进程，已有进程级隔离）。
与其留一个假的隔离器，不如留一个说明白了的限额器 —— 记为已知缺口而非完成。

### 三、验证

| 项 | 结果 |
| --- | --- |
| 探针 `probe_path_guard.dart` | 21 例，修前 **6 例不符** → 修后 **0 例不符** |
| `plugin_escape_test.dart` | 4 → **16 例**（路径穿越 8 + 权限闸门 4 + 并发限额 4） |
| `plugin_host` 包 | 56 → **68 例** |
| 反向验证 `rev_verify_escape.py` | **5 项全部变红**（退回前缀比较 / 不消解 `..` / 不识别盘符 / 忽略大小写参数 / 不清登记） |
| `analyze_inproc` | 320 文件 **0 error / 0 warning / 0 info** |
| `dart format` / `arch_check` | 0 changed / 分层纪律检查通过 |

**M9 出口标准第一条据此勾选**（M9 总览 1/6 → **2/6**）。四类逃逸的证据位置写在
ROADMAP 该条下面 —— 其中 SSRF 不在本包，由
`spider_host/test/host_api_redirect_test.dart` 9 例覆盖。

## 本次会话（2026-09-30 二）：权限撤销后插件优雅降级

M9 出口标准第四条。核账时发现这条**根本没有实现**，不是「没测」：

```dart
// 改之前：PermissionChecker 只有改账，与 PluginManager 完全脱钩
void revoke(String pluginId, PluginPermission permission) {
  _grantedPermissions[pluginId]?.remove(permission);
}
```

`revoke` 返回 `void`，没有任何人监听；`PluginManager` 连 `PermissionChecker` 的
引用都没有。也就是说**撤销一个正在运行插件的权限，对那个插件毫无影响** ——
它继续按原样跑，权限只在「下次启用时读账本」才生效。

### 一、补的三处落点

| 落点 | 做法 |
| --- | --- |
| **通知** | `PluginApi.onPermissionRevoked(List<PluginPermission>)` 新增钩子（**具体默认空实现**，存量插件不改也能编译）；`PluginManager.revokePermissions` 先改账、再通知 |
| **不崩溃** | 插件处理撤销时抛异常 → 被捕获进返回值的 `error`，**不外泄、不改状态、不影响其它插件** |
| **调用侧** | `PluginManager.requirePermission` 闸门，缺权限时抛可捕获的 `PluginPermissionDenied`，而不是让插件内部炸出难归因的异常 |

顺带修掉账本 API 的两个「信息丢失」：`revoke` 由 `void` 改为返回 `bool`
（**账目是否真的变了** —— 调用方据此决定要不要通知，撤一项本就没有的权限无需
惊动插件）；`revokeAll` 返回**被撤掉的清单**。

### 二、有意不做的事（写进代码文档，不是遗漏）

- **不自动停用插件**。撤销一项权限不等于插件废了 —— 源插件失去 `network` 可能
  只回本地缓存。要不要停用是应用层策略。是否还「完整可用」用 `isFullyPermitted` 查。
- **不把插件标成 `PluginState.error`**。它仍在运行，标故障不实。
- **通知只在插件 `enabled` 时发**。未运行（未启用 / 已停用 / 激活失败）的插件
  下次启用会重新读账本，无需运行时通知；对它们误发反而会惊动一个没在跑的对象。

`PermissionRevocationOutcome` 把五种情形显式列出来（`notified` / `notRunning` /
`handlerFailed` / `notGranted` / `notInstalled`），调用方不必猜。

### 三、验证

| 项 | 结果 |
| --- | --- |
| `permission_revocation_test.dart` | 新增 **22 例**（通知 5 / 隔离 3 / 免通知 4 / 撤销全部 2 / 调用侧闸门 3 / 账本语义 2 / `isFullyPermitted` 3） |
| `plugin_host` 包 | 68 → **90 例**全绿 |
| 反向验证 `rev_verify_permission.py` | **8 项全部变红**（不通知 / 异常外泄 / 回滚账目 / 误发通知 / 通知请求清单而非实撤项 / 清单可变 / 闸门放行 / `revoke` 恒 false） |
| `analyze_inproc` | 322 文件 **0 error / 0 warning / 0 info** |
| `dart format` / `arch_check` | 0 changed / 分层纪律检查通过 |

**M9 出口标准第四条据此勾选**（M9 总览 2/6 → **3/6**，出口标准 4/6）。

## 本次会话（2026-09-30 三）：畸形主题包不导致白屏或不可读对比度

M9 出口标准最后一条。核账时发现两处**能绕过对比度校验**的真漏洞 ——
既有实现（`loadThemePackage` 的不达标回退）本身是对的，但判据漏了两类输入。

### 一、探针实测（9 例，修前 4 例不符）

先写探针 `.workbuddy-ai/scripts/probe_theme_package.dart`，判据是**最终生效的
主题**长什么样，而不是「有没有告警」—— 告警了但仍按畸形值生效，等于没兜住。

| 形态 | 输入 | 修前 | 应该 |
| --- | --- | --- | --- |
| **全透明前景/背景** | `background=#00000000`、`primaryText=#00FFFFFF` | 21:1 **满分通过** | 拒 |
| 半透明 | `surface=#80FFFFFF` | 通过 | 拒 |
| **尺度为负** | `spacing.unit=-5` | 告警但仍生效 −5 | 夹住 |
| **尺度超大** | `spacing.unit=1e300` | 告警但仍生效 1e300 | 夹住 |
| 圆角为负 | `radius.lg=-1` | 原样生效 −1 | 夹住 |
| 投影超大 | `elevation.overlay=1e300` | 原样生效 1e300 | 夹住 |

### 二、两个根因

1. **`ContrastChecker.luminance` 只看 RGB、忽略 alpha。** 于是「全透明黑底 +
   全透明白字」算出来是 21:1，判为完全达标 —— 而渲染出来什么都看不见，等效
   白屏。**对比度校验的结论只有在「所有令牌都不透明」时才与渲染一致**，这个
   前提此前完全没人守。规范 §2.1 里只有 `color.overlay`（`rgba(0,0,0,0.6)`）
   是刻意半透明的，而它尚未建模；将来建模时要把这条检查对它开豁免。
2. **尺度令牌只校验、不夹住。** `validateScale` 报出「必须是正数」后，值仍
   原样生效 —— `SizedBox(width: -5)` 在 debug 下直接断言失败，`4e300` 会把布局
   撑爆。文档里写的「夹住或按基准值用即可」当时**并没有实现**。

### 三、修法

- **颜色**：解析阶段拒掉带 alpha 的值（`_parseColor` 返回失败原因，调用方只报
  一条告警）。**拒绝而非强改 alpha** —— 强改会静默把作者写的值换掉，比明确拒绝
  更难排查。合成结果再查一遍（`findTranslucentTokens`），基准主题自身畸形也拦得住。
- **尺度**：新增 `clampScale` 与 `_clampScaleToken`，**在解析阶段**夹进安全区间
  （`unit ∈ [1,16]`、圆角 `∈ [0,9999]`、投影 `∈ [0,64]`）并告警；`applyTo` 再过
  一遍 `clampScale` 兜住基准主题；`validateScale` 补上界告警。
  夹在解析阶段而不是合成阶段，是因为 `loadThemePackage` 与 `tools/theme_lint`
  共用 `fromJson → applyTo → validateTheme` 这条链路、且有「两边结论一致」的
  测试 —— 夹在解析阶段，一致性由构造保证。
- **brightness**：`_lintSelfConsistency` 本来只在 lint 里查「声明的明暗与实际
  底色矛盾」，**运行时完全不查**（不经 lint 直接装包的用户看不到任何提示）。
  判据抽成 `checkBrightnessConsistency` 由两边共用，运行时作为**告警**
  （不回退：配色本身合规，不可读的只有系统 UI 那部分）。

### 四、验证

| 项 | 结果 |
| --- | --- |
| 探针 `probe_theme_package.dart` | 9 例，修前 **4 例不符** → 修后 **0 例不符** |
| `theme_engine` | 90 → **98 例**全绿 |
| `theme_lint` | **25 例**全绿（含与运行时的一致性测试） |
| 反向验证 `rev_verify_theme.py` | **7 项全部变红**（放行 alpha / 不夹尺度 / 不查不透明性 / 不查 brightness / clampScale 空转 / 不报上界 / 不透明性检查写坏） |
| `analyze_inproc` | 322 文件 **0 error / 0 warning / 0 info** |
| `dart format` / `arch_check` | 0 changed / 分层纪律检查通过 |

### 五、记录更正：总览的 M9 一直是**少数**的

改之前 ROADMAP 里 M9 出口标准实际已勾 **5 条**（升级回滚、沙箱逃逸、权限撤销、
对比度、生命周期），而 `PROGRESS.md` 总览写的是 **3/6** —— 漏数了更早完成的
对比度与生命周期两条。此前每次「+1」都是在错误基数上加的。本次一并更正为
**6/6**，并在 ROADMAP 的进度实况里记明。

> 教训：总览数字与 ROADMAP 的复选框是**两份数据**，改一处必须对另一处核账。
> 计数类字段应该用 `grep -c "^- \[x\]"` 现场数，不要手写。

## 本次会话（2026-10-01）：M7 收尾——频道排序 + 数字键跳台/方向键换台

M7 出口标准停在 3/4（剩「换台 P50 < 2s」卡真实网络），但**交付物**还差两项
纯本地能做的：频道排序、数字键跳台与方向键换台。这一轮把这两项做完。

### 一、频道排序（`packages/live/lib/src/live_channel_sort.dart`）

- `LiveChannelSortOrder`：`source`（源顺序，默认）/ `byName`（名称自然序）/
  `favoritesFirst`（收藏优先）。
- **自然序**而不是 `String.compareTo`：逐码点比较会把 `CCTV10` 排在 `CCTV2`
  前面（`'1' < '2'`），而 `CCTV1`…`CCTV17` 正是真实源里最常见的一类台名。
  实现上先比「去掉前导零后的位数」再比字典序，因此不必把数字串转成 `int`
  （真实台名不会溢出，但没必要留这个坑）。中文名走码点序**不是**拼音序，
  这一点写进了代码文档 —— 拼音序要一份拼音表，收益与成本不成正比。
- **刻意不做「按频道号」档**：`LiveChannel.channelNumber` 在本项目整条链路里
  没有生产者（`LiveParser` 不产出、真实 txt/m3u 也没有该字段）。提供一个永远
  退化成源顺序的档位，只会让用户以为排序坏了。
- **稳定排序**：Dart 的 `List.sort` 不保证稳定，所以显式用「原始下标」做兜底
  比较键 —— 否则同键频道每次排序的相对位置都可能变，列表看起来在随机抖动。
- **不改动入参**：`source` 档也返回副本，避免调用方拿到的视图与仓库那份共用
  同一个可变对象。
- 偏好落库 `live.channel_sort`（存**枚举名**而不是序号：序号在增删档位后会
  静默错位），走 `apps/mistream/lib/application/live_sort_settings.dart`。

### 二、数字键跳台与方向键换台

分三层，按可测性切开：

| 层 | 文件 | 内容 | 覆盖 |
| --- | --- | --- | --- |
| 定位 | `packages/live/lib/src/live_channel_navigator.dart` | `LiveChannelNavigator`（上/下台环绕、按号定位）+ `ChannelNumberBuffer`（攒数字） | 用例 25 例 |
| 规则 | `packages/live/lib/src/live_shortcuts.dart` | `LiveKey` + `LiveCommand` + `resolveLiveKey` | 用例 13 例 |
| 翻译 | `apps/mistream/lib/features/live/live_shortcuts.dart` | Flutter 按键 → `LiveKey`（只有对照表，没有规则） | 类型检查 |
| 接线 | `apps/mistream/lib/features/live/live_player_page.dart` | 键盘钩子、换台、数字浮层 | 类型检查 |

- **为什么按键要用 `LiveKey` 而不是直接写 `LogicalKeyboardKey`**：
  `package:flutter/services.dart` 在纯 Dart 测试里编不了（本环境 widget 测试
  跑不起来），规则表若直接写在 Flutter 类型上就只能靠人工点一遍验证 —— 而
  「Esc 无条件接管会让直播下退不出全屏」「Shift 不让位则直播下没有音量键」
  这两条是真会出错的判断。拆开之后规则表是纯 Dart，能被用例盯住。
- **`Esc` 只在数字缓冲非空时接管**，空缓冲让给播放器默认表（那里是退出全屏）。
- **`Shift` / `Ctrl` 组合键一律让位**：↑/↓ 被换台占了之后，`Shift+↑/↓` 是
  直播下仅剩的音量入口。
- **上/下台环绕**而不是夹在两端：按到底回到第一个台；夹住会让用户以为遥控器
  失灵。**按号越界返回 `null`** 而不是回退到第一个台，UI 明确提示「没有 N 号
  频道」——按了 999 却跳到 CCTV1 更让人困惑。
- 数字键**超时（1200ms）自动确认**，`Enter` 立即确认。遥控器没有输入框，
  这是必然的取舍，写在代码文档里。
- **换台在用户眼前那份列表上走**（已筛选 + 已排序）：`LivePage` 把
  `_filteredChannels` 随路由 extra 传给播放页，所见即所切。
- 换台失败**不夺走画面与键盘**：整页错误视图只用于首次起播失败；换台失败走
  浮层提示，用户还能接着按 ↑/↓ 换回去。
- 顺带给 `PlayerPage` 加了 `onKey` 钩子（在默认快捷键表**之前**询问，
  返回 `false` 则继续走默认表）。这是直播页能接管 ↑/↓ 又保留 `Shift+↑/↓`
  音量的前提。

### 三、踩到的两个坑

1. **`dart run` 下断言不生效**：给 `ChannelNumberBuffer` 写了
   `assert(maxDigits > 0)` 并配了 `throwsA(isA<AssertionError>())` 的用例，
   实测**不抛**（垫片是 `dart run`，非 assert 模式）——那是一条永远绿的假用例。
   已换成「`maxDigits: 1` 时只留最新一位」这种真实行为用例，并在用例注释里
   写明原因。
2. **Presentation 层不许 import `storage`**（`tools/arch_check` 抓到）：
   直播页为了存排序偏好直接引了 `SettingsDao`。改为在 application 层包一个
   `LiveSortPreference`（`AppAssembly.liveSortPreference`），页面只见应用层
   类型。

### 四、验证

| 项 | 结果 |
| --- | --- |
| `packages/live` + app 直播链路（`run_tests_live.dart`） | 144 → **206 例**全绿 |
| 全量垫片（`run_tests_shim.dart`） | **200 例**全绿 |
| 反向验证 `rev_verify_live.py` | **55 项全部变红**（新增 AM–BC 共 17 项） |
| `analyze_inproc`（live + app） | 81 文件 **0 error / 0 warning / 0 info** |
| `dart format` / `arch_check` | 0 changed / 分层纪律检查通过 |

反向验证新增项：自然序退化 / 前导零不剥 / 等值不同长度不比较 / 收藏优先写反 /
`source` 档返回同一对象 / 按序号解析 / 落库写序号 / 缓冲满时保留最旧 / 空缓冲
当 0 / 不环绕 / 越界回退第一个台 / 忽略 `channelNumber` / 找不到返回 0 /
`Esc` 无条件接管 / 组合键不让位 / 上写反 / 数字键一律当 0。

### 五、仍未做（如实记）

- **换台时保留上一路画面直到新流首帧**：需要双播放器交替 + 首帧回调，属 UI 层，
  且验证需要真实播放器 —— 本环境起不了。**没有实现，不是遗漏**。
- **低延迟缓冲策略**：同上，需真实直播流才能调参验证。
- **换台 P50 < 2s**：需真实网络与真实源（P5 阻塞项）。
- 换台与数字浮层的**渲染**未覆盖（widget 测试跑不起来），验证的是数据与规则，
  不是画得对不对。
- `apps/mistream/lib/features/live/live_shortcuts.dart` 那张按键对照表只有类型
  检查 —— 规则已经搬走，剩下的是机械翻译；漏认小键盘之类的错误仍只能人工发现。

## 下一步（按优先级，2026-09-19 续）

1. **P0 仓库健康** ✅ **已定位并交付守卫脚本**；根因属 I: 盘文件系统语义，
   非仓库问题。迁移到本地盘可彻底消除
2. **P1 门禁** ✅ 727 条 info 已收口，代码侧无告警。**但 2026-09-25 起本机
   跑不了门禁命令**（见第 7 条），须在环境恢复后复跑确认
3. **P2 编码 API 补齐** ✅ **已完成**：`gbkDecode`、`rsa`、`aes`（含位置参数
   契约）均落地；2026-09-25 补齐最后的 JSON 解析组
   `jsonpath`/`pjfh`/`pj`/`pjfa`（提交 `0888440`，compat 用例 130 → **178**）。
   同表其余项建议继续对 `docs/05` §2.2 核账
4. **P3 验收** 补齐出口标准中纯本地可验证的条目：~~M2 迁移回滚测试~~ ✅
   **已完成**（`storage/test/migration_test.dart` 5 例覆盖 v1→v3 / v2→v3；
   `backup_manager_test.dart` 覆盖「迁移失败 → 回滚 → 备份仍在」；本文件
   此前记「缺迁移/备份验证」有误，2026-09-28 已更正总览表）、
   ~~M9 主题对比度测试~~ ✅ **已完成**（2026-09-26，四套主题 × 16 对组合
   全量断言，主题包共用同一份矩阵）、~~M9 尺度/字体/动效令牌~~ ✅ **已完成**
   （2026-09-26 续与 2026-09-27）、~~M9 生命周期状态机测试~~ ✅ **已完成现有
   4 态的全部迁移**（2026-09-28，提交 `68a163d`）、M5 长跑稳定性
   - ~~M9 升级/回滚~~ ✅ **已完成**（2026-09-28 三续：新增 `PluginStore`，
     26 例 + 反向验证 7 项全红；**M9 总览 0/6 → 1/6**）
   - ~~M9 沙箱逃逸测试~~ ✅ **已完成**（2026-09-30：修掉路径穿越两类真漏洞 +
     `PluginSandbox` 空壳如实化；16 例 + 反向验证 5 项全红；**M9 总览 1/6 → 2/6**）
   - ~~M9 权限撤销后优雅降级~~ ✅ **已完成**（2026-09-30 二：补通知链路 +
     异常隔离 + 调用侧闸门；22 例 + 反向验证 8 项全红；**M9 总览 2/6 → 3/6**）
   - ~~M9 畸形主题包不导致白屏或不可读对比度~~ ✅ **已完成**（2026-09-30 三：
     修掉「透明度绕过对比度校验」与「尺度越界原样生效」两处真漏洞；
     theme_engine 98 例 + theme_lint 25 例 + 反向验证 7 项全红；
     **M9 出口标准 5/6 → 6/6，全勾**）
   - **M9 剩余（交付物，非出口标准）**：主题包的安装/启用链路（从插件目录加载，
     现在只有解析与校验）、插件中心 UI、`tool` 类插件的宿主 API、签名验证
5. **P4 债务** `libs/*.jar` 改 `tools/jvm_dist` 按需拉取、契约/长跑测试、
   播放页/首页之外的页面去 `globalRouterAssembly`（播放页与首页已完成注入化）
6. **P5 阻塞** 网络方案（代理 / 可访问机器）——所有「真实源」类出口标准都卡在此
7. **⚠️ 环境：Dart VM 命名管道创建不兼容（2026-09-25 新增，P0 级）**
   `dart analyze` / `dart test` / `flutter test` **全部无法运行**，报
   `CreateFile failed 231`（`ERROR_PIPE_BUSY`）。加 `dangerouslyDisableSandbox`
   现象相同。但 2026-09-25 五续已修正根因：本机只有 423 个命名管道（不是
   耗尽），Python `subprocess` 与 Dart FFI 的 `CreateNamedPipeW` + `CreateFileW`
   **都正常**；问题只在 Dart VM 的 `process_win.cc`（Node/libuv 同样失败）。
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
   换新窗口内的宿主复用已修（四续，`ac86873`）；仍待做的是**真子进程端到端
   验证**（本机 `Process.start` 被管道缺陷挡住，`CreateFile failed 231`，只能等
   环境恢复）。
9. **P2/P3 主链路审查余项**（来自 `docs/CODE_AUDIT_2026-09-27.md`）
   ~~搜索层不能选源~~ ✅、~~引导页三处~~ ✅、~~播放段边界~~ ✅、~~搜索网格全量
   重建~~ ✅（2026-09-27 已修，见上一节：`EpisodeIndex` 值对象统一序号约定、越界
   不再回退、`PlayResult` 回填集号、历史落库 `episodeIndex` 并在续播前比对、
   历史/收藏改走 `player` 入口；搜索网格改用稳定身份键 + `findChildIndexCallback`）、
   ~~`_CategoryDetailPage` 用全局装配~~ ✅、~~选源口径不一致~~ ✅
   （2026-10-02，见本文件末尾「本次会话（2026-10-02）」）。
   **余项：无。**（`router.dart` 里仍剩的两处 `globalRouterAssembly` 属第 5 条
   P4 债务，不在这条清单里）

---

## 本次会话（2026-10-01）· 二：M8 下载与离线——持久化与恢复

`packages/download` 从 22 测试做到 **109**，M8 出口标准由 0/5 到 **1/5**。
这一轮的重点不是「加功能」，是**把已经写好但没接上的东西接上**，以及把两处
看起来在工作、实际不可能工作的实现钉死。

### 查出的三处真实缺陷

1. **`download` / `download_segment` 两张表建了却零使用。** 任务只活在
   `DownloadManager` 的内存 `Map` 里，`schemaVersion = 3` 里那两张表一个写入方
   都没有 —— 「杀进程后重启状态恢复」和「断点续传」两条出口标准在结构上就不
   可能成立。补 `DownloadRepository`（抽象 + 内存实现）与
   `DriftDownloadRepository`，管理器每次状态变化都落库。
2. **`DownloadTask.id` 同毫秒碰撞。** 旧 id 是「当前毫秒的十六进制」，探针实测
   **建 5 个任务只活下来 2 个**（后建的覆盖先建的），UI 上表现为「点了新建下载，
   列表里没出现」。改为 `int`，由 DB 自增 / 内存实现 `++_seq` 分配。
3. **一条假通过用例。** 旧的 `clearCompleted removes completed tasks` 建 2 个任务
   却断言剩 1 个，`copyWith` 的结果**没赋值**（改的是临时对象）—— 它能过纯粹是
   因为上面那个 id 碰撞让第二个任务覆盖了第一个。改写为「真的跑完一个任务再
   断言只少那一个，**而且库里也少了**」。

### 本轮还改掉的

- 真实队列：并发上限（默认 3）、优先级降序出队、`pending` 真正被调度。旧实现是
  「谁先调 `startDownload` 谁先跑，且调用方要 `await` 到底」。
- HLS 分片续传：按 `seq` 跳过已完成分片，并**校验分片文件还在盘上**。
- 分片写盘「先写 `.part` 再改名」；合并前缺片**报错 + 删半成品**。
- 合并改为 Dart 侧字节拼接（原来生成的 `ffmpeg -i "concat:a|b|c"` **是错的**）。
- 保存路径从硬编码 `/downloads/<标题>` 改为应用数据目录下的 `downloads/`，并给
  删除加「不得越出下载根目录」的边界。
- 删掉 `DownloadService`（~122 行、**零调用方**的假实现）。
- 下载页改为从装配层取管理器（不再自己 `new`），`dispose` 只摘监听不销毁。

### 验证

| 项 | 结果 |
| --- | --- |
| `analyze_inproc.dart`（全仓 353 文件） | 0 error / 0 warning / 0 info |
| `run_tests_download.dart`（下载垫片） | 22 → **109 例**全绿 |
| `run_tests_shim.dart`（全量垫片） | 200 → **204 例**全绿 |
| 反向验证（53 项 mutation） | 见下 |

**反向验证**（`.workbuddy-ai/scripts/rev_verify_download.py`）第一轮 52 项里
50 项变红，两处没变红 —— 即「原子写」和「合并缺片」两条保障**没有任何用例盯住**。
补掉的方式不是加断言凑数，而是先给它们造出可观测面：

- **原子写**：给 `HlsDownloader` 加落盘传输层 `HlsWriteBytes`（与
  `HlsFetchBytes` 对称的「磁盘那一半」）。用例把落盘拆成两半、在中间停住，
  断言此刻**成品名不存在** —— 不注入落盘，这条保障只能靠崩溃注入才能看见。
- **合并缺片**：原实现是 `if (!exists) continue`，跳过并**照样返回 success**，
  用户拿到播到一半花屏的成品却毫无提示。改成 `StateError` + 删掉半成品
  `merged.*`，用例用 `onSegmentDone` 在落盘后、合并前删掉一片来构造场景。
- **等价变异**：原 `E4`（取消检查）删的是「拿到信号量名额**之前**」那处提前返回，
  删掉它任务照样会在拿到名额后立刻发现已取消 —— 可观测行为完全一致，是个
  **等价变异**，放进集合只会得到一条永远不红的记录。改为针对「拿到名额之后」
  那处检查。
- **互相遮蔽**：`E3`（越界检查）一度不红，因为它被 `E2`（文件是否还在盘上）挡住了
  —— 越界序号的文件本来就不存在，两条检查同时生效时只看得见一条。用例改成
  「越界序号的文件**还在盘上**」（播放列表变短、上一轮下的是更长的变体）才分开。
- 另补三条用例钉住此前只靠一条脆弱用例变红的行为：`restore` 不自动开始等待中
  的任务、暂停后残余进度回调不写进任务、`listTasks` 同时刻按 id 升序（用
  `upsertTask` 乱序写 id 才测得出兜底键）。

最终在提交后的代码上重跑全部 **53 项，逐项变红**（`REVERSE-VERIFY OK`）。

> 反向验证的教训：**「没变红」不等于「用例写少了」，也可能是变异本身等价，
> 或者被另一条检查遮蔽。** 判断顺序是「这条保障有没有可观测差别」→ 没有就先造
> 可观测面（注入）；有差别但两条检查互相遮蔽 → 换一个只命中其中一条的场景；
> 都没差别 → 那是等价变异，改变异而不是加用例。
>
> ⚠️ 顺序坑：**`dart format` 会把长行折成多行，从而打断变异锚点。** 本次
> `startDownload` 里的 `_updateTask(task.copyWith(...));` 被折成三行，`D3` 的锚点
> 归零（脚本会打 `[SKIP] anchor not found` 并判失败，不会静默通过）。**先格式化，
> 再跑反向验证。**


---

## 本次会话（2026-10-01）· 三：把下载接进主流程

这一轮做的不是「加功能」，是**给一个只有半条链路的功能补上另外半条**。

### 查出的缺口：三列零写入方

下载此前只有**一个入口** —— 下载页手动粘贴 URL。后果是 `download` 表的
`site_id` / `vod_id` / `episode_name` 三列**没有任何写入方**：

- 下载列表分不清「同一部剧的第几集」（`vod_name` 是影片名，多集长得一模一样）；
- 「已加入下载」这个状态无从判断，用户连点两次会建两条各下一半。

### 新增 `DownloadUseCase`（应用层编排）

`apps/mistream/lib/application/download_use_case.dart`。收拢四件必须按序发生、
且各有失败模式的事：

1. **解析真实地址** —— `vod_play_url` 可能是**网页播放页**（`share/xxx` 形态的
   线路全是这样），必须经 `PlayUseCase` 解析，否则下回来是个 HTML。
2. **透传反盗链头** —— `MediaSource.headers` 里的 `Referer` / `User-Agent` 是源站
   判盗链的依据。播放有 mpv 帮忙设，**下载器没有**，丢了就是一路 403。
3. **按「影片 / 集」两级分目录** —— HLS 分片名是固定的 `segment_000000.ts`，
   多集共用一个目录会**互相覆盖**，两份任务各自以为下完了，合出来两集混在一起。
4. 落库后**立即发车**（用户点的是「下载」，不是「放进待办」）。

**依赖收窄成函数类型**：不依赖 `PlayUseCase`，而收一个 `PlayableSourceResolver`
函数类型。`PlayUseCase` 背后是 Spider 运行时 + 静态/CDP 两级嗅探器一整套 ——
直接依赖意味着「测去重与请求头透传」也得把那一整套起起来，于是这些分支最终
不会有人测。装配层用 `_resolvePlayableSource`（8 行）适配。

**幂等键是 `(siteId, vodId, episodeName)` 三件套**：`vodId` 只在单个源内唯一，
两个采集站可能给同一部片同一个 `vod_id`；只看 `vodId` 则同站的两部片互相顶掉；
不看 `episodeName` 则整部剧只留得下一条。已存在则**不再解析地址**；失败的任务
**也算已存在**（重试入口在下载列表的「继续」）；`cancelled` **不算**。

### 配套改动

- `DownloadTask` 加 `siteId` / `vodId` / `episodeName`（`fromJson` / `toJson` /
  `copyWith` 全通）+ `displayName`（`影片名 · 集名`）。**集名单独存，不拼进
  `title`** —— `title` 对应 `download.vod_name`，拼进去它就不再是影片名了，
  而「同一部片的多集」要靠 `vod_id` + `episode_name` 判断。
- `DriftDownloadRepository` 的 `_toCompanion` / `_toTask` 接通三列。
- `DownloadManager.createTask` 加三个可选命名参数。
- `AppAssembly.downloadSavePathFor(vodName, [episodeName])` 改两级分目录
  （`episodeName` 是**可选位置参数** —— 加它时打断了三处既有调用，改可选后不必
  逐个改）。`AppAssembly` 新增 `downloadUseCase` 字段与适配函数。
- `DetailPage` 剧集卡片加 `onMenu`：桌面右键（`onSecondaryTapDown`）与触屏长按
  （外层 `GestureDetector`，因为 **`InkWell` 没有带坐标的 `onLongPressStart`**）
  都通到同一个菜单。「已在下载列表」做成**禁用项**而不是隐藏 —— 用户第二次点
  时要看到「为什么点不动」。
- 下载页列表标题与删除确认框改用 `displayName`。

### 验证

| 项 | 结果 |
| --- | --- |
| `dart format`（363 文件） | 2 changed（已格式化） |
| `tools/arch_check` | 分层纪律检查通过 |
| `analyze_inproc.dart`（全仓 358 文件） | 0 error / 0 warning / 0 info |
| `run_tests_download.dart` | 109 → **126 例**全绿 |
| `run_tests_shim.dart`（全量） | 204 → **216 例**全绿 |

新增用例分布：`download_use_case_test.dart` **10 例**（新建文件）、
`download_test.dart` +2、`download_repository_test.dart` +2、
`download_manager_test.dart` +1、`app_assembly_test.dart` +2。

`download_use_case_test.dart` **同时登记进两个垫片** —— 与 `live_*` 的既有约定
一致：全量垫片收全部 app 层用例，专项垫片用于快速迭代。

### 反向验证新增 H 组（14 项）

`rev_verify_download.py` 从 53 项增到 **67 项**。H 组覆盖这一批的每处保障：

| 标签 | 摘掉的保障 |
| --- | --- |
| H1 | `displayName` 忽略集名 |
| H2 / H3 / H4 | drift 不写 `site_id` / `vod_id` / `episode_name` |
| H5 | drift 读回时不带来源三列 |
| H6 | `addEpisode` 不去重 |
| H7 | `addEpisode` 丢掉反盗链请求头 |
| H8 | `addEpisode` 建完不发车 |
| H9 | `addEpisode` 不把来源三列交给管理器 |
| H10 / H11 / H12 | `findExisting` 不看集名 / 影片 ID / 站点 ID |
| H13 | `findExisting` 把 `cancelled` 也算已存在 |
| H14 | `downloadSavePathFor` 不按集分目录（runner 走全量垫片） |

其中 H10–H12 一开始只有 H10 有判据：原用例只变化了 `episodeName`，另外两处
`continue` 摘掉也不会红 —— 补了「同一站点下的不同影片互不算已存在」与
「不同站点上的同名影片互不算已存在」两条用例才有判据。

按门禁顺序执行：**先 `dart format`，再跑反向验证**（上一批踩过格式化打断锚点的
坑），并在格式化后重跑了一次锚点唯一性检查（67/67 锚点均恰好命中一次）。


> **测试运行方式（重要）**：含夹具或 native 依赖的包，必须 `cd` 进包目录再跑
> `dart test`。从仓库根跑会因 cwd 不对而误报失败/跳过（`spider_js` 实测：
> 根目录 146 通过 / 4 失败，包目录 180 通过 / 0 失败）。`melos exec` 天然以
> 包目录为 cwd，是更稳的选择。
>
> **提交后必做**：`sh tools/git_ref_guard.sh` 恢复被删的分支引用，否则下次
> 提交会产生孤儿提交、丢失历史链。


---

## 本次会话（2026-10-02）：主链路审查余项清空

`docs/CODE_AUDIT_2026-09-27.md` 里剩下的两条 P2/P3 余项都属同一类病：
**两种设计意图各写了一半**，而不是「写错了」。

### 一、`_CategoryDetailPage` 不再读全局装配（P2-3）

`router.dart` 的 `_loadData` / `_loadMore` 此前直接取 `globalRouterAssembly`
（由 `setGlobalRouterAssembly` 写入的可变单例）。改为在 `didChangeDependencies`
里取一次 `AppScope.of(context)` 并缓存（`_assembly`），与 `DetailPage` /
`SearchPage` / `DownloadPage` 统一。

取装配放在 `didChangeDependencies` 而非 `initState`：`AppScope.of` 用的是
`getInheritedWidgetOfExactType`（不建立依赖，放 `initState` 里调也不算错），
但首次取数要等 context 就绪，放这里语义更直白。

⚠️ 这一处**功能上原本就是正确的**（审计已核实：其 `siteId` 来自
`_currentSite?.id`，而该字段已被 `_loadData` 同步为 `workingSiteId`）。修的是
**达成方式**——正确性此前依赖 `_currentSite` 与 `workingSiteId` 的隐式同步，
而不是显式传参。

### 二、选源口径统一（P3-3）

- **选择器**：只有 `isUsable`（= `_siteHasRuntime`）的源可点，不可用的灰显 +
  副标题「(暂不支持)」+ `onTap: null`
- **`HomeUseCase._getEnabledSites(siteId:)`**：**无条件**尊重用户显式选择，
  哪怕缺运行时

后者在首页路径上**不可达** —— 用户根本点不到不可用的源。

**统一到选择器那一侧**：`_getEnabledSites(siteId:)` 也按 `_siteHasRuntime` 过滤。
选这个方向而不是「放开选择器」的理由：选择器已经让用户**提前**知道原因；
放开只会让人点一个注定失败的源，再撞满 8s 的建运行时超时。「点了没反应比报
明确的错更难排查」这条理由在 UI 加灰显之前成立，现在已过时。

配套把「取不到站点」的文案分岔：显式给了 `siteId` 时不再是笼统的
「无可用站点」，而是「所选片源不可用（缺少运行时或已停用）」—— 用户（或上次
遗留的 `workingSiteId`）指的是**某一个**源，笼统文案会让人以为整份配置都坏了。

`home_page.dart` 的注释同步说明「支持与否只有一把尺子」。

### 验证

| 项 | 结果 |
| --- | --- |
| `analyze_inproc.dart` | 358 文件 **0 error / 0 warning / 0 info** |
| `run_tests_shim.dart` | 216 → **217 例**全绿 |
| `tools/arch_check` | 分层纪律检查通过 |
| `dart format` | 0 changed |

**反向验证（逐条摘，各自变红）**：

| 摘掉的保障 | 结果 |
| --- | --- |
| `_getEnabledSites` 的 `_siteHasRuntime` 过滤 | `+3 -1` —— `expect(result.isErr, isTrue)` 失败（旧行为返回 Ok：它拿缺运行时的源去建了运行时） |
| `_noSiteMessage` 的文案分岔 | `+3 -1` —— `Expected: '所选片源不可用（缺少运行时或已停用）' / Actual: '无可用站点'` |

新用例断言的是 `factory.createCalls == 0`，而不只是「返回了错误」：旧实现会
**先建运行时再撞超时**，只断言返回错误抓不住这一点。

### 仍未做（如实记）

- **UI 渲染未覆盖**：选择器灰显、分类详情页的接线都只有静态保证。本环境
  widget 测试连不上 `flutter_tester`，上述「全绿」覆盖的是数据与规则，
  **不是画得对不对**。
- `router.dart` 里仍剩两处 `globalRouterAssembly`（`:251` 给
  `PlayerPageWrapper` 传参、`:315` 作回退），属「下一步」第 5 条的 P4 债务。

---

## 本次会话（2026-10-02）· 二：真实配置源「无法使用」——spider jar 相对路径

**现象**（用户截图）：首页报
「所有站点均无法连接（共尝试 106 个：城市影视: spider jar 不存在: ./spider.jar）」。

**根因**（用户真实库 + 上游原文双证）：

- 用户库里 `config_source` 只有一行（`订阅 2026-09-25`）：
  `spider = './spider.jar;md5;af187c2a2be1bcbb5e183d77e740b21b'`、`spider_md5 = NULL`。
- `SiteRepository.configSourceSpider` 把这一整串**原样**返回。
- `JvmRuntimeFactory._ensureJar` 的判据是「不是 http(s) 就当本地文件路径」→
  `File('./spider.jar').existsSync()` 为假 → 抛 `spider jar 不存在: ./spider.jar`
  （`spider_runtime_factory.dart:652`）。
- 该配置 **105 个站点全是 `type=3` + `csp_`**。注意站点列里写的 `runtime='http'`
  是**陈旧值且不权威**——运行时由 `classifySiteRuntime(typeCode, api)` 现场重算，
  所以照样进了 JVM 分支。整份配置因此全灭，首页只剩一句笼统文案。
- 上游现状（2026-10-02 `curl` 实测）：`api.json` 里**仍是**
  `"./spider.jar;md5;abc13bea…"` —— 相对路径不是历史遗留，是当前写法。
  （顺带：`core_config.parseSpiderField` 只拆 md5、**不解析相对路径**，
  所以这个 bug 对新导入的行同样成立，不只是旧数据。）

**修法**：在**唯一读点** `configSourceSpider` 把相对路径按配置源 URL 解析成绝对地址
（`resolveSpiderJarUrl`）。选这个位置的理由：4 个消费方（`app_assembly` /
`detail_use_case` / `home_use_case` / `play_use_case`）全走这一个口，改一处全覆盖；
且**旧数据不需要重新导入**。

**刻意不做**：`configSourceSpiderMd5` **不回退**到 `spider` 字段里内联的 md5。
实测旧行的内联 md5（`af187c2a…`）与内联 URL 同龄、已过期（上游现值 `abc13bea…`），
采纳它等于拿一个已知过期的期望值去卡死一次本来能成功的下载。返回 null = 本次不校验；
新导入的配置由 `parseSpiderField` 把 md5 正确拆进列，校验照常生效。

### 验证

| 项 | 结果 |
| --- | --- |
| `analyze_inproc.dart` | 358 文件 **0 error / 0 warning / 0 info** |
| `run_tests_shim.dart` | **217 例**全绿 |
| `run_tests_storage.dart` | 47 → **54 例**全绿 |
| `tools/arch_check` | 分层纪律检查通过 |
| `verify_spider_jar_e2e.dart`（真实源 + 真实下载） | **14 项 0 失败**（java 子进程 1 项 SKIP，环境限制） |
| `verify_user_db_spider.dart`（用户库副本） | **5 项 0 失败**，105/105 站点解析出绝对 URL |

`verify_spider_jar_e2e.dart` 的闭环：真实源 → `installFromUrl` 落库（103 站点）→
读回 `configSourceSpider` =
`https://raw.githubusercontent.com/qist/tvbox/refs/heads/master/xiaosa/spider.jar`
→ 真下载 **HTTP 200 / 1859860 字节** → 实算 md5 `abc13beac287a298e6b7ca91af7404cd`
**等于**配置声明的值 → `_ensureJar` 的校验分支会通过。

**反向验证**（各自变红）：

| 摘掉的保障 | 结果 |
| --- | --- |
| `configSourceSpider` 的 `resolveSpiderJarUrl` | `+50 -4` —— 相对路径、已拆分相对路径、绝对 URL 剥离、空白归一 共 4 条转红 |
| 改回 `configSourceSpiderMd5` 的内联回退 | `+52 -2` —— 2 条 md5 断言转红 |

### 仍未做（如实记）

- **JVM 实例创建本地证不了**：`Process.start` 直接抛
  `ProcessException: 所有的管道范例都在使用中 (process_win.cc:744)`
  （本机命名管道缺陷），脚本里记 SKIP。所以「jar 下得下来、md5 对得上」有硬证据，
  「java 能加载它」没有——**需要在用户机器上实测一次**。
- **用户库数据确实陈旧**：105 站点 vs 上游当前 103，`spider_md5` 为空。
  建议顺手「刷新订阅」（会清库重建、拿到正确 md5）。但修后**不刷新也能用**。

---

## 本次会话（2026-10-02）· 三：发布链门禁被 101 条 lint 挡住，且本机此前**跑不了 lint**

### 现象

`v0.1.0-m10-2` / `v0.1.0-m10-3` 两次 Release 都卡在 `release.yml` 的「门禁」
（`melos run check:arch && melos run analyze`）：`check:arch` 通过，`analyze` 报
**`ERROR: 101 issues found`**，后续 6 步（装 native 依赖 / 构建 Windows / 校验包链 /
合规扫描 / 打包 / 建草稿 Release）全部 skipped，**一个包都没产出**。

### 根因（两层，第二层才是真问题）

1. **表层**：全仓有 101 条 `info` 级 lint，而门禁是
   `flutter analyze --fatal-infos --fatal-warnings` —— info 也算致命。
2. **真问题**：本机此前的「analyze 全绿」**从来不是这条门禁的证据**。
   `.workbuddy-ai/scripts/analyze_inproc.dart` 的文件头已写明：

   > lint 规则跑不了。analyzer 12 把 lint 规则拆到 `package:linter`，而 pub 上最新
   > `linter` 只支持 `analyzer ^5.2.0`，与本仓的 12.1.0 不兼容，装不上。所以
   > `linter.rules` 那一段只用来**抑制**，不会真的产生告警。

   该 shim 只能跑 analyzer 自带诊断，**跑不了任何 lint**。所以它报的
   `0 error / 0 warning / 0 info` 与 CI 的 101 条并不矛盾 —— 两者测的不是一回事。
   `release.yml` 是这条门禁**第一次真正执行**。

### 为什么本机跑不了 lint

本机 Dart **起不了任何子进程**（连 `git --version` 都失败）：

```text
CreateFile failed 231 (所有的管道范例都在使用中。)
ProcessException: ... (at ../../runtime/bin/process_win.cc:744)
```

`dart analyze` / `dart fix` / `dart test` / `dart run build_runner` 都要拉子进程
（analysis server / test runner / frontend_server），于是全废。沙箱内外表现一致，
与沙箱无关。

### 解法：用 Python 直接驱动 analysis server

`python` **起子进程是好的**。所以新增 `.workbuddy-ai/scripts/as_client.py`：由 Python
拉起 `dartaotruntime analysis_server_aot.dart.snapshot`，用 stdio 上的 analysis server
协议（**裸 JSON 行**，不是 `Content-Length` 分帧）直接对话。`edit.getFixes` 返回的是
嵌套结构 `{fixes:[{error, fixes:[{message, edits:[{file, edits:[{offset,length,
replacement}]}]}]}]}`。

这样拿到的是**与 CI 同一套分析器、同一套 lint** 的结果。校准：先用 Flutter 自带
Dart 3.13 扫全仓得 **149 条**，其中 48 条 `strict_raw_type` 全在
`packages/storage/lib/src/database/schema_versions.dart/`（根配置 `analyzer.exclude`
排除的生成代码，得自行按子串跳过）→ **149 − 48 = 101，与 CI 逐规则完全一致**。

随后又取到 CI 的 `.tool-versions` 基线 **Dart 3.12.2**（下载路径
`flutter_infra_release/flutter/<engine>/dart-sdk-windows-x64.zip`，`<engine>` 由
`releases_windows.json` 里 Flutter 3.44.8 的 commit 反查 `bin/internal/engine.version`
得到；注意 `dart-archive` 那条路在本机全 404），把客户端切过去，结果同样为 0 ——
做到「本地证据 = CI 证据」。

### 修复

| 规则 | 条数 | 处理 |
| --- | --- | --- |
| `unnecessary_brace_in_string_interps` | 16 | analysis server 自动修复 |
| `missing_whitespace_between_adjacent_strings` | 14 | 在**第一个字面量收尾引号之前**补空格 |
| `use_null_aware_elements` | 9 | 自动修复 |
| `prefer_initializing_formals` | 9 | **放行**（见坑 2） |
| `always_use_package_imports` | 7 | 自动修复 |
| `prefer_int_literals` | 6 | 自动修复 |
| `missing_code_block_language_in_doc_comment` | 6 | 代码块标注 `text` |
| `unnecessary_lambdas` / `unnecessary_parenthesis` / `sort_constructors_first` | 4 / 3 / 3 | 自动修复 |
| `cast_nullable_to_non_nullable` | 3 | 补 `!` |
| `avoid_positional_boolean_parameters` | 3 | 改具名参数（`set` / `check` / `checkBrightnessConsistency`） |
| `prefer_constructors_over_static_methods` | 2 | 改 factory，并**上移到字段之前** |
| `only_throw_errors` | 2 | 字段类型 `Object?` → `Error?` |
| `sort_unnamed_constructors_first` | 2 | 匿名构造上移到具名构造之前 |
| `use_raw_strings` / `prefer_foreach` / `prefer_final_locals` / `omit_local_variable_types` / `noop_primitive_operations` | 各 2 | 自动修复 |
| `prefer_single_quotes` / `prefer_null_aware_operators` / `no_adjacent_strings_in_list` / `unintended_html_in_doc_comment` | 各 1 | 自动修复 / 手工 |

### 三个「别照做」的坑（都是实测踩出来的）

1. **自动修复会提供「加 `// ignore:`」的假修复**。对
   `missing_whitespace_between_adjacent_strings` 直接应用，会插入 15 条 ignore
   注释，然后立刻换来 15 条 `document_ignores`。`as_client.py` 现在会**跳过**替换
   文本里含 `// ignore:` 的修复。
2. **`prefer_initializing_formals` 的自动修复会改坏代码**。本仓命中的 9 处全是
   「具名参数 → 私有字段」，自动修复产出 `this._fetcher`，既打断所有调用方
   （40 条 `undefined_named_parameter`），又换来 9 条
   `private_named_non_field_parameter`。**私有具名参数跨库不可用**，规则在本仓恒为
   误报，已在 `analysis_options.yaml` 写明理由放行。
3. **`missing_whitespace_between_adjacent_strings` 的空格要插在字符串内部**。先按
   「插在两个字面量之间」（`'a' 'b'`）修**无效** —— 规则要的是**拼接结果**里有
   空白（`'a' 'b'` 拼出 `ab`，缺的是 `a` 与 `b` 之间那个空格）。正确做法是插在
   第一个字面量的**收尾引号之前**（`'a ' 'b'`）。

### 验证

| 项 | 结果 |
| --- | --- |
| `as_client.py errors .`（**Dart 3.12.2 分析器 = CI 同源**） | 359 文件 **0 条** |
| `dart format --output=none --set-exit-if-changed .`（Dart 3.12.2） | 363 文件 **0 changed** |
| `dart run tools/arch_check/bin/arch_check.dart` | 分层纪律检查通过 |

反向验证：把 `prefer_initializing_formals` 的放行去掉、或把空白修复改回「插在字面量
之间」，上述扫描立刻分别转红 9 条 / 14 条。

### 仍未做（如实记）

- **本机仍然跑不了测试**：`dart test` / `flutter test` 都要拉子进程，受同一个命名管道
  缺陷阻断。所以这 101 处改动**只有静态证据，没有单测证据** —— `ci.yml` 的 test 矩阵
  是唯一能验证它们的地方。
- **`prefer_initializing_formals` 是放行而非修复**：9 处告警被抑制。要真消掉只能把对应
  字段改公开（扩大公开 API），不该由一条风格规则驱动。
- **`tools/release_check.ps1` 仍在静默空扫**，本次未动。~~打印 `扫描目录：-BuildDir`~~
  ——当时把乱码读成了 `-BuildDir`，实际打印的是变量名 `BuildDir`（`$` 被吃掉）。
  真正的原因与修复见下一节。

## 本次会话（2026-10-02）· 四：合规扫描门禁是**假的**，Release 因此发不出包

### 现象

`lint` 修好之后（见上一节），Release 流水线仍然出不了包。CI run `37029615096`
（tag `v0.1.0-m10-4`）在第 11 步「合规扫描（安装包不含源配置）」失败，而**前面
的 Windows 构建已经成功**：

```
At D:\a\MiStream\MiStream\tools\release_check.ps1:51 char:77
The string is missing the terminator: ".
    + CategoryInfo : ParserError
##[error]Process completed with exit code 1.
```

### 根因：`.ps1` 存成了 UTF-8 **无 BOM**

Windows PowerShell 5.1 的 `-File` 对**没有 BOM** 的脚本按 **ANSI 码页**解码，
不看文件内容。中文被拆成乱码后，乱码还会把紧随其后的 ASCII 字符（`$`、`"`）
一并吃掉——于是同一份文件在不同机器上被改写成**两个不同的程序**：

| 机器 ANSI 码页 | 结果 |
| --- | --- |
| CI runner（CP1252） | 第 51 行收尾引号被吃掉 → `ParserError` → exit 1，Release 挂 |
| 本机（CP936） | 不报错，但 `$files = Get-ChildItem ...` 整段被吞进字符串字面量，`$files` 恒为 null → **扫描 0 个文件后判为通过** |

也就是说：**这条合规门禁在本机一直是假的**，只是没人在意「扫描 0 个文本资源」
这句话。CP936 下双引号总数从 20 变 17，语法却仍然成立，所以它连报错都没有。

定位手法（可复现）：用 .NET 按各码页解码源码，再交给真正的 PowerShell 解析器：

| 码页 | 解析错误 |
| --- | --- |
| CP1252 | **1 个 @51:77**，与 CI 日志逐字一致 |
| CP936 | 0 个（静默失效） |
| UTF-8 | 0 个 |

### 修复

1. 给三个含非 ASCII 的 `.ps1` 加 UTF-8 BOM（`release_check` /
   `build_jvm_runtime` / `build_spider_js_runtime`）。有 BOM 时 PS 5.1 按 UTF-8
   读取，两种码页下行为一致。纯 ASCII 的 `jvm_smoke_test.ps1` 不动。
2. `release_check.ps1` 补一条守卫：**扫到 0 个文本资源直接失败**。真实构建产物里
   至少有 `flutter_assets/FontManifest.json` 与 `NativeAssetsManifest.json`，
   「空集」只可能意味着脚本被改坏、路径写错或匹配规则失效。
3. `tools/arch_check` 新增 **`ps1-bom`** 规则（含非 ASCII 的 `.ps1`/`.psm1`
   必须带 BOM），进 `melos run check:arch`，CI 与 Release 的 arch 门禁都覆盖它。
4. `docs/10-开发规范.md` §3.1 记入该规则。

### 验证

| 项 | 修复前 | 修复后 |
| --- | --- | --- |
| `powershell -File tools/release_check.ps1 -BuildDir apps/mistream/build` | `扫描目录：BuildDir` / `扫描 0 个文本资源` / exit 0 | `扫描目录：apps/mistream/build` / `扫描 10 个文本资源` / exit 0 |

反向用例（`-BuildDir` 指向夹具）：

| 用例 | 结果 |
| --- | --- |
| 含 `api.php` 的目录 | exit 1，准确报出 `leak.json:api\.php` |
| 无文本资源的目录 | exit 1，新守卫触发 |
| 不存在的目录 | exit 1 |

其余证据：

| 项 | 结果 |
| --- | --- |
| .NET 按 PS 5.1 实际路径复核 `release_check.ps1` | 有 BOM（按 UTF-8 读）**errors=0**；对照「仍按 CP1252 读」**errors=2** |
| `dart run tools/arch_check/bin/arch_check.dart` | 分层纪律检查通过 |
| 反向：临时去掉 `build_spider_js_runtime.ps1` 的 BOM | `[ps1-bom]` 报错，exit 1 |
| `ps1-bom` 规则用例（进程内脚本，本机 `dart test` 起不了子进程） | **9 项通过 0 失败** |
| `dart format --output=none --set-exit-if-changed .`（Dart 3.12.2） | 363 文件 **0 changed** |
| `as_client.py errors .`（Dart 3.12.2） | 359 文件 **0 条** |

### 顺带确认的两件事

- **101 处 lint 修复没有回归**。改动前（`52a3d63`）与改动后（`5f9577f`）的
  ubuntu test 失败用例逐条比对：`63 passed, 7 failed` / `120 passed, 8 failed`
  完全一致，且改动后**少了**一条 `sync_frame_io_test.dart` 的耗时型用例（本次自然
  通过）。`test` 三平台的红全是环境依赖（Chromium 沙箱、runner 无 Edge/Chrome、
  真子进程/TCP），与本次改动无关，且该分支**历来每一次 CI 都是红的**。
- **CI 的 `release-windows` 作业是好的**：它产出了 artifact
  `mistream-windows-release`（38.2 MB），包内 `mistream.exe` + `data/app.so` +
  `libmpv-2.dll` + `spider_js_runtime.exe` + quickjs/sqlite3 共 29 项，文本资源
  只有两个 manifest。**所以「拿不到可实测的 Windows 包」从来不是构建的问题，
  是合规门禁把发布那一步挡住了。**
  另注：`spider_jvm_runtime.jar` 不在包里——`app_assembly.dart` 按仓库相对路径找
  它，打包分发时 JVM 类 `csp_` 站点会走「JVM 运行时未配置」的降级分支（已文档化，
  非静默缺陷）。

### 结果：发布链第一次跑通

| run | 结果 |
| --- | --- |
| CI `37032054665`（`28ed23b`） | `lint` / `arch` / `commitlint` / `build-check(macos,windows)` / `release-windows` **全绿** |
| **Release `37032078549`（tag `v0.1.0-m10-5`）** | **success**，13 步全部通过，含第 11 步合规扫描与第 13 步创建草稿 Release |

产出：**草稿 Release `v0.1.0-m10-5`**，asset `mistream-v0.1.0-m10-5-windows-x64.zip`
（38.4 MB，sha256 `0c69c5d2…`）。包内 29 个文件，`mistream.exe`(91 KB 薄启动器) +
`data/app.so`(8.8 MB) + `libmpv-2.dll`(29.7 MB) + `spider_js_runtime.exe`(8.1 MB) +
quickjs/sqlite3/flutter_windows.dll 等；文本资源只有 `FontManifest.json` 与
`NativeAssetsManifest.json` 两个，**不含源配置**。

### 治本：`melos run generate` 改走 workspace 模式（已完成）

原脚本配 `packageFilters: dependsOn: build_runner`，melos 会 cd 进 `packages/storage`
跑一次**单包构建**，在 pub workspace 下写 0 个输出。改成
`dart run build_runner build --workspace` 并**去掉 packageFilters**（没有它 melos 才在
仓库根执行），顺手删掉已被 build_runner 2.15 移除的 `--delete-conflicting-outputs`。

CI 实测（run `37033530708`）：

```
melos run generate
  └> dart run build_runner build --workspace
  Built with build_runner/aot in 35s; wrote 55 outputs.     ← 原来是 0
```

随后 `format:check` 363 文件 0 changed、`analyze` `No issues found!`。

于是回退 `.gitignore` 的例外并把 `database.g.dart` 移出版本控制（`git rm --cached`），
**ADR-008「drift 产物不提交」至此才真正成立**。`ci.yml` 的生成步骤保留
`test -f packages/storage/lib/src/database/database.g.dart` 断言 —— 它拦的正是
「生成器静默写 0 个输出」这个当初没人发现的故障模式。

### 仍未做（如实记）

- `test` 三平台仍然红，且**历来每一次都红**：环境依赖（Chromium 沙箱、runner 无
  Edge/Chrome、真子进程/TCP）。`build-check（linux）` 红是因为 runner 缺
  `libasound2-dev`（`volume_controller` 的 Linux CMake 报 `Could NOT find ALSA`）。
  两者都与本次改动无关，但都是**真问题**，未处理。
- 合规规则只有 `spider` / `api.php` / `vod_pic` 三条，未做 license 扫描与体积门禁
  （`ci.yml` 末尾的 TODO(M10)）。
- 草稿 Release 是 `draft: true`，未发布；`v0.1.0-m10-1/2/3/4` 四个 tag 指向的是失败
  的流水线（其中 2/3/4 的包其实构建成功了，只是被门禁挡住）。
- `spider_jvm_runtime.jar` 不进包：`app_assembly.dart` 按仓库相对路径找它，分发场景
  下 JVM 类 `csp_` 站点会走「JVM 运行时未配置」的降级分支。

## 本次会话（2026-10-02）· 五：三平台 `test` 与 Linux 构建的红，逐条拆掉

### 现象与归类

`test` 三个平台历来每一次都红，`build-check（linux）` 也红。按平台分别统计失败集
（`❌ test/...`），**平台分布本身就是根因线索**：

| 平台 | 失败数 | 归类 |
| --- | --- | --- |
| windows | 8 | `host_soak` 4 + `real_process_host` 4 |
| macos | 12 | 上面 8 + `kernel_locator` 4 |
| ubuntu | 16 | 上面 12 + `kernel_process` 3 + `sync_frame_io` 1 |

四类根因，**前两类与被测代码无关**。

### 一、`Platform.script` 在 `dart test` 下不是源码路径（8 条 × 3 平台）

`dart test` 会把测试**预编译**成 `<tmp>/dart_test.kernel.<hash>/xxx_test.dart`，于是
`Platform.script.resolve('support/rpc_child.dart')` 必然落空：

```
Could not find file `C:\Users\RUNNER~1\AppData\Local\Temp\dart_test.kernel.e3f2c572\support\rpc_child.dart`
Invalid argument(s): 桩文件不存在: /tmp/dart_test.kernel.KFQAIQ/support/rpc_child.dart
test/support/child_staging.dart 35:7  stageChildStubs
```

而本地 `dart run test/xxx_test.dart` 下 `Platform.script` 是真实源码路径，**全绿** ——
这个「跑法差异」让 bug 藏了很久。

修复：`packages/spider_host/test/support/child_staging.dart` 新增
`resolveTestSupportFile(name)`，先按 `Platform.script` 旁路找，落空再从
`Directory.current`（`dart test` 的 cwd 就是**包目录**）向上 4 层找
`test/support/<name>`；都找不到抛 `ArgumentError`，并把 `Platform.script` 与 cwd
带进消息。`host_soak_test.dart` 与 `real_process_host_test.dart` 改用它。

### 二、断言把平台写死（4 条 × mac/ubuntu）

`SnifferKernelLocator._candidates()` 是**按平台分叉**的（Windows→edge、macOS→chrome、
Linux→chromium），但 `kernel_locator_test` 的「优先级」组按 Windows 写死了
`msedge.exe` / `C:\Program Files (x86)\...`。**是测试的错，不是定位器的错。**

改为按当前平台断言「命中排第一的那个」；另两条改成只验证行为不变式（跳过不存在的
候选、返回的路径就是通过存在性检查的那一个）。「空白显式路径按未设置处理」去掉了
对 `custom` 的硬断言。

### 三、Ubuntu 23.10+ 的 Chromium 沙箱（3 条，仅 ubuntu）

```
KernelLaunchException: 内核在端点就绪前退出（code=-6）；stderr:
[…FATAL:content/browser/zygote_host/zygote_host_impl_linux.cc:129] No usable sandbox! …]
```

AppArmor 默认禁止非特权 user namespace。`真实内核启动` 组的 `skipReason` 只覆盖
「找不到浏览器」，盖不住「浏览器在、但起不来」。

测试侧**只在 Linux** 追加 `--no-sandbox`（Windows / macOS 沙箱可用，不加，让默认参数
继续被真实覆盖）。

**生产代码刻意没有这个回退**：嗅探内核要渲染不受信任的第三方页面，关沙箱是实打实的
安全降级（Chromium 原文 "if you want to live dangerously"）。Linux 本身要到 **M13**
才支持，所以现在只影响 CI 与将来的移植工作；M13 时必须解决。测试里的
`--no-sandbox` **不能**拿来反推生产可用。

### 四、性能护栏阈值给不出量级余量（1 条，仅 ubuntu）

`sync_frame_io_test` 断言「1MB 逐字节读 <1000ms」，注释写「实测基线 668ms/MB，
阈值留了 50% 余量，只拦量级性退化」—— **只有 1.5 倍却声称拦量级退化，这句自相矛盾
就是线索**。CI 实测 2008ms（3 倍，宿主机调度噪声）。

改为 5000ms（≈7.5 倍基线），注释里写清两次实测值与「先怀疑宿主机、再怀疑代码」。

### 五、`build-check（linux）` 补一个 `libasound2-dev`

`volume_controller/linux/CMakeLists.txt:50` 是 `find_package(ALSA REQUIRED)`：

```
CMake Error: Could NOT find ALSA (missing: ALSA_LIBRARY ALSA_INCLUDE_DIR)
  flutter/ephemeral/.plugin_symlinks/volume_controller/linux/CMakeLists.txt:50 (find_package)
```

`ci.yml` 的「Linux 桌面构建依赖」补上 `libasound2-dev`。已核实**其余 Linux 插件不需要
额外系统库**：`media_kit_video` 找不到 libs 包只打 WARNING 并编译一个 stub 插件
（`MEDIA_KIT_LIBS_NOT_FOUND=1`），`jni` 是 `find_package(JNI COMPONENTS JVM)` 不带
REQUIRED。**别再被 `media_kit: WARNING: package:media_kit_libs_*** not found.` 骗去装 mpv。**

⚠️ `build-check` 变绿**只代表「能编译」**：`apps/mistream/pubspec.yaml` 只声明了
`media_kit_libs_windows_video`，Linux / macOS 的产物里播放器就是那个 stub。这与 ROADMAP
一致（**M13 macOS/Linux 移植**），**不是疏漏**；但也别因为绿了就以为 Linux 版能用。

### 本地验证

| 项 | 结果 |
| --- | --- |
| `dart format`（Dart 3.12.2，全仓） | `363 files (0 changed)` |
| `analyze`（经 `as_client.py` 直连 analysis server，同源） | 4 个改动文件 **0 诊断** |
| `check:arch`（`dart run tools/arch_check/bin/arch_check.dart`） | `分层纪律检查通过` |
| `dart run test/real_process_host_test.dart` | **4/4** |
| `dart run test/host_soak_test.dart` | **4/4** |
| `dart run test/kernel_locator_test.dart` | **15/15** |
| `verify_stub_resolve.dart`（桩路径兜底 3 种情形） | **9/9** |
| 提交信息（复刻 `tools/commit_lint` 规则逐条校验） | 8 条 **0 error** |

> `dart analyze` / `dart test` 本地跑不了（要起分析服务器 / `frontend_server`，撞命名
> 管道缺陷），所以走 `as_client.py` 拿同源诊断。`kernel_process_test` 本地也跑不了
> （要起 msedge）；`flutter test` 同样跑不了（flutter 工具自身要起 `git` / `where`，
> 实测秒崩在 `CreateFile failed 231`）。这两条都属已知缺陷，与改动无关 —— 代价是
> **`apps/mistream` 的 widget 测试改动只能在 CI 上验证**，本地没有实测数字。
> 本次会话中本机管道资源还一度整体耗尽，连 `cmd /c echo` 都起不来。

### 六、`test:flutter` 在 CI 里**从来没跑过** —— `melos run test` 是 `&&` 串联的

修完上面五条后 `test:dart` **整段通过**，`test:flutter` 这才第一次真正执行，立刻
暴露出 `apps/mistream` 的 5 条失败：

```
❌ test/features/player/player_resume_e2e_test.dart: 历史进度在中间时，重开播放页会 seek 到上次位置 (failed)
订阅拉取失败：HTTP 400 · 0 字节（两次 UA 都试过；浏览器 UA 的结果：HTTP 400 · 0 字节）
```

`melos run test` 的定义是：

```
run: melos run test:dart --no-select && melos run test:flutter --no-select
```

`&&` 让 `test:flutter` 在 `test:dart` 失败时**直接跳过**。而 `test:dart` 历来每一次
都红 —— 所以 `apps/mistream`（仓库里唯一的 Flutter 包）的 widget 测试**在 CI 里
一次都没跑过**。这不是「新增失败」，是**长期被掩盖**。

**三层原因**，都在测试侧（一层修掉才露出下一层）：

1. `TestWidgetsFlutterBinding` 初始化时把 `HttpOverrides.global` 换成 mock，此后
   所有 HTTP 一律返回 400（`_binding_io.dart` 的 `setupHttpOverrides`）。本文件的
   受控外部依赖恰恰是本地 `MockSourceServer`，必须放行 → `setUpAll` 里置 null
   （mock 只在 binding 初始化时装一次，而 `testWidgets` 在 `main()` 注册阶段就把
   binding 建好了，置一次即够）。
2. `_init()` 里的取地址要**真发 HTTP**，而 `testWidgets` 默认在 FakeAsync 里跑。
   只 `pump` 假时钟时，socket 的真实完成回调与假 zone 里排队的微任务对不上节奏，
   `_init()` 会一直挂在 `getPlayableSource` 上 → 改成每轮 `runAsync`（真实事件
   循环）+ `pump`（假时钟）交替推进。
3. 放行 HTTP 后暴露出更深的一层：mock 的播放地址是 `https://example.com/ep1.m3u8`，
   而装配用的是 `SnifferResolver(verifyDirectMedia: true)` —— 它会**真去 fetch**，
   404 之后静态嗅探判失败，于是回退到**浏览器嗅探**；widget 测试里起不了真浏览器，
   `getPlayableSource` 因此永不返回，`_init()` 走不到 `open`（第 5 条报
   `Bad state: 必须先 open 一个媒体`，其余报 `Pending timers: Timer 20s`，
   而那个 20s 定时器的创建栈直接指向 `SnifferKernelProcess.launch`）。
   → 给 `AppAssembly` 加 `enableBrowserSniffing`（默认 true，产品行为不变），
   测试里传 false；关掉后 `PlayUseCase` 仍走「直链形态的地址直接交给播放器」
   那条退路，取地址正常返回。

> **教训一**：`melos run a && melos run b` 会让 b 的失败长期不可见。看到某个作业
> 「历来全红」时，先确认它**每一段都真的执行了**，而不是只数失败条数。
>
> **教训二**：真实子进程测试的失败信息里，**pending timer 的创建栈**比断言行本身
> 有用得多 —— 它直接指出「是谁没结束」。这次就是靠它从
> `SnifferKernelProcess.launch` 一路逆推到浏览器嗅探兜底。

### 结果：三平台 `test` 全绿（run `37041217809`，`9c1151f`）

| 作业 | 结果 |
| --- | --- |
| `lint` / `arch` / `commitlint` | **success** |
| `build-check（linux / macos / windows）` | **success**（linux 首次转绿） |
| `release-windows` | **success** |
| **`test（ubuntu / macos / windows）`** | **success**（三平台首次全绿） |

实测数字（三平台一致）：`test:dart` 各包 `6 / 10 / 11 / 12 / 23 / 25 / 26 / 34 / 39 /
52 / 54 / 66 / 69 / 70 / 72 / 90 / 98 / 116 / 128 / 137 / 186` 条通过，其中
`runtimes/sniffer` 是 `220 passed, 64 skipped`；`test:flutter` 段 `137 passed`。
**三平台 `❌` 计数均为 0**。

`player_resume_e2e_test.dart` 的 5 条全部 ✅（含「重开播放页 seek 到上次位置」），
`kernel_process_test.dart` 的 4 条真实内核启动全部 ✅ —— 这两组此前从未在 CI 里
成功执行过。

### 仍未做（如实记）

- 生产侧「Ubuntu 23.10+ 沙箱」未修：涉及安全权衡，需单独决策（见上）。
- `kernel_process_test` 的真实浏览器启动在共享 runner 上**仍可能偶发超时**（同一
  提交两次 CI 里一次三条全绿、一次首条 30s 超时）。已把 `startupTimeout` 放到 60s；
  若仍复发，下一步是「启动失败重试一次」而不是继续加时间。
- 合规规则仍只有 `spider` / `api.php` / `vod_pic` 三条，未做 license 扫描与体积门禁。
- 草稿 Release `v0.1.0-m10-5` 未发布；`spider_jvm_runtime.jar` 仍未进包。

---

## 本次会话（2026-10-04）· 六：把 PR #4 合进 main —— 仓库「停在两个月前」的真相

### 症状

用户看 https://github.com/imzyb/MiStream 时发现仓库像是停在两个月前。诊断结论：
**仓库没坏，是默认分支 `main` 自 2026-08-04 起就没再前进过。** M1b–M5 的全部成果
都压在**一个始终没合并的 PR** 里，一行都没进 `main`。

合并前的核对结果：

| 项目 | 值 |
|------|-----|
| `main` HEAD | `afb9166` · `2026-08-04T15:13:37Z` · `feat(player): 落地 PlayerEngine 抽象层与契约测试 (#3)` |
| 仓库 `pushed_at` | `2026-10-02T17:43:09Z` ← 推送是新鲜的 |
| 仓库 `updated_at` | `2026-08-04T15:15:03Z` ← 但默认分支两个月没动 |
| PR #4 | `feat/m1b-media-kit-engine` → `main` · open · 未合并 |
| PR #4 规模 | **234 commits · 456 files · +92,904 / −308** |
| PR #4 可合并性 | `mergeable: True` · `mergeable_state: clean` |

`main` 上那三次 workflow 全是 `pub in /. - Update` 这类**定时任务**，提交 SHA 一直
是 `afb9166` —— 连自动提交都没产生新 SHA，只剩空转。

另有 6 个 dependabot PR 也一直挂着（#1、#5、#6、#8、#9、#10），#7 已关闭未合并。

### 合并

合并前先确认了一件事：`ci.yml` 的 `commitlint` 带
`if: github.event_name == 'pull_request'`，**push 到 main 时会跳过**。所以 GitHub
默认生成的 merge commit 标题（`Merge pull request #4 from ...`）不满足
`^(\w+)(?:\(([^()]*)\))?(!)?: (.*)$` 也**不会**判红。确认后才动手。

- 合并成功，merge commit = **`01b0de4`**，标题 `chore: 合并 M1b–M5 里程碑（PR #4）`
- 合并请求里带了 `sha=03a43c4…`，确保合进去的正是审查过的那个提交
- `git fetch` 后确认 `origin/main` = `01b0de4`，`03a43c4` 已是其祖先，`main` 提交数 4 → 238
- 仓库 `updated_at` 跳到 `2026-10-04T04:17:34Z`，「停滞两个月」的症状消失

### ⚠️ 合并后 main 上的 CI 全红 —— 但**不是代码问题**

run `37176561363`（`01b0de4`）：10 个 job 里 9 个 failure、`commitlint` skipped。

特征：**所有 job 一起红，`started_at` → `completed_at` 只差 2～5 秒，每个 job
`steps: []`、`runner_id: 0`、`runner_name: ""`，日志接口返回 `BlobNotFound`。**
即作业**压根没拿到 runner**。

取 check-run annotations 拿到权威原因：

> The job was not started because recent account payments have failed or your
> spending limit needs to be increased. Please check the 'Billing & plans' section in your settings

私有仓库的 Actions 按分钟计费；额度耗尽 / 付款失败后，**所有**新 run 都会这样秒红。
**修法只有一条**：GitHub → Settings → Billing & plans 补付款方式或提高 spending
limit，然后 **re-run** —— 代码一行都不用动。

> 注意：这条红**不代表** `03a43c4` 上那次 10/10 全绿是假的。那次（run `37042622670`，
> 2026-10-02）runner 正常分配、`test:dart` 各包计数与 `test:flutter` 137 passed 都是
> 真实输出。计费问题是 2026-10-02 17:43 之后才出现的。

### 仍未做（如实记）

- **main 上的 CI 要等用户在 Billing 里修好计费后 re-run 才会绿。** 当前这次红纯属
  计费，与本轮代码改动无关。
- 6 个 dependabot PR 需等 main 前进后 rebase。
- 分支 `feat/m1b-media-kit-engine` 已合并，可删。




