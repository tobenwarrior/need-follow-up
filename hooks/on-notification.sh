#!/bin/bash
# Hook for Notification events - handles idle prompts, permission prompts, etc.

# Read JSON input from stdin
INPUT=$(cat)

# Extract notification type and message
NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')
TITLE=$(echo "$INPUT" | jq -r '.title // ""')

# Only handle specific notification types
if [ "$NOTIF_TYPE" != "permission_prompt" ] && [ "$NOTIF_TYPE" != "idle_prompt" ] && [ "$NOTIF_TYPE" != "elicitation_dialog" ]; then
    exit 0
fi

# Load config
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    CONFIG_FILE="$HOME/.claude/settings.json"
    if [ -f "$CONFIG_FILE" ]; then
        BOT_TOKEN=$(jq -r '.plugins[] | select(.name == "telegram-notifier") | .config.botToken' "$CONFIG_FILE" 2>/dev/null)
        CHAT_ID=$(jq -r '.plugins[] | select(.name == "telegram-notifier") | .config.chatId' "$CONFIG_FILE" 2>/dev/null)
    fi
fi

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    exit 0
fi

# Build emoji and header based on type
case "$NOTIF_TYPE" in
    "permission_prompt")
        EMOJI="⏸️"
        HEADER="Claude needs your approval"
        ;;
    "idle_prompt")
        EMOJI="🤔"
        HEADER="Claude is waiting for you"
        ;;
    "elicitation_dialog")
        EMOJI="💬"
        HEADER="Claude has a question"
        ;;
    *)
        EMOJI="📢"
        HEADER="Claude notification"
        ;;
esac

# Build message with title if available
NOTIFICATION="${EMOJI} *${HEADER}*"

if [ -n "$TITLE" ]; then
    NOTIFICATION="${NOTIFICATION}

*${TITLE}*"
fi

if [ -n "$MESSAGE" ]; then
    # Escape markdown and limit length
    ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/[_*[`]/\\&/g' | head -c 500)
    if [ ${#MESSAGE} -gt 500 ]; then
        ESCAPED_MESSAGE="${ESCAPED_MESSAGE}..."
    fi
    NOTIFICATION="${NOTIFICATION}

${ESCAPED_MESSAGE}"
fi

# Add action hint
NOTIFICATION="${NOTIFICATION}

⏰ _Check your terminal to respond_"

# Escape for JSON
ESCAPED_NOTIFICATION=$(echo "$NOTIFICATION" | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/  */ /g')

# Send notification
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${ESCAPED_NOTIFICATION}\",
        \"parse_mode\": \"Markdown\"
    }" > /dev/null

exit 0
