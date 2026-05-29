#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUEUE_DIR="$HOME/.claude/notify-queue"
mkdir -p "$QUEUE_DIR"

j=$(cat)
sid=$(echo "$j"|sed 's/.*"session_id":"\([^"]*\)".*/\1/')
[ "$sid" = "$j" ] && sid=""

# 写入触发文件（守护进程消费）
echo "{\"type\":\"stop\",\"projectDir\":\"$PWD\",\"sessionId\":\"$sid\"}" > "$QUEUE_DIR/stop-$(date +%s%N).json"

# 检测守护进程是否存活
PID_FILE="$HOME/.claude/notify-daemon.pid"
DAEMON_ALIVE=false
if [ -f "$PID_FILE" ]; then
    DAEMON_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$DAEMON_PID" ] && powershell -NoProfile -Command "Get-Process -Id $DAEMON_PID -ErrorAction SilentlyContinue" >/dev/null 2>&1; then
        DAEMON_ALIVE=true
    fi
fi

# 降级：守护进程不在，直接调 PowerShell 弹窗
if [ "$DAEMON_ALIVE" = false ]; then
    if [ -n "$sid" ]; then
        powershell -NoProfile -Command "\$a=@('-NoProfile','-File','$SCRIPT_DIR/notify.ps1','-Type','stop','-ProjectDir','$PWD','-SessionId','$sid'); Start-Process -WindowStyle Hidden -FilePath powershell -ArgumentList \$a"
    else
        powershell -NoProfile -Command "\$a=@('-NoProfile','-File','$SCRIPT_DIR/notify.ps1','-Type','stop','-ProjectDir','$PWD'); Start-Process -WindowStyle Hidden -FilePath powershell -ArgumentList \$a"
    fi
fi
