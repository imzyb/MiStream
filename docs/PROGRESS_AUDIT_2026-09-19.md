# MiStream 开发进度审计报告

> 审计日期：2026-09-19
> 审计方式：代码仓库实况核对（git log / 文件扫描 / 测试计数），非文档转录
> 结论摘要：**工程完成度显著高于文档记录，但项目已停滞 28 天，且存在 17 个未提交改动**

---

## 一、核心结论

| 维度 | 结论 |
| --- | --- |
| 代码资产 | 14 个 packages + 4 个 runtimes + 1 个 app，267 个 Dart 源文件，82 个测试文件 |
| 测试规模 | **957 个测试用例**（`test` + `testWidgets` 计数），覆盖 15 个包/运行时 |
| 提交历史 | 115 次提交，跨 2026-08-04 ~ 2026-08-22，共 19 天 |
| 开发节奏 | 8/18 单日 41 次提交为峰值，属高强度冲刺 |
| **停滞状态** | **8/22 后零提交，已停滞 28 天** |
| **未提交改动** | **17 个文件挂在工作区**（含 3 个未跟踪新文件） |
| 文档准确性 | PROGRESS.md 停留在 8/21，**已落后代码实况** |

---

## 二、里程碑实况

### 已验收（✅）

**M0 · 工程奠基 4/4** — melos monorepo、lint/format/hook、commitlint、CI 三平台矩阵、结构化 logger、`Result<T, AppError>` 全部落库。

### 组件落地、出口标准待补（🟢）

**M3 · RPC + Spider 5/6**
- 已落地：分帧模糊测试、子进程退避重启、取消资源释放、SSRF 逃逸拦截（含重定向到私网）、mock 源全流程
- 缺口：真实 type=1 源浏览 —— **阻塞于本机网络环境**（CDN 被墙），非代码问题

**M4 · JS 运行时 4/6**
- 已落地：QuickJS 嵌入、兼容性测试集 100+ 用例、interrupt 死循环中断、Context 级 OOM 限制、带堆栈的 `SCRIPT_RUNTIME_ERROR`
- 缺口：5 个真实 drpy 源全流程（同网络阻塞）、search P50 基准断言（e2e 已通，仅缺断言）

**M5 · 主线 UI 4/7**
- 已落地：聚合搜索源隔离、可读错误码、四态齐全、mock 源端到端集成测试
- 缺口：真实配置从零起播（等真实源）、关闭重开续播端到端验收（实现已落地）、长跑稳定性验证

### 出口标准为 0，但代码远超文档描述（🟡）

这是本次审计最重要的发现。**PROGRESS.md 严重低估了这几个里程碑的实际状态**：

| 里程碑 | PROGRESS.md 记载 | 代码实况 |
| --- | --- | --- |
| M1 播放内核 | 未提及 | `player_engine` 包完整：PlayerEngine 抽象、MediaKitEngine、hwdec 降级链、契约测试（`media_kit_engine_contract_test.dart` 等 11 个测试文件 / 121 用例） |
| M2 数据层 | 「缺迁移/备份验证」 | drift schema v1-v3 齐备，7 个测试文件 / 47 用例 |
| M6 嗅探 | 「缺 WebView2 原生集成」 | `media_sniffer` 66 用例（3 文件）；新增 `runtimes/sniffer` **Isolate 嗅探器**（提交 6256300），但 `sniffer.dart` 仅 12 行，仍为占位 |
| M8 下载 | 「`Future.delayed(1s)` 假实现」 | **假实现已被替换**（提交 720dad3「接入真实下载实现」），`Future.delayed` 在 `packages/download/lib/` 已无匹配 |
| M9 插件主题 | 「缺主题引擎」 | 新增独立 **`packages/theme_engine`** 包（提交 b113410「M9 主题与沙箱逃逸」） |
| M10 发布工程 | 「🔴 未启动」 | **已有 `release.yml` + `release_check.ps1`**（提交 d4c323e「M10 发布链草稿」、d17849d「M10 分析门禁全绿」） |

**结论**：M1/M2 的代码实现完全就位，出口标准为 0 是因为这些标准（硬解实测、2 小时长跑、迁移回滚、冷启动性能）**全部需要人工在真实环境验证**，而非需要继续写代码。

---

## 三、提交时间线

```
08-04   3  ███              M0 工程奠基
08-06  11  ███████████      PlayerEngine 抽象
08-07  21  █████████████████████
08-08   1  █
08-11   1  █
08-13  10  ██████████
08-18  41  █████████████████████████████████████████   ← 峰值（UI/UX 五批次）
08-19   4  ████
08-21  15  ███████████████
08-22   8  ████████
08-23 ~ 09-19   0                                          ← 停滞 28 天
```

有效工作日 10 天，平均 11.5 提交/天。

---

## 四、未提交改动分析（17 项）

