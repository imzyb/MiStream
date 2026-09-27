# MiStream 主链路代码审查报告

> 审查日期：2026-09-27
> 审查范围：**添加接口源 → 选择播放源 → 选择/搜索影片 → 播放影片** 端到端主链路
> 审查方式：逐文件通读调用链源码，逐条核实行号与行为；**本次为只读审查，未改动任何代码**
> 结论摘要：主链路设计完整、降级链齐备，但有 **1 个 P0 资源泄漏** 与 **1 个 P1 功能误判**，另有 9 处一致性问题

---

## 修复状态（2026-09-27，四轮修复后）

| 项 | 状态 | 说明 |
| --- | --- | --- |
| P0 · `PlayUseCase` runtime 回收 | ✅ | 摘掉回收 → 新增 5 例中 4 例变红 |
| P1 · `_resolveJavaPath` 补 PATH 回退 | ✅ | 摘掉回退 → 新增 8 例中 3 例变红 |
| P2-1 · `parseDetail` 注释 | ✅ | 纯文档 |
| P2-2 · 搜索层选源 | ✅ | 详情页新增「片源」切换（`replaceNamed` + `didUpdateWidget`）；顺带把一直**声明未使用**的 `DetailPage.item` 真正用起来 |
| P3-1 · 引导页三处 | ✅ | ①错误不再在重试前显示，图片类也不再白跑第二次请求 ②HTML 判定改用 `ConfigDecoder.probeNonJson`（并补 6 例直接单测，此前只有间接覆盖）③Base64 新增可选「配置来源地址」 |
| P3-2 · 剧集越界 / `episodeId` 约定 | ✅ | 抽出 `EpisodeIndex` 值对象统一「第几集」的编解码；越界改为明确报 `notFound`，**不再回退第 1 集**；`PlayResult` 回填实际集号；历史落库 `episodeIndex` 且续播前比对集号。新增 14 例值对象 + 7 例播放端 + 3 例详情端单测，三处反向验证均生效 |
| P3-5 · 剧集序号在生成端与消费端**不一致**（本轮修复中发现） | ✅ | 详情端原用「非空剧集计数」生成 id、播放端用 `split('#')` 下标，源里出现空段（`第1集$u1##第4集$u4`）即整体错位。现两端共用真实下标；摘掉 → 详情用例变红 |
| P3-6 · 历史/收藏的播放入口（本轮修复中发现） | ✅ | `_playHistory`/`_playFavorite` 原 push `detail` 而 extra 用播放路由的键名 → 整个 extra 被丢弃，「继续播放」只打开详情页；`history.flag`（线路名）被当集号传；`episodeIndex` 从未落库。现历史改走 `player`、收藏走 `detail`，并落库集号 |
| P2-3 · `_CategoryDetailPage` 全局装配 | ⏳ | 见 `PROGRESS.md` 下一步第 9 条 |
| P3-3 · 选源口径不一致 | ⏳ | 同上 |
| P3-4 · 搜索网格全量重建 | ✅ | 引擎侧补 `SearchItem.identityKey`（合并去重键，天然唯一），UI 侧卡片带 `ValueKey` + 网格透传 `findChildIndexCallback` —— **只加 key 不够**，sliver 得靠该回调才能按 key 找到旧元素。顺带修正 `sources` 未按优先级排序（`sources.first` 原为「最先命中的源」，由并发顺序决定）。摘掉任一处 → **各 1 例变红** |

P3-5 / P3-6 是本轮修复 P3-2 时新查出来的：它们不在原审查清单里，但同属「播放段
边界」——**同一个约定写两遍**（P3-5）与**入口把参数传给了不认识它的路由**（P3-6）。
两者的共同点是**不报错**：错位表现为「播放地址为空」，跳错路由表现为「打开了详情页
但没起播」，都不会在日志里留下异常。

下方各节保留审查当时的原始记录，未随修复回改。

---

## 一、链路总览

```
① 接入   OnboardingPage / SettingsPage
        → ConfigInstallService.installFromUrl
        → ConfigFetcher（okhttp UA → 浏览器 UA）
        → ConfigImportService.import → sites / configSources 落库

② 选源   HomePage._showSourcePicker ← HomeUseCase.listSources（SourceOption.isUsable）
        → _switchSource → getHomeData（HTTP 源优先 + 30s 探测预算）
        → HomeUseCase.workingSiteId

③ 选片   首页/分类网格 → _navigateToDetail（带 workingSiteId）
        → /detail/:siteId/:vodId → DetailUseCase.load → parseDetail（线路 + 剧集）
        搜索：SearchPage → SearchUseCase.search（8 并发、流式、normalizeTitle 合并）

④ 播放   DetailPage._playEpisode → /player/:siteId/:vodId/:flag
        → PlayerPageWrapper._init → PlayUseCase.getPlayableSource
        → runtime.detail → _extractCandidates（$$$ 线路 / # 剧集）
        → SnifferResolver（静态）→ browserSniffer（CDP）→ 直链兜底
        → MediaKitEngine.open → PlayerController.attach（续播 / 进度 / 起播看门狗）
```

