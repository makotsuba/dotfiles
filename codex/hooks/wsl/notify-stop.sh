#!/bin/bash
# Notify when Codex finishes a task
pwsh.exe -Command "Import-Module BurntToast; New-BurntToastNotification -Text 'Codex', 'Task finished'" 2>/dev/null
