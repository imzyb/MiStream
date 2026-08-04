# ADR-007：状态管理用 Riverpod

**状态**：已接受

## 背景

MiStream 的状态复杂度集中在几个地方：

- **多源并发搜索**：N 个源各自独立地加载中/成功/失败，结果流式合并，任一源不能阻塞其它源
- **播放器状态**：position/duration/buffered/tracks 多路高频流，同时被控制栏、进度条、抽屉、信息浮层消费
- **跨页面共享**：当前播放项、收藏状态、源列表状态需要在多个页面间保持一致
- **可取消**：用户改搜索词时要中止在途请求（[08-RPC协议](../08-RPC协议.md) §3.4）

同时 [10-开发规范](../10-开发规范.md) §3.3 要求分层纪律：Presentation 不得直接触碰 Infrastructure。状态管理方案必须让这条纪律**可强制**，而不只是靠自觉。

## 决策

我们将使用 **Riverpod（code-gen 模式，`@riverpod` 注解）** 作为状态管理与依赖注入方案。

- Provider 作为 Application 层的载体，UI 只读 Provider
- Repository 通过 Provider 注入，测试时 `overrideWith` 替换为 mock
- 异步状态统一用 `AsyncValue`，配合 `AsyncBuilder` 组件强制四态渲染（[09-UI规范](../09-UI规范.md) §7）
- 自动 dispose（`autoDispose`）承载取消语义：页面离开 → provider 销毁 → 请求取消

## 备选方案

| 方案 | 优点 | 放弃原因 |
| --- | --- | --- |
| Bloc | 结构清晰、事件溯源、社区大 | 样板代码量大（每个功能三个文件）；对「N 个并发流合并」这类场景需要手写大量 stream 编排；依赖 `BuildContext` 获取实例，测试与跨层访问不便 |
| Provider（原版） | 简单、官方推荐过 | 依赖 `BuildContext`，无编译期安全；`ProxyProvider` 的组合能力弱；作者本人已用 Riverpod 取代它 |
| GetX | 上手快、样板少 | 服务定位器模式导致依赖关系隐式且不可追踪；与「分层纪律可强制」的目标直接冲突；测试隔离困难 |
| signals / 手写 InheritedWidget | 轻量、无依赖 | 需要自己实现依赖追踪、缓存失效、异步状态封装——等于重造 Riverpod 的一半 |
| MobX | 响应式心智模型简洁 | Dart 生态中相对小众；code-gen 依赖同样存在；对异步状态的四态表达不如 `AsyncValue` 直接 |

## 后果

**正面**

- **无 `BuildContext` 依赖**：Application 层的逻辑可以脱离 widget 树单独单测，这是分层纪律能落地的技术前提
- **编译期安全**：code-gen 模式下 provider 类型、参数、依赖关系都有静态检查，改签名会在编译期报错而不是运行时
- `AsyncValue` 天然表达 loading/data/error，配合 `AsyncBuilder` 让「四态齐全」成为默认行为而非纪律要求
- `autoDispose` + `ref.onDispose` 让取消语义有统一的挂载点，不需要每个页面手写取消逻辑
- `overrideWith` 让集成测试可以整体替换掉 SpiderHost 和 Storage，用 mock 源服务跑端到端

**负面**

- **学习曲线陡**：`ref`、`watch`/`read`/`listen` 的区别、provider 的生命周期、code-gen 的使用，新人上手需要时间
  - 缓解：在 `docs/` 中补一份内部使用约定（何时用 `watch` 何时用 `read`），并在 code review 中作为固定检查项
- 引入 build_runner，增加构建时间与生成代码体积
- provider 数量增长后，依赖关系可能变得难以追踪
  - 缓解：约定 provider 命名（名词 + `Provider`），按 feature 就近组织，禁止跨 feature 直接依赖 provider
- 与 Flutter 官方未来可能的状态管理方向存在偏离风险（可接受——Riverpod 是纯 Dart 实现，不依赖框架内部 API）

## 参考

- [02-系统架构](../02-系统架构.md) §1 分层视图
- [09-UI规范](../09-UI规范.md) §7 状态设计规范
- [10-开发规范](../10-开发规范.md) §3.3 分层纪律