**已跟踪修改（13）：**

| 文件 | 改动性质 |
| --- | --- |
| `apps/mistream/lib/application/config_install_service.dart` | +57 行，配置安装服务增强 |
| `apps/mistream/lib/features/home/home_page.dart` | +3 行 |
| `apps/mistream/pubspec.yaml` | +2 行依赖 |
| `apps/mistream/test/app_test.dart` | +33 行，兼容 outline/实心图标断言、新增响应式网格测试 |
| `packages/core_config/lib/src/config_decoder.dart` | +66 行，`decodeWithProbe` 探测增强 |
| `packages/core_config/lib/src/config_parser.dart` | +28 行 |
| `packages/core_config/lib/src/config_import_service.dart` | +4 行 |
| `packages/core_config/test/*` | 57 行新测试 |
| `packages/core_domain/lib/src/error/error_code.dart` | +9 行新错误码 |
| `tools/mock_source_server/lib/mock_source_server.dart` | +29 行 |
| `docs/05-Spider引擎.md` | 文档更新 |

**未跟踪新文件（4）：**

| 文件 | 价值 |
| --- | --- |
| `apps/mistream/test/m5_mock_e2e_test.dart` | **M5 垂直验证 e2e**：配置 URL → 导入 → Drift 落库 → 搜索 → 详情 → 播放地址。直接对应 M5 出口标准 |
| `apps/mistream/test/application/config_install_service_test.dart` | 6 用例 |
| `docs/DEVELOPMENT_INDEX.md` | 项目文档索引（8/22 日期） |
| `IDEA.md` | 一句话项目定位 |

**判断**：这批改动是一个**完整的、自洽的功能批次**——核心是配置解析健壮性（`decodeWithProbe` 对 HTML/JPEG/PNG/GIF/BMP 返回 `CONFIG_NOT_JSON`）+ M5 e2e 测试 + 错误码扩充。它不是半成品草稿，而是一个待提交的完整语义单元。

---

## 五、真实缺口清单（排除环境阻塞后）

以下是不依赖网络、纯代码可推进的缺口，按优先级：

### P0 · 立即处理

1. **提交那 17 个改动** —— 这是唯一有数据丢失风险的事项。工作区改动已停摆近一个月，若被误清空即永久丢失
2. **`runtimes/sniffer/lib/sniffer.dart` 仅 12 行** —— M6 出口标准的硬缺口。虽有 Isolate 嗅探器落地，但 WebView2 + CDP 驱动尚未实现
3. **`runtimes/spider_python` 存在但未见构建产物** —— M15 范围，非当前阻塞

### P1 · 门禁

4. **`melos run analyze --fatal-infos` 仍红** —— 727 条 info（以 `public_member_api_docs` 为主）。提交 e644d0e 已「机械修复 220 条并放行该 rule」，但全绿门禁尚未达成
5. **`melos run test` 耗时 > 10 分钟** —— 需并行化/缓存优化

### P2 · 出口标准补齐（纯本地可验证）

6. ~~**M4 search P50 < 3s 基准断言**~~ —— **复核实为已完成**：`packages/search_engine/test/search_p50_test.dart` 已在提交 9788722 落库，实测 P50=30ms / P95=32ms。PROGRESS.md 未同步，属文档滞后而非代码缺口
7. **M5 关闭重开续播端到端验收** —— 实现已落地（`router.dart` 读历史 seek + 每 5s/dispose 落库），只差验收测试
8. **M2 迁移回滚测试** —— schema v1-v3 已就位，缺 v1→v2 示例迁移测试 + 模拟失败回滚
9. **M9 主题对比度自动化测试** —— `theme_engine` 包已建，未覆盖 WCAG AA 断言

### P3 · 需要真实环境（非代码工作）

10. 真实 type=1 源浏览（M3）、5 个真实 drpy 源（M4）、真实配置从零起播（M5）、M1 硬解实测与 2 小时长跑、M6 真实 type=0 源嗅探

---

## 六、文档健康度问题

1. **PROGRESS.md 停留在 8/21**，未反映 8/22 及工作区改动
2. **PROGRESS.md 低估了 M1/M2/M6/M8/M9/M10**，与代码实况偏差较大——报告口径是「出口标准」驱动，但读者容易误读为「代码未实现」
3. **`docs/DEVELOPMENT_INDEX.md` 内容有瑕疵**：
   - 目录结构图首行 `I:\Cloudflare\mistream├── apps/` 结构标记拼接错误
   - 「必须遵守的开发纪律」出现两个「### 3.」编号（UI 规范应为 4）
   - 完成状态表遗漏 M6/M7/M8/M9，且 M10 标注「未开始」与实际的 release.yml 存在矛盾
4. **文档最后更新日期 8/22** —— 与项目停滞起点一致

---