整体判断：**结构是健康的**。四段都有明确的失败降级路径，且降级链在代码里是真实现的，不是注释里的愿景：

- 接入段两级 UA 重试 + 重定向链诊断；
- 选源段 HTTP 源优先、逐个探测、30s 总预算；
- 选片段多源合并去重、详情页线路优先级猜测；
- 播放段两级嗅探（静态 → CDP）+ 直链兜底 + 起播看门狗。

问题集中在**资源回收、环境探测、以及同一件事被实现了两遍**这三类。

---

## 二、逐段结论

### ① 添加接口源

| 项目 | 结论 |
| --- | --- |
| 正常路径 | ✅ URL / Base64 / 剪贴板三种方式齐全；`okhttp` UA 失败自动退浏览器 UA；重定向链（含 JS 重定向 `window.location.*`）有专门处理 |
| 降级路径 | ✅ 拿到 HTML 时会尝试从 `data-clipboard-text` 里提候选配置链接并弹选择框 |
| 缺陷 | ⚠️ 引导页自建了一整套 HTTP 拉取 + URL 规范化，与 `core_config` 的 `ConfigFetcher` / `normalizeConfigUrl` 功能重复；HTML 判定弱于 `ConfigDecoder.probeNonJson`；无候选链接时会**重复报错并多发一次请求**；Base64 导入**丢失 `sourceUrl`** |

### ② 选择播放源

| 项目 | 结论 |
| --- | --- |
| 正常路径 | ✅ `listSources` 列出全部启用站点；`_getEnabledSites` 用 `classifySiteRuntime` 预筛掉缺运行时的源，HTTP 类优先，避免 105 个 `csp_` 站点把探测预算烧光 |
| 降级路径 | ✅ 逐个站点试到第一个成功；失败时汇总前 3 个站点的真实错误，不是笼统的「全部失败」 |
| 缺陷 | 🔴 **`_resolveJavaPath` 只查 `JAVA_HOME`**，导致 `csp_` 站点在未设该环境变量的机器上被整体误判为「无运行时」 |

### ③ 选择 / 搜索影片

| 项目 | 结论 |
| --- | --- |
| 正常路径 | ✅ 详情页 `parseDetail` 只留「名称 + 序号」而不缓存地址，避免与播放段二次解析结果不一致——这个设计是对的，注释也解释清楚了动机 |
| 降级路径 | ✅ 搜索 8 并发 + 单源 8s 超时 + 逐源状态回显；标题归一化（去括号后缀、全角转半角）跨源合并 |
| 缺陷 | ⚠️ `parseDetail` 文档注释与实现不符（`##` vs `#`）；搜索层只取 `sources.first`，用户无法在搜索页选源；`_items` 每次进度全量 `clear + addAll` 导致网格闪动 |

### ④ 播放影片

| 项目 | 结论 |
| --- | --- |
| 正常路径 | ✅ 两级嗅探分工明确（静态便宜、CDP 贵但能看到 JS 生成的地址），只在静态失败时才起浏览器 |
| 降级路径 | ✅ 三级：静态嗅探 → 浏览器兜底 → 直链碰运气；全失败才报错，且错误码能区分「页面打不开」与「页面里没地址」 |
| 缺陷 | 🔴 **创建的 runtime 从不 `dispose()`**，每次播放泄漏一个 JS / JVM 子进程 |

---

## 三、缺陷清单

### P0 · `PlayUseCase` 泄漏运行时子进程

**位置**：`packages/search_engine/lib/src/play_use_case.dart:108`

```dart
final runtime = await _createRuntime(site);
final detailResult = await runtime.detail(ids: vodId);
// …整个方法直到 return 都没有 runtime.dispose()
```

**证据**：`play_use_case.dart` 全文没有任何 `dispose` 调用。而同项目其它三处创建 runtime 的地方**全都回收了**：

