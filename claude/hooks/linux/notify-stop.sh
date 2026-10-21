#!/bin/bash
# stdin を消費し、デスクトップ環境がある場合だけ完了を通知する。
cat >/dev/null 2>&1 || exit 0

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || \
    { [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; } || \
    ! command -v notify-send >/dev/null 2>&1; then
    exit 0
fi

notify-send --app-name='Claude Code' -- 'Claude Code' 'タスクが完了しました' >/dev/null 2>&1 || :
exit 0
