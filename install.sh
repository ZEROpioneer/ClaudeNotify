#!/bin/bash
# ClaudeNotify 一键安装脚本
# 将通知系统部署到 ~/.claude/ 并配置全局 hooks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== ClaudeNotify 安装 ==="

# 1. 复制脚本到 ~/.claude/
echo "[1/5] 复制脚本文件..."
cp "$SCRIPT_DIR/scripts/notify.ps1" "$CLAUDE_DIR/notify.ps1"
cp "$SCRIPT_DIR/scripts/notify-daemon.ps1" "$CLAUDE_DIR/notify-daemon.ps1"
cp "$SCRIPT_DIR/scripts/notify-stop.sh" "$CLAUDE_DIR/notify-stop.sh"
cp "$SCRIPT_DIR/scripts/notify-permission.sh" "$CLAUDE_DIR/notify-permission.sh"
cp "$SCRIPT_DIR/scripts/status.sh" "$CLAUDE_DIR/status.sh"

# 2. 赋予执行权限
echo "[2/5] 设置执行权限..."
chmod +x "$CLAUDE_DIR/notify-stop.sh" "$CLAUDE_DIR/notify-permission.sh" "$CLAUDE_DIR/status.sh"

# 3. 启动常驻守护进程（关键：避免每次弹窗冷启动 WPF）
echo "[3/5] 启动通知守护进程..."
# 杀掉旧实例（通过 PID 文件）
powershell -Command "\$pidFile = \"\$env:USERPROFILE\\.claude\\notify-daemon.pid\"; if (Test-Path \$pidFile) { try { \$oldPid = [int](Get-Content \$pidFile -Raw); Stop-Process -Id \$oldPid -Force -ErrorAction Stop; Write-Host '  Stopped old daemon' } catch {}; Remove-Item \$pidFile -Force }" 2>/dev/null
# 用 Start-Process 启动独立后台进程，不受父进程退出影响
powershell -Command "Start-Process -WindowStyle Hidden -FilePath powershell -ArgumentList '-NoProfile', '-File', '$CLAUDE_DIR/notify-daemon.ps1'"
echo "  守护进程已启动"

# 4. 检测 Python（用于合并 JSON）
echo "[4/5] 配置全局 settings.json..."
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
  echo "警告: 未找到 Python，跳过 settings.json 合并，请手动配置"
else
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

# 添加 statusLine
settings['statusLine'] = {
    'type': 'command',
    'command': 'bash ~/.claude/status.sh',
    'refreshInterval': 30
}

# 添加 hooks（仅覆盖 Stop 和 PermissionRequest，保留其他 hooks）
if 'hooks' not in settings:
    settings['hooks'] = {}

settings['hooks']['Stop'] = [{
    'hooks': [{
        'type': 'command',
        'command': 'bash ~/.claude/notify-stop.sh',
        'timeout': 15,
        'async': True
    }]
}]

settings['hooks']['PermissionRequest'] = [{
    'hooks': [{
        'type': 'command',
        'command': 'bash ~/.claude/notify-permission.sh',
        'timeout': 15,
        'async': True
    }]
}]

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
print('settings.json 已更新')
"
fi

echo "[5/5] 完成！"
echo ""
echo "ClaudeNotify 已安装到 $CLAUDE_DIR"
echo "守护进程已在后台运行，重启 Claude Code 使 hooks 生效。"
echo ""
echo "如果重启电脑，需重新启动守护进程："
echo "  powershell -WindowStyle Hidden -File $CLAUDE_DIR/notify-daemon.ps1"
echo ""
echo "项目级配置（可选）："
echo "  .claude/session-name.txt    项目默认会话名"
echo "  .claude/session-names.json  各 session 绑定名（自动维护）"
