#!/bin/bash
# Notify when Claude needs permission approval
MESSAGE=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('message','承認が必要です'))" 2>/dev/null || echo "承認が必要です")
TOAST_MSG="$MESSAGE" pwsh.exe -Command "Import-Module BurntToast; New-BurntToastNotification -Text 'Claude Code — 承認が必要です', \$env:TOAST_MSG -Sound Reminder" 2>/dev/null
