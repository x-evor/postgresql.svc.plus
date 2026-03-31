#!/usr/bin/env bash
set -euo pipefail

# === Config ===
REMOTE="${REMOTE:-origin}"
KEEP_BRANCHES=("main" "release/mvp" "release/v0.1.0")

DRY_RUN=0
ASSUME_YES=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -r <remote>   指定远程名（默认: origin）
  -n            仅演示要删除哪些分支（dry-run）
  -y            跳过确认，直接执行
  -k <branch>   额外保留一个分支（可重复多次）
  -h            显示帮助

Env:
  REMOTE=origin|...   也可用环境变量指定远程名
EOF
}

# --- Parse args ---
while getopts ":r:nyk:h" opt; do
  case $opt in
    r) REMOTE="$OPTARG" ;;
    n) DRY_RUN=1 ;;
    y) ASSUME_YES=1 ;;
    k) KEEP_BRANCHES+=("$OPTARG") ;;
    h) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
  esac
done

# --- Preconditions ---
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "❌ 当前目录不是 Git 仓库"; exit 1; }

echo "➡️ 远程: $REMOTE"
echo "➡️ 保留分支: ${KEEP_BRANCHES[*]}"

# --- Helpers ---
is_kept() {
  local b="$1"
  for k in "${KEEP_BRANCHES[@]}"; do
    [[ "$b" == "$k" ]] && return 0
  done
  return 1
}

join_by_newline() { printf '%s\n' "$@"; }

CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD || echo "")"

# --- Refresh remote refs ---
git fetch -p "$REMOTE" >/dev/null

# --- Compute deletion sets ---
mapfile -t LOCAL_BRANCHES < <(git for-each-ref --format='%(refname:short)' refs/heads)
mapfile -t REMOTE_BRANCHES < <(
  git for-each-ref --format='%(refname:short)' "refs/remotes/$REMOTE" \
  | sed "s#^$REMOTE/##" \
  | sort -u
)

LOCAL_TO_DELETE=()
for b in "${LOCAL_BRANCHES[@]}"; do
  if ! is_kept "$b"; then
    if [[ -n "$CURRENT_BRANCH" && "$b" == "$CURRENT_BRANCH" ]]; then
      echo "⚠️ 跳过本地当前检出分支: $b"
      continue
    fi
    LOCAL_TO_DELETE+=("$b")
  fi
done

REMOTE_TO_DELETE=()
for b in "${REMOTE_BRANCHES[@]}"; do
  is_kept "$b" || REMOTE_TO_DELETE+=("$b")
done

echo
echo "📌 将删除的本地分支 (${#LOCAL_TO_DELETE[@]}):"
((${#LOCAL_TO_DELETE[@]})) && join_by_newline "${LOCAL_TO_DELETE[@]}" || echo "(无)"

echo
echo "📌 将删除的远程分支 (${#REMOTE_TO_DELETE[@]}):"
((${#REMOTE_TO_DELETE[@]})) && join_by_newline "${REMOTE_TO_DELETE[@]}" || echo "(无)"

if (( DRY_RUN )); then
  echo
  echo "✅ dry-run 模式：未做任何更改。"
  exit 0
fi

if (( ! ASSUME_YES )); then
  echo
  read -r -p "❓确认删除以上分支吗？(y/N) " ans
  [[ "${ans:-N}" =~ ^[Yy]$ ]] || { echo "已取消。"; exit 0; }
fi

# --- Delete locals ---
if ((${#LOCAL_TO_DELETE[@]})); then
  for b in "${LOCAL_TO_DELETE[@]}"; do
    echo "🗑  删除本地分支: $b"
    git branch -D "$b"
  done
else
  echo "ℹ️ 无本地分支需要删除。"
fi

# --- Delete remotes ---
if ((${#REMOTE_TO_DELETE[@]})); then
  for b in "${REMOTE_TO_DELETE[@]}"; do
    echo "🗑  删除远程分支: $REMOTE/$b"
    git push "$REMOTE" --delete "$b"
  done
else
  echo "ℹ️ 无远程分支需要删除。"
fi

echo "✅ 完成。"
