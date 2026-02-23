#!/bin/bash
# Hook for Stop events - with project name

INPUT=$(cat)

# Get project name from current directory
PROJECT_NAME=$(basename "$PWD")

# Check if emojis are enabled (default: enabled)
USE_EMOJIS="${TELEGRAM_USE_EMOJIS:-true}"

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

if [ "$USE_EMOJIS" = "true" ]; then
    FOLDER_EMOJI="📁"
    DONE_EMOJI="✅"
else
    FOLDER_EMOJI="[PROJECT]"
    DONE_EMOJI="[DONE]"
fi

NOTIFICATION="${FOLDER_EMOJI} ${PROJECT_NAME}

${DONE_EMOJI} Claude finished

Your request has been completed. Check the terminal for details."

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${NOTIFICATION}\"
    }" > /dev/null

exit 0
