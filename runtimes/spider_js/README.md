# spider_js

QuickJS 运行时 + drpy 宿主 API 兼容层。**项目关键路径。**

接口见 [docs/05-Spider引擎](../../docs/05-Spider引擎.md)，
进程隔离理由见 [ADR-001](../../docs/adr/001-spider-独立子进程.md)。

兼容性测试集（`(HTML 快照, 规则, 期望输出)` 三元组）是本包的一等交付物，
不是附属品——`pdfh` 的语义只能靠对齐真实源行为来确定。

## 现状

| 部分 | 状态 |
| --- | --- |
| QuickJS 引擎（`JsRuntime` / FFI 绑定） | 可执行 JS，有正向回归用例 |
| drpy 兼容层（`pdfh`/`pdfa`/`crypto`） | 纯 Dart 实现，**已注册进 JS 上下文** |
| 宿主 API 桥（JS 里可调 `pdfh`/`md5`/`console`） | 同步函数已通 |
| `req`（网络）与 `local.*`（落库） | **已通**，走 `host.fetch` / `host.storage.*` 过宿主 RPC |
| 真实 drpy2 端到端 | 已跑通（4 条远程 import + 规则解析），见 `tool/probe_real_drpy.dart` |
| 兼容性测试集 | 10 条，出口标准要求 ≥100 |

## 宿主 API 桥

JS 侧只有一个 native 入口：

```
__qs_host(name, argsJson) -> resultJson
```

实参与返回值全走 JSON——这是被下面那条 JSValue 约束逼出来的，不是随手选的。
`JsRuntime` 在 `init()` 时注入一段 JS 前导，在这个入口之上铺出 drpy 的函数面：

`pdfh` `pdfa` `pd` `pdfl` `md5` `sha1` `sha256` `hmac256` `urlencode`
`urldecode` `base64Encode` `base64Decode` `joinUrl` `aes` `console.log/warn/error`

宿主侧报的错会在前导里变回 JS 异常，所以脚本能用寻常的 try/catch 处理，未捕获
时也能带堆栈冒泡到 `JsRuntime.lastError`。

分发表在 `HostBridge`，可用 `extraHandlers` 覆盖或追加。`HostBridge.invoke`
是公开的，好处是**分发表不依赖 native 也能被完整测到**（CI 上没有 DLL）。

派发目标按 **context** 存，不是进程全局。每个 `JsRuntime` 有自己的 context 和
自己的 Dart `NativeCallable`，而 `NativeCallable.isolateLocal` 只能由创建它的
isolate 调用——一个全局槽位会在第二个 runtime 注册时被覆盖，随后第一个 context
就会打进另一个 isolate 的回调里，进程直接 access violation。`dart test` 并行跑
suite 时立刻能复现；生产上「一个源一个 context」是同一回事。

### 同步性是怎么解决的

drpy 脚本按**同步**语义调 `req`（网络）和 `local.*`（落库），而 Dart 侧是异步的，
两者对不上。解法不是把宿主函数做成异步，而是**把整个脚本执行搬进独立子进程**
（ADR-001）：

- 子进程主循环刻意**全同步**——脚本调 `req` 时 C 栈停在 `JS_Eval` 里回调 Dart，
  Dart 事件循环不转，异步 I/O 的响应永远送不到。所以宿主往返必须是阻塞的。
- 阻塞在子进程里完全无害：它整个存在的意义就是跑完这一次调用。
- 于是 `req` → `host.fetch`、`local.*` → `host.storage.*`，都由宿主在
  `write` 回调里同步应答，脚本拿到的就是同步返回值。

代价是**重入**：`callHost` 写出请求后要继续读，而这期间宿主可能发来别的消息。
分流规则见 `RuntimeChild._awaitResponse`（匹配 id 的响应返回、`$/cancelRequest`
立即处理、其余入队）。


## native 依赖

`lib/src/engine/` 下的三个 DLL **不入库**（见 `.gitignore`），但仓库内
`tools/quickjs_dist/vendor/` 保存着同一份文件的**受版本控制的副本**：

- `libquickjs.dll` — QuickJS 本体（MinGW 构建）
- `quickjs_wrapper.dll` — MSVC 构建的 ABI 适配层，由 `native/build.bat` 生成
- `quickjs.dll` — `libquickjs.dll` 的别名副本

CI 上引擎目录为空，靠 `melos run quickjs:install`（`tools/quickjs_dist`）
从 vendor 副本校验 SHA256 后装回去；`spider-js:bundle` 会在打包前自动跑
这一步，避免「缺 DLL 却在构建成功后才暴露」。

wrapper 的存在理由：QuickJS 的 `JS_Eval` 等函数按值返回 16 字节的 `JSValue`
结构体，直接从 Dart FFI 调 MinGW 产物会踩 ABI 差异，所以中间垫一层 MSVC 编译的
薄封装。

重建：

```bat
runtimes\spider_js\native\build.bat
```

需要 VS 2022 BuildTools（C++ 工作负载）。脚本自己探测 vcvars64 的位置，中间产物
（`.obj` / `.lib` / `.exp`）落到 `%TEMP%`，不污染仓库。

脚本刻意**全 ASCII**：cmd 按 OEM 代码页（zh-CN 是 936）读 .bat，UTF-8 注释会被
错解、拆行，然后当命令执行——之前就是这样报出莫名的
`'xxx' is not recognized as an internal or external command`。

重编 `quickjs_wrapper.dll` 后记得把新 DLL 同步到 `tools/quickjs_dist/vendor/`
并更新 `tools/quickjs_dist/assets/quickjs.manifest.json` 的 SHA256，否则
`quickjs:install` 会拒绝替换。

