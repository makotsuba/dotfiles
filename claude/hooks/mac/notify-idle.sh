#!/bin/bash
# Notify when Claude has been idle waiting for input
osascript -e 'display notification "入力待ちです" with title "Claude Code"' 2>/dev/null
