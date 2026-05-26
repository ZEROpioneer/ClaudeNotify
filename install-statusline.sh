#!/bin/bash
# ClaudeNotify StatusLine + 守护进程安装脚本
# 部署 status.sh、notify-daemon.ps1 到 ~/.claude/，配置 statusLine 并启动守护进程

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== ClaudeNotify StatusLine + 守护进程安装 ==="

# 1. 复制脚本到 ~/.claude/
echo "[1/3] 复制脚本..."
cp "$SCRIPT_DIR/scripts/status.sh" "$CLAUDE_DIR/status.sh"
cp "$SCRIPT_DIR/scripts/notify-daemon.ps1" "$CLAUDE_DIR/notify-daemon.ps1"
chmod +x "$CLAUDE_DIR/status.sh"

# 2. 启动守护进程
echo "[2/3] 启动通知守护进程..."
# 杀掉旧实例（通过 PID 文件）
powershell -Command "\$pidFile = \"\$env:USERPROFILE\\.claude\\notify-daemon.pid\"; if (Test-Path \$pidFile) { try { \$oldPid = [int](Get-Content \$pidFile -Raw); Stop-Process -Id \$oldPid -Force -ErrorAction Stop; Write-Host '  Stopped old daemon' } catch {}; Remove-Item \$pidFile -Force }" 2>/dev/null
powershell -Command "Start-Process -WindowStyle Hidden -FilePath powershell -ArgumentList '-NoProfile', '-File', '$CLAUDE_DIR/notify-daemon.ps1'"
echo "  守护进程已启动"

# 3. 检测 Python 并配置 settings.json
echo "[3/3] 配置 statusLine..."
PY=""
if [ -n "$PYTHON_PATH" ] && command -v "$PYTHON_PATH" >/dev/null 2>&1; then
  PY="$PYTHON_PATH"
elif command -v python3 >/dev/null 2>&1; then
  PY="python3"
elif command -v python >/dev/null 2>&1; then
  PY="python"
else
  for py_path in \
    "$HOME/AppData/Local/Programs/Python/Python314/python.exe" \
    "$HOME/AppData/Local/Programs/Python/Python313/python.exe" \
    "$HOME/AppData/Local/Programs/Python/Python312/python.exe" \
    "/c/Python314/python.exe" \
    "/c/Python313/python.exe"; do
    if [ -f "$py_path" ]; then PY="$py_path"; break; fi
  done
fi

if [ -z "$PY" ]; then
  echo "警告: 未找到 Python，请手动在 ~/.claude/settings.json 中添加 statusLine 配置"
  exit 1
fi

$PY -c "
import json, os

settings_path = os.path.expanduser('~/.claude/settings.json')

settings = {}
if os.path.exists(settings_path):
    with open(settings_path, 'r', encoding='utf-8') as f:
        try:
            settings = json.load(f)
        except:
            settings = {}

settings['statusLine'] = {
    'type': 'command',
    'command': 'bash ~/.claude/status.sh',
    'refreshInterval': 30
}

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
print('statusLine 已配置')
"

echo ""
echo "StatusLine 已安装，守护进程已启动，重启 Claude Code 生效。"
echo ""
echo "重启电脑后需重新启动守护进程："
echo "  powershell -WindowStyle Hidden -File $CLAUDE_DIR/notify-daemon.ps1"
