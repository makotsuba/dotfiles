#!/bin/bash
# PreToolUse hook: block Read/Edit/Write/MultiEdit/NotebookEdit access to .env files

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required by the .env access guard" >&2
  exit 2
fi

if ! input=$(cat); then
  echo "Error: could not read hook input" >&2
  exit 2
fi

# file_path: Read/Edit/Write/MultiEdit, notebook_path: NotebookEdit
if ! file=$(printf '%s' "$input" | jq -er \
  '(.tool_input.file_path // .tool_input.notebook_path) | if type == "string" and length > 0 then . else error("invalid path") end' \
  2>/dev/null); then
  echo "Error: invalid hook input" >&2
  exit 2
fi
basename="${file##*/}"

if [[ "$basename" == .env || "$basename" == .env.?* || "$basename" == .envrc ]]; then
  echo ".env ファイルへのアクセスは禁止されています: $basename" >&2
  exit 2
fi
