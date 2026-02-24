#!/bin/bash
# Hook for Notification events - with project name

INPUT=$(cat)

NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')
TITLE=$(echo "$INPUT" | jq -r '.title // ""')

# Get project name from current directory
PROJECT_NAME=$(basename "$PWD")

# Only handle specific types
if [ "$NOTIF_TYPE" != "permission_prompt" ] && [ "$NOTIF_TYPE" != "idle_prompt" ] && [ "$NOTIF_TYPE" != "elicitation_dialog" ]; then
    exit 0
fi

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

# Build message
case "$NOTIF_TYPE" in
    "permission_prompt") EMOJI="⏸️"; HEADER="Claude needs approval" ;;
    "idle_prompt") EMOJI="🤔"; HEADER="Claude is waiting" ;;
    "elicitation_dialog") EMOJI="💬"; HEADER="Claude has a question" ;;
    *) EMOJI="📢"; HEADER="Claude notification" ;;
esac
FOLDER_EMOJI="📁"

NOTIFICATION="${FOLDER_EMOJI} ${PROJECT_NAME}

${EMOJI} ${HEADER}"

[ -n "$TITLE" ] && NOTIFICATION="${NOTIFICATION}

${TITLE}"

if [ -n "$MESSAGE" ]; then
    TRIMMED_MSG=$(echo "$MESSAGE" | head -c 500)
    [ ${#MESSAGE} -gt 500 ] && TRIMMED_MSG="${TRIMMED_MSG}..."
    NOTIFICATION="${NOTIFICATION}

${TRIMMED_MSG}"
fi

NOTIFICATION="${NOTIFICATION}

Check terminal to respond"

# Send notification (use jq to properly encode Unicode/emojis)
PAYLOAD=$(jq -n --arg chat_id "$CHAT_ID" --arg text "$NOTIFICATION" '{chat_id: $chat_id, text: $text}')
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null

exit 0