DLL 不在场时引擎整体降级：`isQuickJSAvailable` 为 false，`JsRuntime.init()`
返回 false 并在 `lastError` 给出原因，相关用例整组 skip（未跑 quickjs:install
的 CI 即此路径）。

## 边界约定：跨 FFI 的 JSValue 只能是字符串

`JsRuntime.eval` 会把用户代码包进一层 JS（`_wrap`），结果与异常都在 JS 侧
`String()` / `JSON.stringify` 掉再回传。**这不是风格问题，是硬约束。**

手头这份 `libquickjs.dll` 的 `JSObject` 内存布局与 mainline QuickJS 不一致：

- 字符串（tag `-7`）首个 int32 确实是 `ref_count`（实测 `'a'+'b'` → 2）
- 对象（tag `-1`）首 8 字节是**链表指针**而非 `ref_count`（连续分配的三个对象
  读回的是彼此相邻的 `gc_obj_list` 节点地址）

而 libquickjs 只导出 `__JS_FreeValue`（finalizer，入口断言 `ref_count == 0`），
公开的 `JS_FreeValue` 是 static inline、没有符号可绑。于是对 object 来说：
自己递减会写坏链表指针，直接调 finalizer 会访问违例，不释放则泄漏、在
assert 版 libquickjs 上 `JS_FreeRuntime` 时断言 `list_empty(&rt->gc_obj_list)`。

三条路都不通，所以干脆让 object 不跨界——留在 JS 内部由 QuickJS 自己回收。
`test/quickjs_bindings_test.dart` 里那几条「对象/数组/函数结果不跨界」用例守的
就是这个约定，真正的断言点是 `tearDown` 里的 `dispose()`。

C 侧确实需要持有 object 引用的地方（注册宿主函数要拿 global、取异常要拿 Error），
用 `qs_release_object` 把引用**还给 QuickJS**而不是自己算：
`JS_SetPropertyStr` 会**消费**它存进去的值，所以「塞进一个临时槽位、再用
undefined 覆盖掉」这两步就等于让 QuickJS 拿自己知道的布局去 `JS_FreeValue`。

**根治办法**：拿到与该 DLL 匹配的 `quickjs.h`（或从已知源码自行构建
libquickjs），直接用真正的 `JS_FreeValue`。在那之前不要放宽这条约定。

## 缺陷：runtime 的 GC / 释放路径会断言 abort

**症状**：跑完一次真实 drpy2（4 条远程 import + 660KB 依赖 + `init` + `home`）
之后，调 `JS_FreeRuntime` 或 `JS_RunGC` 会以约一半概率触发
`Assertion failed: i != 0, file quickjs.c, line 3394` 直接 abort 整个进程
（换 reuse 之后还会撞 `js_rc(p->shape)->ref_count == 1, line 9235`）。
进程 abort 会**丢掉管道里缓冲的 stdout**，所以排查时得靠落盘追踪。

**爆炸半径**：宿主 `_trySites` 每试一个订阅源就 `spider.destroy` 一次，也就是
每次请求都会打死共享的 JS 子进程，顺带带走同进程里其它源的调用。

**二分结论**（每组 6 次，脚本见下）：

| 操作 | 结果 |
| --- | --- |
| `JS_FreeContext` | 6/6 走完，**永远安全** |
| `JS_RunGC` | 6 次崩 5 次 |
| `JS_FreeRuntime` | 同样会崩（它内部也走这套释放路径） |
| 释放 context 后再往同一 runtime 挂新 context | 崩（shape 是 runtime 级对象、跨 context 共享） |

也就是说崩点是**这套 build 的 GC/释放机制本身**，不是「有环没回收」——所以
「先 GC 再释放」的组合没有意义。它还是**堆布局阈值敏感**的：内存上限
32/128/256/512MB 都不触发、默认 64MB 触发；少装一个限值或少数一步求值也不
触发。调参数只是换个落点，不是修复。

**缓解（当前实现）**：

1. `JsRuntime.park()`：只做 `JS_FreeContext` + 封存，**不 GC、不释放 runtime**；
   `dispose()` 对封存过的实例只丢引用。于是热路径上一次都不碰那两条危险调用。
2. **不复用 runtime**：释放过 context 的 runtime 已被污染，再挂新 context 会撞
   shape 断言。每个源一个全新 runtime。
3. 代价是**内存**：实测释放 context 并不真把内存还回来，每个源约留 10MB。
   所以由宿主**整进程换新**来归还——`SpiderHost` 每收掉
   `kSourceTearDownsPerProcess`（默认 8）个源、且当前没有活实例时，发
   `runtime.shutdown` 让子进程干净退出，再重新拉起。进程退出由 OS 回收内存，
   代价只是下一次 `spider.create` 重付一次 drpy2 加载。

**复现与验收脚本**（`runtimes/spider_js` 目录下）：

```bash
dart run tool/probe_real_drpy.dart              # 真实 drpy2 全链路 + 连续试源
dart run tool/probe_real_drpy.dart cycles=10    # 连续 11 个源，顺带报 RSS
dart run tool/repro_dispose.dart full 5         # 最小复现（旧行为：会崩）
dart run tool/repro_dispose.dart full 5 lim=none  # 对照：换限值就不崩
```

`probe_real_drpy.dart` 是**进程内**驱动真 `RuntimeChild` + 真 QuickJS，只在分帧层
拦一个点接管全部 HTTP（子进程协议是同步的，宿主回话必须发生在 `write` 回调里）。
当前 13 项检查全过，连跑 10 次无 abort。

**根治办法**同上一节：换一份非 assert 构建、或拿到匹配的 `quickjs.h` 自行构建。