## 七、仓库状态异常（本次审计额外发现）

准备提交工作区改动时，发现本地仓库处于一个**危险状态**：

- `feat/m1b-media-kit-engine` 分支的**本地引用不存在**（无任何提交），
  而 `origin/feat/m1b-media-kit-engine` 上有完整的 115 次提交历史
- 工作区代码基线**实际就是** origin 上的 `7315185`，只差那批未提交改动
- 后果：任何 `git add . && git commit` 都会在本地产出一个**没有历史的
  孤儿提交**，把 115 次提交的演进史从本地分支上抹掉（origin 尚存，可恢复）

处理：将本地分支引用重新指向 `origin/feat/m1b-media-kit-engine`，
并用 `git read-tree HEAD` 重建索引，工作区文件零改动。

### 7.1 提交后引用丢失 —— 根因已定位

**现象**：每次 `git commit` 之后，`.git/refs/heads/feat/` 整个目录被删除。
下一次 git 命令报 `your current branch 'X' does not have any commits yet`；
此时若继续提交，git 会走 `initial commit` 路径，产生**父提交为空的孤儿提交**，
从而丢失整条历史链（reflog 中可见 `0000... -> <hash> commit (initial)`）。

**排除项（均经实测验证）**：

| 假设 | 验证方式 | 结论 |
| --- | --- | --- |
| `.githooks` 钩子所为 | `git commit --no-verify` 跳过全部钩子 | 仍复现，**排除** |
| `pre-commit` 的 `git diff` 报「命令行太长」 | 单独运行 `.githooks/pre-commit`，退出码 0，引用完好 | **排除** |
| 外部进程定时清理 | 重建引用后静置 20 秒，引用稳定存在 | **排除** |
| `core.logAllRefUpdates=false` | 实测为 `true` | **排除** |
| 旧式 loose ref 不受支持 | `.git/refs/heads/main`（8/4 老文件）始终完好 | **排除** |

**定位结论**：删除发生在 `git commit` 进程的**退出清理阶段**，且只影响
**本次操作新建的**引用目录（`feat/` 为新建，`main` 为既有文件故不受影响）。
根因指向 I: 盘的虚拟化文件系统语义 —— `df` 显示挂载参数为
`ntfs (binary,noacl,posix=0,...)`，inode 号为 `5629499534720xx`
（非本地 NTFS 正常范围），目录句柄在跨进程切换时的刷新行为与 git 的
`refs` 目录清理策略冲突。这是**环境/文件系统问题，不是仓库配置问题**。

**应对**：已新增 `tools/git_ref_guard.sh`，每次提交后执行一次即可从 reflog
自动恢复引用，并规避孤儿提交风险（回溯到第一个 `old` 非零的 reflog 记录）：

```bash
sh tools/git_ref_guard.sh
```

> 提交后务必用 `git log --oneline -3` 与 `git status -sb` 双重确认。
> 若报「分支无提交」，**先跑守卫脚本再继续任何操作**，切勿直接 commit。

---

## 八、建议行动顺序

```
第一步（已完成）
  └─ 修复本地分支引用 + 提交 18 项改动，按语义拆 5 个 commit
     · chore: gitignore 补 .workbuddy-ai 与 .flutter_tool_state
     · feat(config): decodeWithProbe 探测 + CONFIG_NOT_JSON
     · fix(config): 中文域名 Punycode + 浏览器 UA
     · fix(ui): 首页分类网格 shrinkWrap + M5 垂直集成测试
     · docs: 开发索引与审计报告

第二步（1 小时）
  └─ M5 续播验收测试
     → 可再勾掉 1 条出口标准，M5 达 5/7

第三步（半天）
  └─ 补 M2 迁移回滚测试 + M9 主题对比度测试

第四步（需决策）
  └─ 网络方案：代理 / 可访问机器 / mock 源扩充
     → 所有「真实源」类出口标准都卡在这里
```

---

## 九、审计备注

- 本报告的所有数字均来自 `git log`、文件系统扫描与 `grep` 计数，未经文档转录
- 测试用例数 957 为 `test(` / `testWidgets(` 出现次数，含 `group` 不计；实际运行时用例数可能因参数化略有差异
- 「停滞 28 天」指 2026-08-22 至 2026-09-19 无提交，不含未提交的工作区改动

### 实测更正（本会话复核）

初版报告引用了文档中的「`spider_host` 99/99 全绿」等说法，**未实测**。实际
运行后发现该包有一批用例依赖本地 HTTP 回环连接（`HttpRuntime` 系列），在本
沙箱内因「目标计算机积极拒绝」而失败（6 例）。这些用例自建 mock server 绑定
`loopbackIPv4`，失败属环境限制，**与本会话改动无关**（已用 `git show` 比对确认
测试文件未被触及）。

