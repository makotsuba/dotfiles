#!/bin/bash
# Notify when Claude finishes a task
pwsh.exe -Command "Import-Module BurntToast; New-BurntToastNotification -Text 'Claude Code', 'Task finished'" 2>/dev/null