| 位置 | 回收方式 |
| --- | --- |
| `apps/mistream/lib/application/detail_use_case.dart:159-165` | `finally { await runtime.dispose(); }` |
| `packages/search_engine/lib/src/home_use_case.dart:211 / 218 / 239 / 245` | 成功与异常两条路径都 dispose |
| `apps/mistream/lib/application/app_assembly.dart:246-248`（`_LazySearcher`） | `finally { await runtime.dispose(); }` |

**影响**：`PlayUseCase.getPlayableSource` 由 `PlayerPageWrapper._init`（`apps/mistream/lib/app/router.dart:329`）在**每次进入播放页时调用一次**。`type=3` 站点的 runtime 背后是 JS 子进程（`runtimes/spider_js`）或 JVM 子进程，因此**每播一集就多一个常驻子进程**，连播一季会累积几十个。表现是内存与句柄持续上涨，退出播放页也不会释放。

**修法**：把 `runtime.detail` 调用包进 `try { … } finally { await runtime.dispose(); }`。注意 `detailResult` 的 `body` 是字符串，dispose 之后仍可继续用于 `_extractCandidates`，回收点放在提取候选**之后**或**之前**都安全——但放在 `finally` 里最省心。

---

### P1 · `csp_` 站点在未设 `JAVA_HOME` 的机器上被整体误判

**位置**：`apps/mistream/lib/application/app_assembly.dart:170-181`

```dart
/// 定位 java 可执行文件：JAVA_HOME 优先，fallback 到 PATH 里的 `java`。
static String? _resolveJavaPath() {
  final javaHome = Platform.environment['JAVA_HOME'];
  if (javaHome != null && javaHome.isNotEmpty) {
    final candidate = File('$javaHome${sep}bin${sep}java.exe');
    if (candidate.existsSync()) return candidate.path;
  }
  return null;          // ← 注释承诺的 PATH fallback 不存在
}
```

**传导链**（已逐级核实）：

1. `_resolveJvmConfig()`（`:143-168`）在 `javaPath == null` 时返回 `null`；
2. `SpiderRuntimeFactory` 持有 `jvm` 字段，`supports()`（`packages/spider_host/lib/src/runtime/spider_runtime_factory.dart:532-541`）对 `SiteRuntimeKind.jvm` 返回 **`jvm != null`**；
3. `HomeUseCase._siteHasRuntime()`（`home_use_case.dart:143-147`）把 `supports()` 的结果写进 `SourceOption.hasRuntime`；
4. `SourceOption.isUsable => hasRuntime`，首页片源选择器据此**灰显并禁用**该源（`home_page.dart:198 / 218`），`_getEnabledSites()` 也据此把它从探测列表里剔除。

**影响**：`JAVA_HOME` 未设置但 `java` 在 `PATH` 里，是 Windows 上**极常见的**安装形态（尤其用 winget / scoop / 绿色版 JDK）。这类机器上，配置里所有 `csp_` 站点会在片源列表里显示「暂不支持」且无法点击，首页探测也直接跳过——而它们其实完全可用。项目记忆里也记着「实测某真实配置 105 个站点全是 `csp_`」，即这会让**整份配置看起来完全不可用**。

**修法**：`JAVA_HOME` 未命中时，遍历 `PATH` 找 `java.exe`（`Platform.environment['PATH']` 按 `;` 切分，逐个 `File('$dir/java.exe').existsSync()`）；再退一步可以尝试常见安装位置。注释已经写明了意图，实现补齐即可。

---

### P2 · 一致性缺陷（不影响功能，但会误导后续维护）

#### P2-1 `parseDetail` 文档注释与实现不符

- `apps/mistream/lib/application/detail_use_case.dart:198` 注释：**「各线路的剧集列表以 `##` 分隔」**
- 同文件 `:224` 实现：`urlStr.split('#')`
- 同文件 `:219` 行内注释又正确写着「`#` 分隔剧集」

**代码是对的**（TVBox / Apple CMS v2 的 `vod_play_url` 就是 `#` 分隔剧集），错的是方法级文档注释。这类不一致的危险在于：后来者按注释「修正」代码，就会把 `##` 引入解析，存量源全部解析出空剧集名。

**修法**：把 `:198` 的 `##` 改成 `#`。

#### P2-2 搜索层无法选择片源

- `apps/mistream/lib/features/search/search_page.dart:202-215`

```dart
void _goDetail(SearchItem item) {
  if (item.sources.isEmpty) return;
  final source = item.sources.first;      // ← 只取第一个
  …
}
```