本会话实测通过的规模：**445 用例全绿**（1 跳过），覆盖
`player_engine 142`、`spider_js 164`、`core_domain 42`、`storage 47`、
`core_logging 39`、`search_engine 30`、`core_config 23`、`download 22`、
`plugin_host 19`、`live 17`、`media_sniffer 66`、`theme_engine 5`、
`source_adapter 11`、`play_engine 6`、`resume_policy 15` 等。

### 全量基线（逐包实测，最终口径）

对 24 个 workspace 包逐个执行 `dart test`，结果为
**795 通过 / 10 失败 / 37 跳过**。10 个失败**全部**归因于沙箱环境，无代码回归：

| 包 | 通过 | 失败 | 失败原因 |
| --- | --- | --- | --- |
| `spider_host` | 93 | 6 | 自建 mock server 需绑定回环端口，沙箱拒绝（`os error 10061`） |
| `spider_js` | 122 | 4 | **测试运行目录不对**，见下方更正 |

其余 22 个包**全部通过**，包括 `player_engine 142`、`media_sniffer 66`、
`storage 47`、`core_domain 42`、`core_logging 39`、`search_engine 30`、
`core_config 23`、`commit_lint 23`、`download 22`、`plugin_host 19`、
`live 17`、`arch_check 15`、`mock_source_server 12`、`source_adapter 11`、
`quickjs_dist 11`、`libmpv_dist 10`、`play_engine 6`、`theme_engine 5`、
`mistream app 若干`。

> 教训：本报告第一版对「测试全绿」的判断部分来自文档而非实测。后续审计
> 应默认实测，文档只作交叉参考。

### 重要更正：测试必须从**包目录**运行

上面 `spider_js` 的 4 个「失败」与大量「跳过」是**误判**，根因不在环境而在
运行目录。`dart test runtimes/spider_js`（从仓库根）与
`cd runtimes/spider_js && dart test`（从包目录）结果完全不同：

| 运行方式 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- |
| 从仓库根（错误） | 146 | 4 | 38 |
| 从包目录（正确） | **180** | **0** | 10 |

原因是测试夹具用相对路径（如 `Directory('test/compat')`）定位，从仓库根运行
时 cwd 不含该目录，用例直接抛 `Directory listing failed`。同时 native 库
（QuickJS DLL）也依赖 cwd 解析，导致本可运行的 JS 集成测试被当成「跳过」。

**结论：QuickJS native 在本机是可用的**（此前记录为「不可用」属误判）。
后续凡涉及 `spider_js`／`spider_host` 等含夹具或 native 依赖的包，**必须
cd 进包目录再跑**，或用 `melos exec`（它天然以包目录为 cwd）。


### 静态检查实测（更正 P1）

初版报告依据 PROGRESS.md 记录称「`melos run analyze --fatal-infos` 仍显示
727 条 info」。**实测结果为 0 条**：

- `flutter analyze --no-pub --fatal-infos --fatal-warnings` → `No issues found!`
- 24 个 workspace 包逐包分析 → **全部 `No issues found!`**
- 验证方式：在 `packages/core_domain` 临时注入 `avoid_print` +
  `prefer_const_declarations` 探针，根目录分析**成功捕获**
  （说明 workspace 递归分析有效，门禁并非形同虚设），随后清除

`analysis_options.yaml` 中的注释已说明：727 条既有债通过逐条 `ignore`
放行处理（`public_member_api_docs` 占 380 条），**该项已收口**。
PROGRESS.md 的 P1 记录滞后，应从待办中移除或改标为「已完成」。


### 本地环境限制清单

- `flutter test` 需显式注入 `ProgramFiles(x86)` 环境变量，本机缺失，否则工具链静默中断
- widget 测试在本沙箱内 `flutter_tester` 连不上（`WebSocketException: Invalid
  WebSocket upgrade request`），只能跑 `dart test`
- `dart test` 无法加载 Flutter SDK 内部源码（`flutter_test` 相关导入会编译失败），
  故 app 级 widget 测试与触库测试均无法在沙箱内执行
- 沙箱禁止本地端口回环连接，`spider_host/test/http_runtime_test.dart` 等
  自建 mock server 的用例无法运行
- **含夹具或 native 依赖的包，测试必须 `cd` 进包目录再跑**（见上方「重要更正」）；
  从仓库根运行会因 cwd 不对而误报失败/跳过
- 提交含中文路径时 `git commit` 会因命令行超长失败，须用 `--pathspec-from-file` 传路径
- **`git commit` 后分支引用文件会被删除**（I: 盘虚拟化文件系统语义所致）；
  提交后须执行 `sh tools/git_ref_guard.sh` 恢复，否则下次提交会产生孤儿提交
- commitlint 的 scope 白名单：`ci config deps domain logging player plugin rpc
  sdk sniffer spider spider-js storage theme tools ui updater`

