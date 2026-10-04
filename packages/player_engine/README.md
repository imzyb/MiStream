# player_engine

`PlayerEngine` 抽象与 libmpv 实现。

**状态**：M1-a 已落地抽象层与契约测试；M1-b 的 `MediaKitEngine`（media_kit /
libmpv 实现）已接入同一套契约，纯映射逻辑已被 `dart test` 覆盖。

设计见 [docs/04-播放器设计](../../docs/04-播放器设计.md)，
分两期实现的理由见 [ADR-004](../../docs/adr/004-播放器分两期实现.md)。

## 公共 API

两个入口，刻意分开：

| 入口 | 内容 |
| --- | --- |
| `package:player_engine/player_engine.dart` | `PlayerEngine` 接口与全部值类型 |
| `package:player_engine/testing.dart` | `FakePlayerEngine` 测试替身 |

测试替身若并进主入口，生产代码 import 之后就能顺手 `FakePlayerEngine()`，
而这种事一旦发生没人会注意到。分开导出让它在 review 时是一行显眼的 import。

## 接口以 mpv 为参照系

[ADR-004](../../docs/adr/004-播放器分两期实现.md) 的「后果」一节写明了本包最大的
风险：抽象层若照抄一期实现（media_kit）的形状，二期换 `NativeMpvEngine` 时会
发现接口不够用，抽象层也就白做了。缓解措施是**以 mpv 的原生能力为参照系**，
具体落在三处：

- `TrackId` 采用 mpv `vid`/`aid`/`sid` 的取值语义——轨道号、`auto`、`no`
  三种值，而不是列表下标。用下标会丢掉「自动选轨」与「关字幕」，而这恰是
  最常用的两个操作。
- `HwdecChain` 是**有序的降级链**（`d3d11va-copy` → `d3d11va` → `dxva2-copy`
  → 软解），不是布尔开关。归并成「是否硬解」会直接丢掉 docs/04 §5 那张表。
- `MediaInfo` 的字段一一对应 mpv 属性（`video-codec`、`container-fps`、
  `video-bitrate`、`hwdec-current`、`video-params/*`），不做二次归并。

## 失败怎么表达

`docs/10-开发规范.md` §3.4 要求可预期失败走 `Result`，而 docs/04 §3 的原始
签名清一色是 `Future<void>`。本包按三条收敛（文档已同步）：

1. **返回 `AppResult`**：`initialize` / `open` / `addExternalSubtitle` /
   `screenshot`。失败由外部原因造成、可预期，且调用方必须分支处理——
   `PlayUseCase` 的整条回退链就建立在「`open` 失败了，换下一个候选」之上。
2. **返回 `Future<void>`，只在调用顺序错误时抛 `StateError`**：其余传输控制。
   未 `initialize` 就调、`dispose` 之后再调，都是编程错误。
3. **走 `errorStream`**：播放中的异步失败（解码错误、网络中断、硬解降级）。
   它们不属于任何一次方法调用，没有返回值可挂。

## 流的订阅语义

所有 `Stream` 都是广播流，且**迟到的订阅者立即收到当前值**。播放页的组件是
陆续挂载的，控制栏订阅时播放可能已经开始；拿不到当前值就会显示成「未播放」
直到下一次状态变化——而稳定播放时，下一次变化可能是十分钟以后。

## 单独测试

```bash
dart test packages/player_engine        # 或 melos run test:dart
```

契约套件在 `test/contract/player_engine_contract.dart`，每个实现写一个几行的
入口文件调用它即可（见 `test/contract/fake_engine_contract_test.dart` 与
`test/contract/media_kit_engine_contract_test.dart`）。后者需要 libmpv 运行库
与一个本地样本媒体（由 `LIBMPV_LIBRARY_PATH` 与 `MISTREAM_SAMPLE_MEDIA` 两个
编译期环境变量给出），缺了就整组跳过——真真能不能起播由 M1 出口标准的手工
验收把关。需要真实媒体才能验的项——硬解是否生效、HLS 能否起播、连续两小时
不涨内存——都属于 M1 出口标准里的手工验证，不在契约套件内。
