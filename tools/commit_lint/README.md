# commit_lint

Conventional Commits 校验器。规则见
[docs/10-开发规范](../../docs/10-开发规范.md) §2。

`.githooks/commit-msg` 与 CI 共用同一份实现——本地拦不住的（比如 `--no-verify`
绕过），CI 会在 PR 上再拦一次。

## 用法

```bash
dart run tools/commit_lint/bin/commit_lint.dart .git/COMMIT_EDITMSG
dart run tools/commit_lint/bin/commit_lint.dart --message "feat(ui): 加个按钮"
dart run tools/commit_lint/bin/commit_lint.dart --range origin/main..HEAD
```

存在 error 即退出码 1；warning 只打印不拦。

## 规则

| 规则 | 级别 | 说明 |
| --- | --- | --- |
| `header-format` | error | 必须是 `type(scope): subject`，冒号后一个空格 |
| `type-enum` | error | type 在白名单内 |
| `scope-enum` | error | scope 若写了就必须在白名单内；可整个省略 |
| `subject-empty` | error | subject 不能为空 |
| `subject-max-length` | error | subject ≤ 50 字（按字符计，中文一字算一个）|
| `subject-full-stop` | error | 结尾不要句号 |
| `subject-language` | **warn** | 约定用中文，但不拦英文 |
| `body-leading-blank` | error | header 与 body 之间要空一行 |

merge / revert / fixup / squash 这些 git 自动生成的信息直接跳过——格式由 git
决定，拦了也改不了。

新增 scope 请先改 `docs/10-开发规范.md` §2 再改
`CommitLinter.defaultScopes`，别只改代码。
