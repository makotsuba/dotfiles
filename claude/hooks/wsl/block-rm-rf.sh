#!/bin/bash
# PreToolUse hook: block rm -rf as a second layer (deny list known bug workaround)
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

if echo "$command" | grep -qE 'rm\s+.*(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)'; then
  echo "rm -rf は禁止されています。削除が必要な場合は手動で実行してください。" >&2
  exit 2
fi
