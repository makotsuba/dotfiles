#!/bin/bash
# PreToolUse hook: block Read/Edit/Write/MultiEdit/NotebookEdit access to .env files

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

input=$(cat)
# file_path: Read/Edit/Write/MultiEdit, notebook_path: NotebookEdit
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
basename=$(basename "$file")

if [[ "$basename" == .env || "$basename" == .env.?* || "$basename" == .envrc ]]; then
  echo ".env ファイルへのアクセスは禁止されています: $basename" >&2
  exit 2
fi
