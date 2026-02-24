#!/bin/bash
# Hook for PermissionRequest events - Notification only with project name

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""')
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

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

# Build message
case "$TOOL_NAME" in
    "Bash")
        EMOJI="💻"
        HEADER="Claude wants to run a command"
        ;;
    "Write")
        EMOJI="📝"
        HEADER="Claude wants to create a file"
        ;;
    "Edit")
        EMOJI="✏️"
        HEADER="Claude wants to edit a file"
        ;;
    "Read")
        EMOJI="👀"
        HEADER="Claude wants to read a file"
        ;;
    *)
        EMOJI="⚠️"
        HEADER="Claude needs permission"
        ;;
esac
FOLDER_EMOJI="📁"
TIME_EMOJI="⏰"

# Build detail
case "$TOOL_NAME" in
    "Bash")
        DETAIL="${COMMAND:0:300}"
        [ ${#COMMAND} -gt 300 ] && DETAIL="${DETAIL}..."
        ;;
    *)
        DETAIL="${FILE_PATH}"
        ;;
esac

NOTIFICATION="${FOLDER_EMOJI} ${PROJECT_NAME}

${EMOJI} ${HEADER}

${DETAIL}

${TIME_EMOJI} Go to terminal to approve"

# Send notification (use jq to properly encode Unicode/emojis)
PAYLOAD=$(jq -n --arg chat_id "$CHAT_ID" --arg text "$NOTIFICATION" '{chat_id: $chat_id, text: $text}')
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null

exit 0
