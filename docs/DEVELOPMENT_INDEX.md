# MiStream 项目开发文档索引

## 文档概览

本项目共包含以下核心文档（按优先级和相关性排序）：

### 1. 项目定位与范围
- [01-项目概述.md](01-项目概述.md)：项目定位、合规边界、成功标准
- [ROADMAP.md](../ROADMAP.md)：交付顺序、里程碑出口标准、依赖图

### 2. 系统架构
- [02-系统架构.md](02-系统架构.md)：分层、进程模型、数据流、ADR
- [03-技术选型.md](03-技术选型.md)：技术栈、自研清单、License、体积预算
- [ADR 索引](adr/README.md)：架构决策记录

### 3. 核心组件
- [04-播放器设计.md](04-播放器设计.md)：PlayerEngine、能力矩阵、硬解、起播编排
- [05-Spider引擎.md](05-Spider引擎.md)：统一接口、四类运行时、沙箱、TVBox 兼容层
- [06-插件系统.md](06-插件系统.md)：Manifest、权限、生命周期、市场
- [07-数据库设计.md](07-数据库设计.md)：表结构、迁移、备份
- [08-RPC协议.md](08-RPC协议.md)：分帧、方法清单、错误码、版本协商

### 4. 开发规范
- [09-UI规范.md](09-UI规范.md)：设计令牌、响应式、页面规范、文案
- [10-开发规范.md](10-开发规范.md)：分支、提交、测试、CI/CD、发布、安全基线
- [11-构建与发布.md](11-构建与发布.md)：本地构建步骤、产物结构、环境坑、发布流水线

### 5. 辅助文档
- [compatibility.md](compatibility.md)：版本兼容矩阵
- [checklists/](checklists/)：发布门禁、播放回归
- [adr/](adr/)：架构决策记录模板

## 目录结构

```
I:\Cloudflare\mistream_new
├── apps/                # 主应用层
│   └── mistream/        # Flutter Desktop 主应用
│       ├── lib/         # 业务逻辑层
│       └── test/        # 测试层
│
├── packages/            # Dart 包 (melos 管理)
│   ├── core_config/     # 配置相关
│   ├── core_domain/     # 域层 (Result<T, AppError>)
│   ├── core_logging/    # 结构化日志
│   ├── download/        # 下载引擎
│   ├── live/            # 直播功能
│   ├── media_sniffer/   # 嗅探引擎
│   ├── player_engine/   # 播放器引擎抽象
│   ├── play_engine/     # 播放协调层
│   ├── plugin_host/     # 插件宿主
│   ├── search_engine/   # 搜索引擎
│   ├── source_adapter/  # 源适配器
│   └── storage/         # Drift 数据库
│
├── runtimes/            # 运行时
│   ├── sniffer/         # WebView2 + CDP 驱动
│   ├── spider_js/       # QuickJS 嵌入
│   ├── spider_jvm/      # JVM 运行时
│   └── spider_python/   # CPython 嵌入
│
├── tools/               # 辅助工具
│   ├── arch_check/      # 架构纪律检查
│   ├── build_jvm_runtime.ps1
│   ├── build_spider_js_runtime.ps1
│   ├── check_spider_js_bundle.dart
│   └── commit_lint/     # Conventional Commits 校验
│
└── docs/                # 文档 (见上方索引)
```

## 关键依赖版本基线

| 包 | 当前版本 | 上界 | 说明 |
|---|---|---|---|
| Flutter | 3.44.8 stable | - | 版本基线锁在 `.tool-versions` |
| Dart | 3.12.2 | - | 随 Flutter 分发 |
| Melos | 8.2.2 | - | monorepo 编排 |
| go_router | ^14.8.0 | ^17.5.0 | 路由框架 |
| media_kit_video | ^1.2.4 | ^2.0.1 | 视频解码 |
| sqlite3 | ^3.0.0 | ^3.5.2 | FFI native library |
| drift | ^2.34.0 < 2.34.1 | - | ORM 数据库 |
| drift_dev | ^2.34.0 < 2.34.1 | - | 迁移工具 |

