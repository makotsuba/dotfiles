#!/bin/bash
# PreToolUse hook: block Bash commands that access .env / .envrc files
# NOTE: This covers shell-based access (cat, vim, echo >, source, etc.).
#       Native file tool interception is not supported by Codex PreToolUse.

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Strip quote characters so 'cat ".env"' and "cat '.env'" are also caught
stripped=$(printf '%s' "$command" | tr -d "'\"\`")

# Match .env, .env.local, .env.production, .envrc etc. as standalone tokens
# (not substrings of longer identifiers like .envbin)
DOT_ENV_PATTERN='(^|[[:space:];|&<>!/])\.env(rc|\.[a-zA-Z0-9_]+)?([[:space:];|&<>!]|$)'

for check in "$command" "$stripped"; do
  if echo "$check" | grep -qE "$DOT_ENV_PATTERN"; then
    echo ".env ファイルへのアクセスは禁止されています" >&2
    exit 2
  fi
done
