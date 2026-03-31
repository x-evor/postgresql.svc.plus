#!/usr/bin/env bash
set -e

tags="$1"
preferred=""

while IFS= read -r line; do
  [[ "$line" == *":latest" ]] && preferred="$line" && break
done <<< "$tags"

if [[ -z "$preferred" ]]; then
  preferred="$(echo "$tags" | head -n 1)"
fi

echo "$preferred"
