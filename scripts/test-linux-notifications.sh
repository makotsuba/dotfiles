#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="${TEST_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-linux-notifications.XXXXXX")}"
if [ ! -d "$TEST_ROOT" ] || [ -n "$(find "$TEST_ROOT" -mindepth 1 -print -quit)" ]; then
    echo "Error: TEST_ROOT must be an empty directory: $TEST_ROOT" >&2
    exit 1
fi

JQ_BIN=$(command -v jq)
MOCK_BIN="$TEST_ROOT/mock-bin"
NO_NOTIFY_BIN="$TEST_ROOT/no-notify-bin"
NO_JQ_BIN="$TEST_ROOT/no-jq-bin"
mkdir -p "$MOCK_BIN" "$NO_NOTIFY_BIN" "$NO_JQ_BIN" "$TEST_ROOT/claude-hooks" "$TEST_ROOT/codex-hooks"
for bin in "$MOCK_BIN" "$NO_NOTIFY_BIN" "$NO_JQ_BIN"; do
    ln -s "$(command -v cat)" "$bin/cat"
done
ln -s "$JQ_BIN" "$MOCK_BIN/jq"
ln -s "$JQ_BIN" "$NO_NOTIFY_BIN/jq"

# 実際の desktop 通知は送らず、引数境界と service 失敗を記録する。
cat > "$MOCK_BIN/notify-send" <<'MOCK'
#!/bin/bash
printf '%s\0' "$@" > "$NOTIFY_TEST_ARGS"
exit "${NOTIFY_TEST_EXIT:-0}"
MOCK
chmod +x "$MOCK_BIN/notify-send"
ln -s "$MOCK_BIN/notify-send" "$NO_JQ_BIN/notify-send"

for hook in notify-stop notify-idle notify-permission; do
    test -x "$DOTFILES_DIR/claude/hooks/linux/$hook.sh"
    ln -s "$DOTFILES_DIR/claude/hooks/linux/$hook.sh" "$TEST_ROOT/claude-hooks/$hook.sh"
done
test -x "$DOTFILES_DIR/codex/hooks/linux/notify-stop.sh"
ln -s "$DOTFILES_DIR/codex/hooks/linux/notify-stop.sh" "$TEST_ROOT/codex-hooks/notify-stop.sh"

CASE_NUMBER=0
LAST_ARGS=''
invoke_hook() {
    local hook="$1" payload="$2" display="$3" wayland="$4" bus="$5" bin="$6" notify_exit="${7:-0}"
    CASE_NUMBER=$((CASE_NUMBER + 1))
    LAST_ARGS="$TEST_ROOT/case-$CASE_NUMBER-args"
    printf '%s' "$payload" | /usr/bin/env -i \
        PATH="$bin" DISPLAY="$display" WAYLAND_DISPLAY="$wayland" DBUS_SESSION_BUS_ADDRESS="$bus" \
        NOTIFY_TEST_ARGS="$LAST_ARGS" NOTIFY_TEST_EXIT="$notify_exit" \
        /bin/bash "$hook" > "$TEST_ROOT/case-$CASE_NUMBER-out" 2> "$TEST_ROOT/case-$CASE_NUMBER-err"
    test ! -s "$TEST_ROOT/case-$CASE_NUMBER-out"
    test ! -s "$TEST_ROOT/case-$CASE_NUMBER-err"
}

assert_args() {
    local app="$1" title="$2" body="$3"
    printf '%s\0' "--app-name=$app" -- "$title" "$body" > "$TEST_ROOT/expected-args"
    cmp "$TEST_ROOT/expected-args" "$LAST_ARGS"
}

for hook in "$TEST_ROOT/claude-hooks/notify-stop.sh" \
            "$TEST_ROOT/claude-hooks/notify-idle.sh" \
            "$TEST_ROOT/claude-hooks/notify-permission.sh" \
            "$TEST_ROOT/codex-hooks/notify-stop.sh"; do
    invoke_hook "$hook" '{}' '' '' '' "$MOCK_BIN"
    test ! -e "$LAST_ARGS"
    invoke_hook "$hook" '{}' ':1' '' '' "$MOCK_BIN"
    test ! -e "$LAST_ARGS"
    invoke_hook "$hook" '{}' '' '' 'unix:path=/mock/bus' "$MOCK_BIN"
    test ! -e "$LAST_ARGS"
    invoke_hook "$hook" '{}' ':1' '' 'unix:path=/mock/bus' "$NO_NOTIFY_BIN"
    test ! -e "$LAST_ARGS"
    invoke_hook "$hook" '{}' ':1' '' 'unix:path=/mock/bus' "$MOCK_BIN" 1
    test -s "$LAST_ARGS"
done

invoke_hook "$TEST_ROOT/claude-hooks/notify-stop.sh" '{}' ':1' '' 'unix:path=/mock/bus' "$MOCK_BIN"
assert_args 'Claude Code' 'Claude Code' 'タスクが完了しました'
invoke_hook "$TEST_ROOT/claude-hooks/notify-idle.sh" '{}' '' 'wayland-0' 'unix:path=/mock/bus' "$MOCK_BIN"
assert_args 'Claude Code' 'Claude Code' '入力待ちです'
invoke_hook "$TEST_ROOT/codex-hooks/notify-stop.sh" '{}' ':1' '' 'unix:path=/mock/bus' "$MOCK_BIN"
assert_args 'Codex' 'Codex' 'タスクが完了しました'

# 先頭の --、quote、改行、command substitution を本文のまま渡す。
special_message=$(printf '%s\n%s' '--urgency=critical "quoted"' "\$(touch '$TEST_ROOT/should-not-exist')")
payload=$("$JQ_BIN" -n --arg message "$special_message" '{message:$message}')
invoke_hook "$TEST_ROOT/claude-hooks/notify-permission.sh" "$payload" ':1' '' 'unix:path=/mock/bus' "$MOCK_BIN"
assert_args 'Claude Code' 'Claude Code — 承認が必要です' "$special_message"
test ! -e "$TEST_ROOT/should-not-exist"

for payload in '' '{}' '{' '{"message":null}' '{"message":123}' '{"message":[]}' '{"message":""}' '[]' '{"message":"one"} {"message":"two"}'; do
    invoke_hook "$TEST_ROOT/claude-hooks/notify-permission.sh" "$payload" ':1' '' 'unix:path=/mock/bus' "$MOCK_BIN"
    assert_args 'Claude Code' 'Claude Code — 承認が必要です' '承認が必要です'
done
invoke_hook "$TEST_ROOT/claude-hooks/notify-permission.sh" '{}' ':1' '' 'unix:path=/mock/bus' "$NO_JQ_BIN"
assert_args 'Claude Code' 'Claude Code — 承認が必要です' '承認が必要です'

echo 'Linux notification mock tests passed; desktop delivery was not tested.'
echo "TEST_ROOT is retained for inspection: $TEST_ROOT"
