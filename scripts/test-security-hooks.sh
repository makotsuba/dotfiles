#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOOK="$DOTFILES_DIR/claude/hooks/common/block-dotenv.sh"
CODEX_HOOK="$DOTFILES_DIR/codex/hooks/common/block-dotenv-bash.sh"
RM_HOOK="$DOTFILES_DIR/claude/hooks/common/block-rm-rf.sh"

assert_blocked() {
    local hook="$1"
    local payload="$2"
    local status

    set +e
    printf '%s' "$payload" | "$hook" >/dev/null 2>&1
    status=$?
    set -e

    if [ "$status" -ne 2 ]; then
        echo "Assertion failed: expected hook to block with status 2: $hook" >&2
        exit 1
    fi
}

assert_allowed() {
    local hook="$1"
    local payload="$2"

    if ! printf '%s' "$payload" | "$hook" >/dev/null 2>&1; then
        echo "Assertion failed: expected hook to allow payload: $hook" >&2
        exit 1
    fi
}

assert_missing_jq_fails_closed() {
    local hook="$1"
    local status

    set +e
    printf '%s' '{"tool_input":{}}' | PATH=/nonexistent /bin/bash "$hook" >/dev/null 2>&1
    status=$?
    set -e

    if [ "$status" -ne 2 ]; then
        echo "Assertion failed: expected missing jq to fail closed: $hook" >&2
        exit 1
    fi
}

assert_blocked "$CLAUDE_HOOK" '{"tool_input":{"file_path":"/workspace/.env"}}'
assert_blocked "$CLAUDE_HOOK" '{"tool_input":{"file_path":"/workspace/.env.production.local"}}'
assert_blocked "$CLAUDE_HOOK" '{"tool_input":{"file_path":"/workspace/.env.local-test"}}'
assert_blocked "$CLAUDE_HOOK" '{"tool_input":{"notebook_path":"/workspace/.envrc"}}'
assert_allowed "$CLAUDE_HOOK" '{"tool_input":{"file_path":"/workspace/.environment"}}'

assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":"cat .env"}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":"cat ./config/.env.production.local"}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":"(cat .env.production.local)"}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":"source .env.local-test"}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":"printf x > .envrc"}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":"cat .env.*"}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":"cat .env*"}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":"cat .env.[a-z]*"}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":"cat .env[a-z]"}}'
assert_allowed "$CODEX_HOOK" '{"tool_input":{"command":"cat .environment"}}'
assert_allowed "$CODEX_HOOK" '{"tool_input":{"command":"echo .envbin"}}'

assert_blocked "$RM_HOOK" '{"tool_input":{"command":"rm -rf /tmp/example"}}'
assert_blocked "$RM_HOOK" '{"tool_input":{"command":"rm -fr /tmp/example"}}'
assert_allowed "$RM_HOOK" '{"tool_input":{"command":"rm /tmp/example"}}'

assert_missing_jq_fails_closed "$CLAUDE_HOOK"
assert_missing_jq_fails_closed "$CODEX_HOOK"
assert_missing_jq_fails_closed "$RM_HOOK"

assert_blocked "$CLAUDE_HOOK" '{'
assert_blocked "$CODEX_HOOK" '{'
assert_blocked "$RM_HOOK" '{'
assert_blocked "$CLAUDE_HOOK" '{"tool_input":{}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{}}'
assert_blocked "$RM_HOOK" '{"tool_input":{}}'
assert_blocked "$CLAUDE_HOOK" '{"tool_input":{"file_path":null}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":null}}'
assert_blocked "$RM_HOOK" '{"tool_input":{"command":null}}'
assert_blocked "$CLAUDE_HOOK" '{"tool_input":{"file_path":""}}'
assert_blocked "$CODEX_HOOK" '{"tool_input":{"command":""}}'
assert_blocked "$RM_HOOK" '{"tool_input":{"command":""}}'

echo "security hook tests passed"
