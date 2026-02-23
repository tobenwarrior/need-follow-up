# Claude Code Telegram Notifier

A Claude Code CLI plugin that sends you Telegram notifications when:
- Claude needs your approval to proceed
- A task/prompt has been completed
- Claude has been thinking for a while and wants to check in

Never come back from a 15-minute break just to find Claude waiting for you to type "yes"!

## Installation

```bash
# Install the plugin
npm install -g claude-code-telegram-notifier

# Or install locally in your project
npm install claude-code-telegram-notifier
```

## Setup

### 1. Create a Telegram Bot

1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot` and follow the instructions
3. Save your **bot token** (looks like `123456789:ABCdefGHIjklMNOpqrSTUvwxyz`)
4. Send `/start` to your new bot

### 2. Get Your Chat ID

1. Message [@userinfobot](https://t.me/userinfobot) on Telegram
2. It will reply with your user info including your **Chat ID** (a number like `123456789`)

### 3. Configure Claude Code

Add to your `~/.claude-code/config.json`:

```json
{
  "plugins": [
    {
      "name": "claude-code-telegram-notifier",
      "config": {
        "botToken": "YOUR_BOT_TOKEN",
        "chatId": "YOUR_CHAT_ID",
        "notifyOnApproval": true,
        "notifyOnCompletion": true,
        "notifyOnLongThinking": true,
        "longThinkingThresholdMinutes": 5
      }
    }
  ]
}
```

Or set environment variables:

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `botToken` | string | (required) | Your Telegram bot token from BotFather |
| `chatId` | string | (required) | Your Telegram chat ID |
| `notifyOnApproval` | boolean | `true` | Send notification when approval is needed |
| `notifyOnCompletion` | boolean | `true` | Send notification when task completes |
| `notifyOnLongThinking` | boolean | `true` | Send notification when thinking exceeds threshold |
| `longThinkingThresholdMinutes` | number | `5` | Minutes before "long thinking" notification |
| `includeContext` | boolean | `true` | Include task context in notifications |
| `quietHoursStart` | string | `null` | Start of quiet hours (24h format, e.g., "22:00") |
| `quietHoursEnd` | string | `null` | End of quiet hours (e.g., "08:00") |

## Usage

Once installed and configured, the plugin works automatically. You'll receive Telegram messages like:

**Approval Needed:**
> ⏸️ **Claude needs approval**
> 
> Task: *"Refactor the authentication module"*
> 
> Claude wants to: `Delete file src/auth/old.ts`
> 
> Reply with: ✅ Approve | ❌ Deny | 💬 Ask

**Task Completed:**
> ✅ **Task Complete**
> 
> Task: *"Refactor the authentication module"*
> 
> Duration: 12 minutes
> Files changed: 5
> 
> [View Summary]

**Long Thinking Check-in:**
> 🤔 **Still working...**
> 
> Task: *"Analyze the codebase"*
> 
> Claude has been thinking for 8 minutes. Everything is proceeding normally.

## Reply Commands

When you receive an approval notification, you can reply with:

- `yes`, `y`, `approve`, `✅` - Approve the action
- `no`, `n`, `deny`, `❌` - Deny the action
- Any other text - Claude will see it as a message

## Development

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/need-follow-up.git
cd need-follow-up

# Install dependencies
npm install

# Build
npm run build

# Watch mode
npm run dev
```

## How It Works

The plugin hooks into Claude Code's event system:

1. **Approval Events**: When Claude needs permission (file edits, command execution, etc.)
2. **Completion Events**: When a prompt finishes executing
3. **Heartbeat Events**: Periodic checks for long-running tasks

It sends these as Telegram messages via the Bot API, and can receive your replies to control Claude.

## License

MIT
