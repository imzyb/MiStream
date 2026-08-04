# core_domain

MiStream 的领域层。**这个包不依赖 Flutter，也不碰 IO**——没有 `dart:io`、没有
Dio、没有 drift。约束由 `tools/arch_check` 在 CI 中强制校验，不是靠自觉。

约束的意义在于：领域模型一旦沾上 IO，就再也无法在纯 Dart 环境下快速跑测试，
也无法被 `runtimes/` 下的子进程复用。

## 当前内容（M0）

| 文件 | 职责 |
| --- | --- |
| `src/error/error_code.dart` | 全量错误码。负数来自 RPC，正数是宿主本地 |
| `src/error/app_error.dart` | `AppError` sealed class，`RemoteError` / `LocalError` |
| `src/error/result.dart` | `Result<T, E>` 与组合子，领域层用它代替异常 |

实体（`MediaItem` / `Episode` / `PlaySource` / `Channel` / `SourceSite`）与
Repository 接口在 M2 随数据层一起落地。

## 为什么用 Result 而不是异常

`docs/10-开发规范.md` §3.4：可预期失败不该走异常。搜索单个源失败是**正常**
情况（几十个源里总有几个挂掉），用异常表达会让调用方不得不在每层写
`try/catch`，而漏写一处就是崩溃。`Result` 把失败编进类型里，编译器会提醒。

真正的编程错误（断言失败、非法状态）仍然 `throw`。

## 单独测试

```bash
dart test packages/core_domain
```