## 必须遵守的开发纪律

### 1. 代码规范 ([10-开发规范.md](10-开发规范.md))
- **分支管理**: feat/ 功能分支，main 基线
- **提交消息**: 必须符合 Conventional Commits
- **预提交 hook**: pre-commit (格式+静态检查) + commit-msg (Conventional Commits 校验)
- **CI 门禁**: lint / test / build-check 三平台矩阵
- **分层检查**: `melos run check:arch` 必通过

### 2. 分层架构 ([02-系统架构.md](02-系统架构.md) §6)
- **core_domain**: 纯 Dart，不依赖任何 Flutter/IO 包
- **core_logging**: 结构化 logger (JSONL 落盘 + 脱敏函数)
- **core_config**: 配置解析与导入服务
- **packages**: 各功能独立包，通过 melos 管理
- **apps**: Flutter Desktop 主应用，仅 Presentation/Application 层

### 3. 错误处理基线
- `Result<T, AppError>` 模式统一
- `AppError` 码体系完整
- `dart:io` 异常有序脱敏（URL 中的 token 等）
- CI 中 `--fatal-infos --fatal-warnings`，零告警才算通过

### 3. UI 规范 ([09-UI规范.md](09-UI规范.md))
- **内容优先**: 封面与标题是主角，chrome 退让
- **桌面优先**: 鼠标悬停、右键菜单、键盘快捷键、多窗口
- **状态永远可见**: 加载中、失败原因、兜底渲染
- **四态规范**: Loading/Empty/Error/Success 必全
- **主题系统**: 深色/浅色/跟随系统/OLED，健壮性兜底
- **键盘操作**: 全局快捷键、焦点环、语义标签

### 4. 发布流程
- **里程碑**: 按 ROADMAP.md 交付标准，不按日期
- **版本映射**: v0.1 MVP → v1.0 Windows 正式版 → v1.5 → v2.0
- **发布门禁**: 合规扫描脚本在 CI 中作为发布门禁
- **更新流程**: 自动更新 + 模拟失败回滚

## 快速开始开发

### 环境搭建
```bash
# 1. 克隆项目
git clone <repository-url>
cd mistream_new

# 2. 初始化依赖
dart pub global activate melos
melos bootstrap

# 3. 生成代码
melos run generate

# 4. 运行分析
melos run analyze    # 应全绿

# 5. 格式化
melos run format     # 261 files, 0 changed

# 6. 运行测试
melos run check:all  # 包含格式+分析+测试
```

> **构建 Windows 产物**：`cd apps/mistream && flutter build windows --release`。
> cwd 必须是 app 包目录（仓库根不是 Flutter app），另有一批环境坑。
> 完整步骤见 [11-构建与发布.md](11-构建与发布.md)。

### 项目结构关键点
- `packages/` 目录下的每个包都有自己的 `pubspec.yaml`
- `melos.yaml` 配置在根 `pubspec.yaml` 的 `melos:` 键下
- `apps/mistream/` 是 Flutter Desktop 主应用（`name: mistream`）
- `runtimes/` 下的快速启动脚本：`tools/build_jvm_runtime.ps1` 等
- `tools/` 下的 lint/检查脚本

### 常用命令速查
```bash
melos run analyze      # 静态分析 (零告警)
melos run format       # 代码格式化
melos run check:arch # 分层纪律检查
melos run test         # 所有单测
melos run check:all    # 组合检查 (format + analyze + check:arch + test)
melos run generate     # 代码生成 (schema, 等)
```

## 已完成里程碑状态

> 注：里程碑按 ROADMAP.md 的**出口标准**判定，而非代码存在性。下表标注「组件已落地」表示相关代码/测试已就位并过门禁，但出口标准中的**真实源实测/长跑验证**项仍需联网环境手动完成。

