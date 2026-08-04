# arch_check

把 [docs/10-开发规范](../../docs/10-开发规范.md) §3 里的分层纪律变成 CI 门禁。

```bash
melos run check:arch
# 或
dart run tools/arch_check/bin/arch_check.dart
```

## 三条规则

| 规则 | 内容 |
| --- | --- |
| `pure-dart` | `core_domain` 的 pubspec 依赖与源码 import 必须在白名单内 |
| `layering` | `apps/mistream/lib/features/**` 不得 import `spider_host` / `storage` / `plugin_host` |
| `ignore-reason` | 每个 `// ignore:` 都要跟一句为什么 |

白名单：`dart:` 只允许 `async` `collection` `convert` `math` `typed_data`；
`package:` 只允许 `meta`。

## 为什么值得单写一个工具

「`core_domain` 不许 import Flutter/IO」是 M0 的出口标准之一，但加一行
`import 'dart:io'` 只要一秒——而它一旦进去，这个包就再也无法在纯 Dart 环境下
跑测试，也无法被 `runtimes/` 下的子进程复用。这类约束靠人盯是盯不住的。

`ignore-reason` 同理：无理由的 `// ignore:` 等于把一条 lint 规则永久关掉却不
留线索，半年后没人敢动它。写一句为什么成本是一行，收益是它将来可以被清理。
