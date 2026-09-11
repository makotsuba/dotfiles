#!/bin/bash
# PreToolUse hook: block Bash commands that access .env / .envrc files
# NOTE: This covers shell-based access (cat, vim, echo >, source, etc.).
#       Native file tool interception is not supported by Codex PreToolUse.

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required by the .env access guard" >&2
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

# Strip quote characters so 'cat ".env"' and "cat '.env'" are also caught
stripped=$(printf '%s' "$command" | tr -d "'\"\`")

# Match .env, .env.local, .env.production, .envrc, and shell glob forms such
# as .env.* while excluding longer identifiers such as .environment or .envbin.
DOT_ENV_FILE_PATTERN='(^|[^a-zA-Z0-9_.-])\.env(rc|(\.[a-zA-Z0-9_-]+)+)?([^a-zA-Z0-9_.-]|$)'
DOT_ENV_GLOB_PATTERN='(^|[^a-zA-Z0-9_.-])\.env(\.[*?]|\.[[]|[*?]|[[])'

for check in "$command" "$stripped"; do
  if printf '%s\n' "$check" | grep -qE "$DOT_ENV_FILE_PATTERN|$DOT_ENV_GLOB_PATTERN"; then
    echo ".env ファイルへのアクセスは禁止されています" >&2
    exit 2
  fi
done