| 里程碑 | 状态 | 关键交付物落库情况 |
|--------|------|--------|
| M0 · 工程奠基 | ✅ 完成 | melos 骨架、lint/format/hook、CI 矩阵、Result<T,AppError>、ADR 1-8 |
| M1 · 播放内核 | 🟧 组件落地 | PlayerEngine 抽象、MediaKitEngine、hwdec 降级链（21 用例全绿）、契约测试（142+1 全绿） |
| M2 · 数据层 | ✅ 组件落地 | drift schema v1-v3、DAO/Repository、迁移+备份框架（各表齐全） |
| M3 · RPC + Spider | 🟧 组件落地 | JSON-RPC stdio 分帧、SSRF 拦截、Host API、HTTP 运行时 |
| M4 · JS 运行时 | 🟧 组件落地 | QuickJS 嵌入、drpy 兼容层（100+ 用例）、interrupt/OOM 限制 |
| M5 · 主线 UI | 🟧 组件落地 | 首页/搜索/详情/播放/媒体库/设置 + 续播（router.dart）+ 起播 watchdog |
| M10 · 发布工程 | 🟧 部分落地 | `release.yml` 路径 bug 已修 + 整目录打包 + 合规门禁（见 [11-构建与发布.md](11-构建与发布.md) §7.3）；MSIX、代码签名、自动更新未做 |

## 待办事项概览

### 高优先级
- [ ] 真实配置源端到端实测（需联网 + 桌面 GUI 环境手动跑，饭太硬等反爬源属 M6 范围）
- [ ] 全仓 `melos run test` 耗时优化（>10 分钟，可做测试并行化/缓存）
- [ ] **在真实 tag 上跑通一次 `release.yml`**（2026-09-24 修了路径 bug，但改动本身
      尚未在 tag 上验证过，见 [11-构建与发布.md](11-构建与发布.md) §7.3）

### 中优先级
- [ ] 更新 12 个过时依赖包（go_router/media_kit_video/drift/build_runner/melos 等）
- [ ] 源诊断面板进 v1.0（05-Spider引擎 §5.4）
- [ ] 完善主题系统对比度自动化测试（09-UI规范 §2）

### 已完成的 M5 垂直验证
- [x] `apps/mistream/test/m5_mock_e2e_test.dart`：配置 URL → 导入 → Drift 落库 → 搜索 → 详情 → 播放地址
- [x] Mock 源覆盖 type=1 Apple CMS 链路；`mock_source_server` 同时提供 type=3 脚本端点
- [x] 配置站点开关兼容数字、字符串、布尔值；缺少 `searchable` 时默认可搜索
- [x] `ConfigDecoder.decodeWithProbe` 对 HTML/JPEG/PNG/GIF/BMP 返回 `CONFIG_NOT_JSON`

### 低优先级
- [ ] 跨平台（macOS/Linux）兼容性增强
- [ ] 实验性运行时（Python/JVM）支持
- [ ] 云同步功能
- [ ] 插件市场 UI

## 开发流程工作流

### 新功能开发流程
1. 在 `docs/02-系统架构.md` §6 查阅 ADR 是否已存在
2. 在对应 `packages/` 目录下实现功能
3. 遵守 `dart` 代码格式 (`melos run format`)
4. 通过 `melos run analyze` (零告警)
5. 编写对应单元测试
6. 通过 `melos run check:arch` (分层检查)
7. 提交 PR，确保 CI 三平台矩阵通过
8. 标记里程碑出口标准

### 问题排查流程
1. 运行 `melos run analyze` 定位分析警告
2. 运行 `melos run format` 确认格式统一
3. 运行 `melos run check:arch` 验证分层纪律
4. 检查 `CHANGELOG.md` 和 `ROADMAP.md` 里程碑状态
5. 查阅 `docs/adr/` 下的架构决策记录
6. 查看控制台错误日志和 Flutter Doctor 输出

---

*文档最后更新: 2026-09-24*
*项目: MiStream - Modern, cross-platform, pluginized media aggregator client*
*许可: LGPL + 动态链接 (见 About 页)*
