#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
j=$(cat)
sid=$(echo "$j"|sed 's/.*"session_id":"\([^"]*\)".*/\1/')
[ "$sid" = "$j" ] && sid=""
powershell -NoProfile -File "$SCRIPT_DIR/notify.ps1" -Type stop -ProjectDir "$PWD" -SessionId "$sid"
