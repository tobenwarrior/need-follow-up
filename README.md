# Telegram Notifier for Claude Code

Get Telegram notifications when Claude needs approval or finishes tasks. Never come back from a break to find Claude waiting for you!

## Features

- **📱 Instant notifications** — Get pinged on Telegram when Claude needs approval
- **📁 Project identification** — Messages include the project/folder name
- **🔍 Detailed context** — See exactly what Claude wants to do (commands, files, etc.)
- **✅ Task completion** — Know when Claude finishes
- **🖥️ Cross-platform** — Works on macOS, Linux, and WSL

## What It Does

When Claude needs permission, you get a Telegram message like:

```
📁 my-project

💻 Claude wants to run a command

npm install some-package

⏰ Go to terminal to approve
```

The **project name** (folder name) is included so you know which project needs attention — useful when you have multiple projects connected to the same bot!

## Prerequisites

You need `jq` installed:

**Ubuntu/Debian/WSL:**
```bash
sudo apt-get install -y jq
```

**macOS:**
```bash
brew install jq
```

**Fedora/RHEL:**
```bash
sudo dnf install jq
```

## Installation

```bash
# Add the marketplace
/plugin marketplace add https://github.com/herbalclaw/need-follow-up

# Install the plugin
/plugin install telegram-notifier@lucas-plugins
```

Then restart Claude Code.

## Setup

### 1. Create a Telegram Bot

1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot` and follow the instructions
3. Save your **bot token** (looks like `123456789:ABCdefGHIjklMNOpqrSTUvwxyz`)
4. Send `/start` to your new bot

### 2. Get Your Chat ID

1. Message [@userinfobot](https://t.me/userinfobot) on Telegram
2. It will reply with your user info including your **Chat ID** (a number like `123456789`)

### 3. Configure Environment Variables

Add to your shell profile (`.zshrc`, `.bashrc`, etc.):

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

Then restart your terminal or run `source ~/.zshrc` (or `~/.bashrc`).

## Multi-Project Support

You can connect multiple projects to the same Telegram bot. Each notification includes the **project name** (the folder name where you started Claude Code):

```
📁 frontend-app
💻 Claude wants to run a command...
```

```
📁 backend-api
📝 Claude wants to create a file...
```

This way you know exactly which project needs your attention!

## Platform Support

| Platform | Status |
|----------|--------|
| macOS | ✅ Supported |
| Linux | ✅ Supported |
| WSL | ✅ Supported |

## Notification Types

**Permission Required:**
```
📁 my-project

💻 Claude wants to run a command

npm install some-package

⏰ Go to terminal to approve
```

**Task Complete:**
```
📁 my-project

✅ Claude finished

Your request has been completed. Check the terminal for details.
```

## How It Works

The plugin uses Claude Code's hook system:

| Hook | When It Fires |
|------|---------------|
| `PermissionRequest` | Before file edits, bash commands, etc. |
| `Notification` | Permission prompts, idle prompts |
| `Stop` | When Claude finishes responding |

The **project name** is determined from the current working directory (`$PWD`) where Claude Code was started.

**Note:** Claude Code's PermissionRequest hook is **notification-only** — it can tell you something is waiting, but you still need to go back to the terminal to approve/deny. This plugin ensures you know when to come back!

## Troubleshooting

**Not receiving notifications?**
1. Check that `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are set
2. Make sure you sent `/start` to your bot on Telegram
3. Restart Claude Code after installing the plugin

**Want to disable completion notifications?**
```bash
export TELEGRAM_NOTIFY_COMPLETION="false"
```

## License

MIT
