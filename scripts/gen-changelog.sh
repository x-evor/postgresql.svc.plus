#!/usr/bin/env bash
set -euo pipefail

RAW_FROM_TAG=${1:-""}
RAW_TO_TAG=${2:-"HEAD"}
OUTPUT_NAME=${3:-"$RAW_TO_TAG"}

FROM_TAG="$RAW_FROM_TAG"
TO_TAG="$RAW_TO_TAG"

# 检查 FROM_TAG
if [[ -n "$FROM_TAG" ]]; then
  if ! git rev-parse "$FROM_TAG" >/dev/null 2>&1; then
    echo "⚠️  Tag $FROM_TAG not found, using previous tag instead" >&2
    if FALLBACK_TAG=$(git describe --tags --abbrev=0 2>/dev/null); then
      FROM_TAG="$FALLBACK_TAG"
    else
      FALLBACK_TAG=$(git tag --sort=-creatordate | head -n 1 || true)
      if [[ -n "$FALLBACK_TAG" ]]; then
        FROM_TAG="$FALLBACK_TAG"
      else
        echo "⚠️  No existing tags found, defaulting to empty range" >&2
        FROM_TAG=""
      fi
    fi
    if [[ -n "$FROM_TAG" ]]; then
      echo "ℹ️  Using fallback tag: $FROM_TAG" >&2
    fi
  fi
fi

# 检查 TO_TAG
if ! git rev-parse "$TO_TAG" >/dev/null 2>&1; then
  echo "⚠️  Tag $TO_TAG not found, using HEAD instead" >&2
  TO_TAG=HEAD
fi

# 生成 changelog 内容
CONTENT=$(cat <<EOF
## Changelog $FROM_TAG → $TO_TAG

### 👥 Contributors
$(git log --pretty=format:"- %an" $FROM_TAG..$TO_TAG | sort -u || echo "- (none)")

### ✨ Features / Changes
$(git log --pretty=format:"- %s" $FROM_TAG..$TO_TAG | grep -E "^(feat|fix|chore|refactor|docs|perf)" || echo "- (no major feature commits)")

### 📦 Others
$(git log --pretty=format:"- %s" $FROM_TAG..$TO_TAG | grep -vE "^(feat|fix|chore|refactor|docs|perf)" || echo "- (none)")
EOF
)

# 打印到终端
echo "$CONTENT"

# 如果在 CI 中，写入 docs/changelog_<ref>.md
if [[ -n "${GITHUB_REF_NAME:-}" || -n "$OUTPUT_NAME" ]]; then
  mkdir -p docs
  SAFE_OUTPUT_NAME=${OUTPUT_NAME:-${GITHUB_REF_NAME:-}}
  SAFE_OUTPUT_NAME=${SAFE_OUTPUT_NAME//[^A-Za-z0-9._-]/_}
  OUTFILE="docs/changelog_${SAFE_OUTPUT_NAME}.md"
  echo "$CONTENT" > "$OUTFILE"
  echo "✅ changelog written to $OUTFILE"
fi
