# spider_jvm

外部 JRE + android 兼容 shim。**实验性可选组件，不承诺任意 jar 可用。**

**状态**：已实现，但按 [ADR-006](../../docs/adr/006-jar-运行时降级为可选.md)
**不进 v1.0 出口标准**，排在 M15（v2.0）。

> 这里原先写的是「**状态**：占位，M15 落地」。那句话是错的，已于 2026-10-04 修正：
> `src/main/java` 下是真实实现（进程、JSON-RPC 协议、dex→jar 转换链路俱全），
> `tools/jvm_smoke_test.ps1` 能跑通握手与 `home` 取数并拿到真实数据。
> 把它标成「占位」会让排查的人直接跳过这个目录 —— 而 0.1.0 那次「105 个站点
> 全部不可用」的根因恰好就在这儿。

## 前置条件（两项都要用户自己装，MiStream 不随包分发）

| 依赖 | 用途 | 缺失后果 |
| --- | --- | --- |
| **JRE/JDK 17+** | 跑 `spider_jvm_runtime.jar` | 所有 jar 源不可用 |
| **Python3** | 跑 enjarify 做 dex→jar 转换 | 只有 dex 形态的 jar 源失败，纯 Java 字节码的 jar 不受影响 |

不内置 JRE 是 ADR-006 明确否决过的备选方案：随包分发要 +150MB 以上，且要承担
JRE 的安全更新责任。

## 构建

```bash
melos run jvm:build      # 等价于 powershell -File tools/build_jvm_runtime.ps1
```

产物为 `build/spider_jvm_runtime.jar`（`--release 17` 编译，字节码 major 61）。

**`build/` 与 `libs/` 都不入库**（根 `.gitignore` 的 `build/` 命中前者），
干净检出里没有 jar。因此：

- 发布链（`release.yml`、`ci.yml` 的 `release-windows`）必须先跑这一步
- CMake 的 install 规则是 `OPTIONAL`：没构建时**不报错**，只在 configure 阶段打一条 STATUS
- 兜底靠发布门禁 `tools/check_jvm_runtime_bundle.dart` —— 产物缺 jar 直接红

## 包内布局（与解析代码严格对应，不能改）

```
<exe 目录>/runtimes/spider_jvm/
├── build/spider_jvm_runtime.jar
└── libs/*.jar                    # 31 个依赖
```

启动命令：`java -cp <jar>;<libs>/* io.mistream.jvm.Main`

`AppAssembly._resolveJvmRuntimeDir()` 按这个布局逐条试候选目录（exe 同级 →
逐级向上 → `%APPDATA%/com.mistream/mistream` → cwd）。它的判定条件与
`tools/check_jvm_runtime_bundle.dart` **必须一致** —— 两处不一致就会出现
「门禁放行的包在运行时仍判为不可用」。

> 0.1.0 的便携包漏了这个目录，导致 105 个 `csp_` 站点在界面上全部显示
> 「暂不支持」。根因是 `apps/mistream/windows/CMakeLists.txt` 里没有对应的
> install 规则，已于 2026-10-04 修复。

## 能力边界

只承诺「**纯 Java 逻辑 + 已 shim 的 android API 子集**」可运行，不承诺任意 jar
可用。三类障碍都可能导致失败：字节码格式不对（Android Dex）、依赖未 shim 的
android 框架 API、依赖 WebView 执行 JS 挑战。完整理由见
[ADR-006](../../docs/adr/006-jar-运行时降级为可选.md)。
