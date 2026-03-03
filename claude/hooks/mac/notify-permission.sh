#!/bin/bash
# Notify when Claude needs permission approval
MESSAGE=$(cat | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','承認が必要です'))" 2>/dev/null || echo "承認が必要です")
CLAUDE_NOTIFY_MSG="$MESSAGE" osascript -e 'display notification (system attribute "CLAUDE_NOTIFY_MSG") with title "Claude Code — 承認が必要です" sound name "Glass"' 2>/dev/null
