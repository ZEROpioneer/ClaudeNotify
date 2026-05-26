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
├── README.md              — 使用说明
├── notify.ps1             — WPF 弹窗核心（PowerShell，需 UTF-8 BOM）
├── notify-stop.sh          — Stop hook 入口
├── notify-permission.sh    — Permission hook 入口
├── status.sh               — StatusLine 脚本
├── install.sh              — 一键安装到 ~/.claude/
├── CLAUDE.md               — 本文件
└── .gitignore
```

## 依赖

- Windows 10/11
- PowerShell 5.x+
- Git Bash（或兼容 bash 环境）
- Python 3.12+（用于 session-names.json 读写）

## 安装方式

```bash
bash install.sh
```

安装后重启 Claude Code 即可生效。

## 部署原理

安装脚本将脚本文件复制到 `~/.claude/`，并在 `~/.claude/settings.json` 中配置全局 hooks 和 statusLine。所有项目自动继承。

## 语言偏好

始终使用中文与用户交流。