`SearchItem.sources` 明明承载了同一部片在多个源上的匹配结果（`_MergedEntry.addSource` 累积，按 `maxPriority` 排序），但跳转时只用了第一个。详情页有「线路」`ChoiceChip`（`detail_page.dart`），但**线路 ≠ 片源**：用户看到的第一源可能只有抢先版，而第三源有高清，却无从切换。

**修法**：详情页增加「片源」切换（`SearchItem.sources` 已随 `extra` 传入 `:212`，数据是现成的），或跳转前弹一个源选择框。

#### P2-3 `_CategoryDetailPage` 用全局装配而非注入

- `apps/mistream/lib/app/router.dart:614` 与 `:649` 直接用 `globalRouterAssembly`

对比：`DetailPage` / `SearchPage` 都走 `AppScope.of(context)` 注入。全局可变单例（`setRouterAssembly` 写入，见 `:32-39`）在「同时存在两个装配实例」的场景（测试、多窗口）下会静默取错对象。

**补充**：这一处**功能上是正确的**——`_CategoryDetailPage` 收到的 `siteId` 来自 `HomePage._navigateToCategoryDetail`（`home_page.dart:154-165`）传入的 `_currentSite?.id`，而 `_currentSite` 在 `_loadData` 里已被更新为 `workingSiteId`（`home_page.dart:91-96`），所以它推详情时用的确实是「实际取数成功的站点」。**只是达成方式脆弱**：正确性依赖 `_currentSite` 与 `workingSiteId` 的隐式同步，而不是显式传参。

---

### P3 · 引导页的重复实现与体验缺陷

`apps/mistream/lib/features/onboarding/onboarding_page.dart` 自建了一套 HTTP 拉取（`:74 _fetchWithRedirects`）与 URL 规范化（`:353-377 _normalizeUrl`），而 `core_config` 里已经有 `ConfigFetcher`（`packages/core_config/lib/src/config_fetch.dart`，含手动跟随重定向、成环检测、`maxBytes` 限制、`ConfigFetchDiagnostics`）与 `ConfigInstallService.normalizeConfigUrl`。三处具体问题：

1. **重复报错 + 多发一次请求**（`:56-59` 与 `:110-117`）
   `_importWithUserAgent` 在「HTML 里提不出候选链接」时，**先 `setState` 把错误显示出去**，然后 `return _ImportAttempt.notConfig`；`_importFromUrl` 收到 `notConfig` 会**再用浏览器 UA 重试一次**，走同一个分支再 `setState` 一次错误。用户看到错误文案闪动，且白白多发一次网络请求。契约上 `notConfig` 应该表示「已给出明确错误」还是「值得重试」在这里是自相矛盾的——`:628-629` 的枚举注释把两者混在一个值里了。

2. **HTML 判定偏弱**（`:95-101`）
   只解码前 200 字节做 `startsWith('<!DOCTYPE')` / `'<html'` 判断。`ConfigDecoder.probeNonJson` 的判断更完整，这里等于又实现了一份更弱的版本。

3. **Base64 导入丢失 `sourceUrl`**（`:393`）
   `_importFromBase64` 调用 `_processImport(bytes)`，**不传 `sourceUrl`**；而 URL 导入路径（`:130` / `:141`）是传的。配置里若有**相对路径**的 spider 脚本，从 Base64 导入时会解析失败——同样的配置用 URL 导入却能成功，属于难以排查的不一致。

---

### P3 · 播放段的边界行为

#### P3-1 剧集越界静默回退第一集

`packages/search_engine/lib/src/play_use_case.dart:323-331`

```dart
static String? _episodeUrl(String line, int episodeIndex) {
  final episodes = line.split('#');
  if (episodes.isEmpty) return null;
  var index = episodeIndex;
  if (index < 0 || index >= episodes.length) index = 0;   // ← 静默回退
  …
}
```

用户在详情页点了「第 10 集」，若该线路只有 5 集，会**静默播放第 1 集**，且界面上没有任何提示——用户只会觉得「点了没反应 / 播错了」。回退本身是合理的容错（总比报错强），但至少应把「实际播放的集号」回传给 UI，或在越界时优先换一条集数足够的线路。

#### P3-2 `episodeId` 语义在两处独立实现

- 生成：`detail_use_case.dart:232` → `VodEpisode(id: '${eps.length}')`，即**序号字符串**
- 消费：`play_use_case.dart:276` → `int.tryParse(episodeId ?? '') ?? 0`

两处各自实现「序号」约定，中间靠注释维系。任何一处改动（例如详情页改成缓存地址）都会让播放段**静默退到第 1 集**，且不报错。建议提取共享常量或改成一个显式的 `EpisodeIndex` 值对象。

