# CLAUDE.md

ClaudeNotify — 可复用的 Claude Code 桌面通知系统。

## 项目说明

为 Claude Code 提供 WPF 桌面弹窗通知 + StatusLine 会话名显示。

- **Stop 通知**：任务完成时右下角弹出绿色霓虹边框提示（5 秒自动消失）
- **Permission 通知**：权限确认时右下角弹出琥珀红色霓虹边框提示（8 秒自动消失）
- **StatusLine**：终端状态栏显示项目名、模型、上下文余量、会话名
- **会话名**：支持 `/rename` 命令、按 session_id 绑定、项目默认名三种方式

## 文件结构

```
ClaudeNotify/
├── .claude-plugin/
│   └── plugin.json          — 插件清单
├── hooks/
│   └── hooks.json           — Stop + PermissionRequest 钩子
├── scripts/
│   ├── notify.ps1           — WPF 弹窗核心（PowerShell，需 UTF-8 BOM）
│   ├── notify-stop.sh       — Stop hook 入口
│   ├── notify-permission.sh — Permission hook 入口
│   └── status.sh            — StatusLine 脚本
├── install.sh               — 传统安装（复制到 ~/.claude/ + 配置 settings.json）
├── install-statusline.sh    — 独立安装 statusLine 到 settings.json
├── CLAUDE.md                — 本文件
├── README.md
└── .gitignore
```

## 依赖

- Windows 10/11
- PowerShell 5.x+
- Git Bash（或兼容 bash 环境）
- Python 3.12+（用于 session-names.json 读写）

## 安装方式

### Plugin（推荐）

```
/plugin install github.com/ZEROpioneer/ClaudeNotify
```

Hooks 自动生效。StatusLine 需额外执行 `bash install-statusline.sh`。

### 传统

```bash
bash install.sh
```

安装后重启 Claude Code 即可生效。

## 部署原理

- **Plugin 方式**：hooks 随插件启用自动注册，路径通过 `${CLAUDE_PLUGIN_ROOT}` 引用脚本
- **传统方式**：安装脚本将脚本文件复制到 `~/.claude/`，并在 `~/.claude/settings.json` 中配置全局 hooks 和 statusLine。所有项目自动继承

## 语言偏好

始终使用中文与用户交流。
