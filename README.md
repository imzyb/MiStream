# MiStream

MiStream 是一个现代化、跨平台、插件化的媒体聚合客户端。它兼容 TVBox 生态的配置协议，但在架构、播放内核与工程质量上完全重做。

## 特性

- **Flutter Desktop** — Windows 优先，后续 macOS / Linux
- **libmpv 播放内核** — HDR、AV1、HEVC、完整字幕栈、精细硬解控制
- **Spider Runtime** — JS / HTTP 为主，Python / JVM 为实验性；独立进程沙箱，源崩溃不影响主进程
- **插件系统** — Manifest + 权限模型 + 原子升级回滚
- **主题系统** — 设计令牌驱动，无代码执行
- **自动更新** — 校验、原子替换、失败回滚

## 重要说明

MiStream **不内置、不分发、不推荐任何内容源、订阅地址或解析接口**。安装包为空壳，所有数据源需由用户自行导入。用户须对自己导入的内容及其合法性负责。

项目不提供 VIP 破解、DRM 解除或付费墙绕过能力。

## 文档

| 文档 | 内容 |
| --- | --- |
| [ROADMAP](ROADMAP.md) | 里程碑、出口标准、依赖图、风险登记册 |
| [01-项目概述](docs/01-项目概述.md) | 定位、范围、合规边界、成功标准 |
| [02-系统架构](docs/02-系统架构.md) | 分层、进程模型、数据流、ADR |
| [03-技术选型](docs/03-技术选型.md) | 技术栈、自研清单、License、体积预算 |
| [04-播放器设计](docs/04-播放器设计.md) | PlayerEngine、能力矩阵、硬解、起播编排 |
| [05-Spider引擎](docs/05-Spider引擎.md) | 统一接口、四类运行时、沙箱、TVBox 兼容层 |
| [06-插件系统](docs/06-插件系统.md) | Manifest、权限、生命周期、市场 |
| [07-数据库设计](docs/07-数据库设计.md) | 表结构、迁移、备份 |
| [08-RPC协议](docs/08-RPC协议.md) | 分帧、方法清单、错误码、版本协商 |
| [09-UI规范](docs/09-UI规范.md) | 设计令牌、响应式、页面规范、文案 |
| [10-开发规范](docs/10-开发规范.md) | 分支、提交、测试、CI/CD、发布、安全基线 |
| [ADR 索引](docs/adr/README.md) | 架构决策记录 |
| [compatibility](docs/compatibility.md) | 版本兼容矩阵 |
| [检查清单](docs/checklists/) | 发布门禁、播放回归 |

## 开发环境

| 工具 | 版本 | 说明 |
| --- | --- | --- |
| Flutter | 3.44.8 stable | 版本基线锁在 [`.tool-versions`](.tool-versions)，asdf / mise 可直接读取 |
| Dart | 3.12.2 | 随 Flutter 分发，不单独安装 |
| Melos | 8.2.2 | monorepo 编排；配置在根 `pubspec.yaml` 的 `melos:` 键下，不再有 `melos.yaml` |

```bash
dart pub global activate melos
melos bootstrap        # 解析依赖，并自动把 git hooks 指向 .githooks
melos run check:all    # 格式 + 静态检查 + 分层校验 + 全部单测
flutter run -d windows # 从仓库根目录直接跑
```

`melos bootstrap` 会执行 `git config core.hooksPath .githooks`，装上 pre-commit（格式与静态检查）与 commit-msg（Conventional Commits 校验，实现见 [`tools/commit_lint`](tools/commit_lint)）。若 hooks 未生效，手动执行 `melos run hooks:install`。

常用脚本：

| 命令 | 作用 |
| --- | --- |
| `melos run format` | 格式化全部 Dart 代码 |
| `melos run analyze` | 静态检查，零告警才算通过 |
| `melos run test` | 纯 Dart 包与 Flutter 包的全部单测 |
| `melos run check:arch` | 分层纪律与 `ignore` 注释校验 |

## 状态

**M0 · 工程奠基**已完成——monorepo 骨架、Flutter 桌面空窗口、lint/format/hook、commitlint、CI 三平台矩阵、结构化 logger 与 `Result<T, AppError>` 均已落地。下一步是 M1 播放内核。

完整进度与各里程碑出口标准见 [ROADMAP](ROADMAP.md)。
