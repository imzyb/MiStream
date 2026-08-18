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
| `req`（网络）与 `local.*`（落库） | **未接**，见下「同步性缺口」 |
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

### 同步性缺口：req 与 local.*

只登记**同步**函数。`req`（网络）与 `local.*`（落库）在 Dart 侧都是异步的，而
drpy 脚本按同步语义调它们，两者对不上。要接得先有 ADR-001 的子进程/隔离区加上
阻塞原语（或把 `local.*` 的 KV 在 init 时预载进内存、写回异步化）。在那之前脚本
里调这两个会报未定义，而不是拿到假数据。


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
