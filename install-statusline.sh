#!/bin/bash
# ClaudeNotify StatusLine 安装脚本
# 将 status.sh 部署到 ~/.claude/ 并配置 statusLine

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== ClaudeNotify StatusLine 安装 ==="

# 1. 复制 status.sh 到 ~/.claude/
echo "[1/2] 复制 status.sh..."
cp "$SCRIPT_DIR/scripts/status.sh" "$CLAUDE_DIR/status.sh"
chmod +x "$CLAUDE_DIR/status.sh"

# 2. 检测 Python 并配置 settings.json
echo "[2/2] 配置 statusLine..."
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
echo "StatusLine 已安装，重启 Claude Code 生效。"
