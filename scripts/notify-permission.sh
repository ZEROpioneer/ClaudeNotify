#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUEUE_DIR="$HOME/.claude/notify-queue"
mkdir -p "$QUEUE_DIR"

j=$(cat)
sid=$(echo "$j"|sed 's/.*"session_id":"\([^"]*\)".*/\1/')
[ "$sid" = "$j" ] && sid=""

# 写入触发文件（守护进程消费）
echo "{\"type\":\"permission\",\"projectDir\":\"$PWD\",\"sessionId\":\"$sid\"}" > "$QUEUE_DIR/perm-$(date +%s%N).json"

# 检测守护进程是否存活
PID_FILE="$HOME/.claude/notify-daemon.pid"
DAEMON_ALIVE=false
if [ -f "$PID_FILE" ]; then
    DAEMON_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$DAEMON_PID" ] && kill -0 "$DAEMON_PID" 2>/dev/null; then
        DAEMON_ALIVE=true
    fi
fi

# 降级：守护进程不在，直接调 PowerShell 弹窗
if [ "$DAEMON_ALIVE" = false ]; then
    powershell -NoProfile -File "$SCRIPT_DIR/notify.ps1" -Type permission -ProjectDir "$PWD" -SessionId "$sid"
fi

echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","permissionDecision":"ask"}}'
