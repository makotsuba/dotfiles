#!/bin/bash
# GUI や通知サービスを利用できない環境では静かに省略する。
cat >/dev/null 2>&1 || exit 0

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || \
    { [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; } || \
    ! command -v notify-send >/dev/null 2>&1; then
    exit 0
fi

notify-send --app-name='Claude Code' -- 'Claude Code' '入力待ちです' >/dev/null 2>&1 || :
exit 0
