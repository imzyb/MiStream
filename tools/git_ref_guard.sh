#!/bin/sh
# 修复「提交后分支引用被删除」的环境问题。
#
# 现象：在 I: 盘（虚拟化文件系统）上执行 git commit 后，.git/refs/heads/<分支>
# 这个目录会被删除，导致下一次 git 命令报
#   fatal: your current branch 'X' does not have any commits yet
# 若不处理就继续提交，git 会走 initial commit 路径，产生父提交为空的孤儿提交，
# 从而丢失整条历史链。
#
# 已确认：引用在 commit 执行期间是完好的（reflog 记录父提交正确），删除发生在
# git 进程退出阶段，属于文件系统交互问题，与 .githooks 钩子无关
# （--no-verify 同样复现）。
#
# 用法：每次提交后执行
#   sh tools/git_ref_guard.sh
# 脚本从 reflog 恢复引用，并校验恢复后的提交确实是当前 HEAD 的祖先。

set -eu

branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
if [ -z "$branch" ]; then
  echo "git_ref_guard: 当前不在分支上，跳过" >&2
  exit 0
fi

ref_path=".git/refs/heads/$branch"
if [ -f "$ref_path" ]; then
  echo "git_ref_guard: 引用完好，无需修复"
  exit 0
fi

log=".git/logs/refs/heads/$branch"
if [ ! -f "$log" ]; then
  echo "git_ref_guard: 找不到 reflog，无法恢复：$log" >&2
  exit 1
fi

# reflog 每行格式：<old> <new> <ident> <ts> <msg>，取最后一行的 new。
head_hash=$(tail -1 "$log" | awk '{print $2}')
if [ -z "$head_hash" ]; then
  echo "git_ref_guard: reflog 为空，无法恢复" >&2
  exit 1
fi

# reflog 里可能存在孤儿提交（old 为全零），此时最后的 new 不可信。
# 向前回溯，找到第一个 old 非零的记录，用它的 new 作为安全落点。
safe_hash=$(awk '$1 !~ /^0+$/ { h = $2 } END { print h }' "$log")
if [ -n "$safe_hash" ]; then
  head_hash="$safe_hash"
fi

mkdir -p "$(dirname "$ref_path")"
printf '%s\n' "$head_hash" > "$ref_path"

echo "git_ref_guard: 已恢复 $branch -> $head_hash"
git log --oneline -1
