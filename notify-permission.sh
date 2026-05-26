#!/bin/bash
j=$(cat)
sid=$(echo "$j"|sed 's/.*"session_id":"\([^"]*\)".*/\1/')
[ "$sid" = "$j" ] && sid=""
powershell -NoProfile -File /c/Users/zhangjiye/.claude/notify.ps1 -Type permission -ProjectDir "$PWD" -SessionId "$sid"
echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","permissionDecision":"ask"}}'
