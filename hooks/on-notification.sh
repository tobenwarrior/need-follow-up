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

NOTIFICATION="📁 *${PROJECT_NAME}*

${EMOJI} ${HEADER}"

[ -n "$TITLE" ] && NOTIFICATION="${NOTIFICATION}

*${TITLE}*"

if [ -n "$MESSAGE" ]; then
    ESCAPED_MSG=$(printf '%s' "$MESSAGE" | sed 's/[_*[`]/\\&/g' | head -c 500)
    [ ${#MESSAGE} -gt 500 ] && ESCAPED_MSG="${ESCAPED_MSG}..."
    NOTIFICATION="${NOTIFICATION}

${ESCAPED_MSG}"
fi

NOTIFICATION="${NOTIFICATION}

⏰ _Check terminal to respond_"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${NOTIFICATION}\",
        \"parse_mode\": \"Markdown\"
    }" > /dev/null

exit 0
