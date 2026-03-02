#!/bin/bash
# Notify when Claude finishes a task
osascript -e 'display notification "Task finished" with title "Claude Code"' 2>/dev/null
