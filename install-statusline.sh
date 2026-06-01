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
echo "[2/4] 启动通知守护进程..."
# 停止旧实例
if [ -f "$CLAUDE_DIR/notify-daemon.pid" ]; then
    OLD_PID=$(cat "$CLAUDE_DIR/notify-daemon.pid" 2>/dev/null)
    if [ -n "$OLD_PID" ] && powershell -NoProfile -Command "Get-Process -Id $OLD_PID -ErrorAction SilentlyContinue" >/dev/null 2>&1; then
        powershell -Command "Stop-Process -Id $OLD_PID -Force -ErrorAction SilentlyContinue" 2>/dev/null
        echo "  已停止旧守护进程"
    fi
    rm -f "$CLAUDE_DIR/notify-daemon.pid"
fi
# 启动新守护进程（Start-Process 确保不受父进程退出影响）
powershell -Command "Start-Process -FilePath powershell -ArgumentList '-WindowStyle','Hidden','-NoProfile','-File','$CLAUDE_DIR/notify-daemon.ps1'"
sleep 1
# 验证启动成功
if [ -f "$CLAUDE_DIR/notify-daemon.pid" ]; then
    NEW_PID=$(cat "$CLAUDE_DIR/notify-daemon.pid" 2>/dev/null)
    if [ -n "$NEW_PID" ] && powershell -NoProfile -Command "Get-Process -Id $NEW_PID -ErrorAction SilentlyContinue" >/dev/null 2>&1; then
        echo "  守护进程已启动 (PID $NEW_PID)"
    else
        echo "  警告: 守护进程启动失败，将使用降级弹窗模式"
    fi
else
    echo "  警告: 守护进程启动失败，将使用降级弹窗模式"
fi

# 3. 配置开机自启
echo "[3/4] 配置开机自启..."
# 清理旧注册表方式
powershell -NoProfile -Command "Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'ClaudeNotify' -ErrorAction SilentlyContinue"

# 创建无窗口启动 VBS
cat > "$CLAUDE_DIR/notify-start.vbs" << 'VBSCRIPT'
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -WindowStyle Hidden -File """ & CreateObject("WScript.Shell").ExpandEnvironmentStrings("%USERPROFILE%") & "\.claude\notify-daemon.ps1""", 0, False
VBSCRIPT

# 创建 Startup 文件夹快捷方式
powershell -NoProfile -Command "
\$startupDir = [Environment]::GetFolderPath('Startup')
\$WshShell = New-Object -ComObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut(\"\$startupDir\ClaudeNotify.lnk\")
\$Shortcut.TargetPath = '$CLAUDE_DIR/notify-start.vbs'
\$Shortcut.WindowStyle = 7
\$Shortcut.Save()
"
echo "  已添加到启动文件夹"

# 4. 检测 Python 并配置 settings.json
echo "[4/4] 配置 statusLine..."
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
echo "StatusLine 已安装，守护进程已启动，已配置开机自启。"
echo "重启 Claude Code 生效。"
