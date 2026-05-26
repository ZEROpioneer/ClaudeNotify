# ClaudeNotify

Claude Code 桌面通知系统 — WPF 弹窗 + StatusLine 会话名。

## 功能

| 功能 | 说明 |
|------|------|
| 任务完成通知 | 右下角绿色霓虹弹窗 + 提示音（5秒） |
| 权限确认通知 | 右下角琥珀红霓虹弹窗 + 提示音（8秒） |
| StatusLine | 状态栏显示项目名、模型、上下文余量、会话名 |
| 会话命名 | 支持 `/rename`、按 session 绑定、项目默认名 |
| 不抢焦点 | 弹窗出现不影响当前工作窗口 |

## 快速开始

### 方式一：Plugin 安装（推荐）

```
/plugin install github.com/ZEROpioneer/ClaudeNotify
```

Hooks（Stop/PermissionRequest 弹窗）自动生效。

StatusLine 需要额外一步：

```bash
git clone https://github.com/ZEROpioneer/ClaudeNotify.git
cd ClaudeNotify
bash install-statusline.sh
```

### 方式二：传统安装

```bash
git clone https://github.com/ZEROpioneer/ClaudeNotify.git
cd ClaudeNotify
bash install.sh
```

重启 Claude Code 即可。

## 项目级配置（可选）

在任意项目下创建：

```bash
# 默认会话名（优先级最低的兜底）
echo "我的项目" > .claude/session-name.txt
```

```bash
# 把当前会话绑定一个名字
echo "开发环境" > .claude/pending-name.txt
```

## 会话名优先级

1. `/rename` 命令设置的名称（最优先）
2. `.claude/session-names.json` 中按 session_id 绑定的名称
3. `.claude/session-name.txt` 项目默认名称（兜底）

## 自定义 Python 路径

如果 Python 不在 PATH 中，设置环境变量：

```bash
export PYTHON_PATH="/c/Users/你的用户名/AppData/Local/Programs/Python/Python314/python.exe"
```

## 系统要求

- Windows 10/11
- PowerShell 5.x+
- Git Bash
- Python 3.12+
