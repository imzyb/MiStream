# git hooks

放在版本库里而不是 `.git/hooks/`，靠 `core.hooksPath` 指过来。这样 hook 本身
能被 review、能随 PR 一起改，不会出现「每个人机器上的 hook 都不一样」。

## 安装

`melos bootstrap` 的 post hook 已经自动执行，正常流程下不用管。手动修复：

```bash
git config core.hooksPath .githooks
```

## 内容

| hook | 作用 |
| --- | --- |
| `pre-commit` | 对暂存的 `.dart` 跑 `dart format` 并重新入暂存区 |
| `commit-msg` | 用 `tools/commit_lint` 校验提交信息 |

两个 hook 在找不到 `dart` 时都只警告不阻断——CI 会兜住。

## 行尾

`.gitattributes` 强制 `.githooks/*` 为 LF。带 CRLF 的 sh 脚本在 Windows 的
Git Bash 下会以 `bad interpreter` 失败，所以这不是风格问题。

## 绕过

`git commit --no-verify` 可以跳过。这是给「本地环境临时坏掉」留的口子，不是
常规操作——CI 上的 `lint` 与 `commitlint` job 拦的是同样的规则。
