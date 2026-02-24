#!/bin/bash
# Hook for Stop events - with project name

INPUT=$(cat)

# Get project name from current directory
PROJECT_NAME=$(basename "$PWD")

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    for CONFIG_FILE in "$HOME/.claude/settings.json" "$HOME/.claude-code/config.json"; do
        if [ -f "$CONFIG_FILE" ]; then
            BOT_TOKEN=$(jq -r '.plugins[]? | select(.name == "telegram-notifier") | .config.botToken' "$CONFIG_FILE" 2>/dev/null)
            CHAT_ID=$(jq -r '.plugins[]? | select(.name == "telegram-notifier") | .config.chatId' "$CONFIG_FILE" 2>/dev/null)
            [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ] && break
        fi
    done
fi

[ -z "$BOT_TOKEN" ] && exit 0

[ "${TELEGRAM_NOTIFY_COMPLETION:-true}" = "false" ] && exit 0

FOLDER_EMOJI="📁"
DONE_EMOJI="✅"

NOTIFICATION="${FOLDER_EMOJI} ${PROJECT_NAME}

${DONE_EMOJI} Claude finished

Your request has been completed. Check the terminal for details."

# Send notification (use jq to properly encode Unicode/emojis)
PAYLOAD=$(jq -n --arg chat_id "$CHAT_ID" --arg text "$NOTIFICATION" '{chat_id: $chat_id, text: $text}')
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null

exit 0
