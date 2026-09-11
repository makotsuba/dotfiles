#!/bin/bash
# PreToolUse hook: block rm -rf as a second layer (deny list known bug workaround)
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required by the destructive-command guard" >&2
  exit 2
fi

if ! input=$(cat); then
  echo "Error: could not read hook input" >&2
  exit 2
fi
if ! command=$(printf '%s' "$input" | jq -er \
  '.tool_input.command | if type == "string" and length > 0 then . else error("invalid command") end' \
  2>/dev/null); then
  echo "Error: invalid hook input" >&2
  exit 2
fi

if echo "$command" | grep -qE 'rm\s+.*(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)'; then
  echo "rm -rf は禁止されています。削除が必要な場合は手動で実行してください。" >&2
  exit 2
fi
