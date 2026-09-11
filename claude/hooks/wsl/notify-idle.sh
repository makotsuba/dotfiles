#!/bin/bash
# Notify when Claude has been idle waiting for input
pwsh.exe -Command "Import-Module BurntToast; New-BurntToastNotification -Text 'Claude Code', '入力待ちです' -Sound IM" 2>/dev/null