#### P3-3 片源选择器与 `_getEnabledSites` 口径不一致

- 选择器：只有 `isUsable == true` 的源才可点（`home_page.dart:198 / 218`）
- `_getEnabledSites`：`siteId != null` 时**无条件尊重**用户选择，哪怕缺运行时（`home_use_case.dart:152-156`，注释理由是「点了没反应比报明确的错更难排查」）

两条设计意图都合理，但合在一起，`_getEnabledSites` 的那个分支在首页路径上**不可达**——用户根本点不到不可用的源。要么放开选择器（允许点，点了给明确错误），要么删掉那个分支。目前是两种意图各写了一半。

#### P3-4 搜索结果网格每次进度全量重建

`apps/mistream/lib/features/search/search_page.dart:56-64`

```dart
_items..clear()..addAll(progress.items);
```

`SearchProgress` 每有一个源完成就 emit 一次，每次都全量清空重建。由于 `MediaCard` 无 key，已渲染的卡片会被销毁重建 → **滚动位置跳动、封面图重复解码闪烁**。8 个源意味着搜索过程中闪 8 次。

---

## 四、已排除的疑点（读代码后证伪）

审查中怀疑过、但核实后**不成立**的项，一并记录以免后续重复排查：

| 疑点 | 结论 |
| --- | --- |
| `_CategoryDetailPage` 推详情不带 `extra`，可能与 `workingSiteId` 不一致 | ❌ 不成立。其 `siteId` 来自 `_currentSite?.id`，而该字段已被 `_loadData` 同步为 `workingSiteId`（`home_page.dart:91-96`） |
| `HomePage._navigateToDetail` 在 `workingSiteId == null` 时静默 return | ❌ 不成立。该分支只在 `getHomeData` 整体失败时进入，此时 `_recommends` 为空、无卡片可点 |
| `HomeUseCase._trySites` 可能 double-dispose | ❌ 不成立。`:211` 的 `dispose` 若抛异常会落入 `:217` catch 再 dispose 一次，但 `dispose` 实现均为幂等（`spider_runtime_factory.dart:105` 为空实现） |
| `_extractCandidates` 的 `episodeIndex` 与详情页不一致 | ❌ 语义一致（都是序号），仅缺共享定义，见 P3-2 |
| `SearchUseCase` 并发 worker 存在竞态 | ❌ 不成立。`queue.removeAt(0)` 在 Dart 单线程事件循环下原子（`:139-141` 注释已说明），且 `_LazySearcher` 在 `finally` 里正确回收了 runtime |

---

## 五、建议修复顺序

| 顺序 | 项 | 优先级 | 改动量 | 理由 |
| --- | --- | --- | --- | --- |
| 1 | `PlayUseCase` runtime 回收 | **P0** | ~5 行 | 真实资源泄漏，连播场景必现，改动极小、风险极低 |
| 2 | `_resolveJavaPath` 补 PATH 查找 | **P1** | ~15 行 | 决定整份 `csp_` 配置是否可用，影响面最大 |
| 3 | `parseDetail` 注释修正 | P2 | 1 行 | 纯文档，但错的方向会诱导后续改错代码 |
| 4 | 搜索页片源切换 | P2 | 中 | 数据已就绪（`extra` 带 `SearchItem`），是可用性缺口 |
| 5 | 引导页三处（重复报错 / HTML 判定 / Base64 缺 `sourceUrl`） | P3 | 中 | 其中 Base64 缺 `sourceUrl` 是真实功能缺失，建议单独提 |
| 6 | `episodeId` 越界回传、`_items` 增量更新、选源口径统一 | P3 | 中 | 体验优化，可合并到后续 UI 打磨 |

**建议**：第 1、2 项是明确的缺陷修复，适合立刻单独提交；第 3 项可搭车；第 4–6 项建议进 `PROGRESS.md` 的下一步清单，按 UI 打磨节奏处理。

---

## 六、本次审查的验证手段说明

本机环境限制（详见项目记忆）：`dart analyze` / `dart test` / `flutter test` 因 Dart VM 命名管道缺陷（`CreateFile failed 231`）不可用，`flutter build windows` 因缺 Visual Studio 不可用，widget 测试因 `flutter_tester` WebSocket 失败不可用。

因此本次审查为**纯静态代码审查**：所有结论均来自逐行阅读源码与跨文件交叉验证调用链，每条缺陷都给出了 `文件:行号` 与传导路径，并做了反向核实（第四节）。**未执行任何运行时验证**，也未改动任何代码。
