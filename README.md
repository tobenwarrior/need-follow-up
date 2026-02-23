# Telegram Notifier for Claude Code

Get Telegram notifications when Claude needs approval or finishes tasks. Never come back from a break to find Claude waiting for you to type "yes"!

## Installation

```bash
# Add the marketplace
/plugin marketplace add https://github.com/herbalclaw/need-follow-up

# Install the plugin
/plugin install telegram-notifier@lucas-plugins
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

### 3. Configure the Plugin

Add to your `~/.claude-code/config.json`:

```json
{
  "plugins": [
    {
      "name": "telegram-notifier",
      "config": {
        "botToken": "YOUR_BOT_TOKEN",
        "chatId": "YOUR_CHAT_ID",
        "notifyOnApproval": true,
        "notifyOnCompletion": true,
        "notifyOnLongThinking": true,
        "longThinkingThresholdMinutes": 5,
        "includeContext": true
      }
    }
  ]
}
```

Or use environment variables:

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
export TELEGRAM_NOTIFY_APPROVAL="true"
export TELEGRAM_NOTIFY_COMPLETION="true"
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

## Notifications You'll Receive

**Approval Needed:**
```
⏸️ Claude needs approval

Task: "Refactor the authentication module"

Action: `Delete file src/auth/old.ts`

Claude wants to remove the deprecated auth module.

Reply with: ✅ yes | ❌ no
```

**Task Completed:**
```
✅ Task Complete

Task: "Refactor the authentication module"

Duration: 12 min
Files changed: 5

_Migrated auth to new JWT-based system..._
```

**Long Thinking Check-in:**
```
🤔 Still working...

Task: "Analyze the codebase"

Claude has been thinking for 8 minutes. Everything is proceeding normally.
```

## Quiet Hours

Don't want notifications at night? Set quiet hours:

```json
{
  "quietHoursStart": "22:00",
  "quietHoursEnd": "08:00"
}
```

Notifications will be suppressed during these hours.

## How It Works

The plugin uses Claude Code's hook system:

- **`onApprovalRequired`** — Triggered when Claude needs permission
- **`onTaskComplete`** — Triggered when a prompt finishes
- **`onThinkingStart`** — Triggered during long-running tasks

Each hook sends a Telegram message via the Bot API.

## Development

```bash
# Clone the repo
git clone https://github.com/herbalclaw/need-follow-up.git
cd need-follow-up

# Install dependencies
npm install

# Build
npm run build

# Watch mode
npm run dev
```

## License

MIT
