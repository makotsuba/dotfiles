#!/bin/bash
# メッセージは文字列だけを採用し、不正な入力では既定文を使う。
MESSAGE='承認が必要です'
if command -v jq >/dev/null 2>&1; then
    MESSAGE=$(jq -ers '
        (if length == 1 and (.[0] | type == "object") then .[0].message else null end)
        | if type == "string" and length > 0 then . else "承認が必要です" end
    ' 2>/dev/null) || MESSAGE='承認が必要です'
else
    cat >/dev/null 2>&1 || exit 0
fi

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || \
    { [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; } || \
    ! command -v notify-send >/dev/null 2>&1; then
    exit 0
fi

# -- と引用によって、本文を option や shell command として扱わせない。
notify-send --app-name='Claude Code' -- 'Claude Code — 承認が必要です' "$MESSAGE" >/dev/null 2>&1 || :
exit 0
