#!/bin/bash
# ClaudeNotify 一键安装脚本
# 将通知系统部署到 ~/.claude/ 并配置全局 hooks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== ClaudeNotify 安装 ==="

# 1. 复制脚本到 ~/.claude/
echo "[1/4] 复制脚本文件..."
cp "$SCRIPT_DIR/notify.ps1" "$CLAUDE_DIR/notify.ps1"
cp "$SCRIPT_DIR/notify-stop.sh" "$CLAUDE_DIR/notify-stop.sh"
cp "$SCRIPT_DIR/notify-permission.sh" "$CLAUDE_DIR/notify-permission.sh"
cp "$SCRIPT_DIR/status.sh" "$CLAUDE_DIR/status.sh"

# 2. 赋予执行权限
echo "[2/4] 设置执行权限..."
chmod +x "$CLAUDE_DIR/notify-stop.sh" "$CLAUDE_DIR/notify-permission.sh" "$CLAUDE_DIR/status.sh"

# 3. 检测 Python（用于合并 JSON）
echo "[3/4] 配置全局 settings.json..."
PY=""
if [ -n "$PYTHON_PATH" ] && command -v "$PYTHON_PATH" >/dev/null 2>&1; then
  PY="$PYTHON_PATH"
elif command -v python3 >/dev/null 2>&1; then
  PY="python3"
elif command -v python >/dev/null 2>&1; then
  PY="python"
else
  for p in \
    "/c/Users/$USER/AppData/Local/Programs/Python/Python314/python.exe" \
    "/c/Users/$USER/AppData/Local/Programs/Python/Python313/python.exe" \
    "/c/Users/$USER/AppData/Local/Programs/Python/Python312/python.exe" \
    "/c/Python314/python.exe" \
    "/c/Python313/python.exe"; do
    if [ -f "$p" ]; then PY="$p"; break; fi
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

echo "[4/4] 完成！"
echo ""
echo "ClaudeNotify 已安装到 $CLAUDE_DIR"
echo "请重启 Claude Code 使配置生效。"
echo ""
echo "项目级配置（可选）："
echo "  .claude/session-name.txt    项目默认会话名"
echo "  .claude/session-names.json  各 session 绑定名（自动维护）"
