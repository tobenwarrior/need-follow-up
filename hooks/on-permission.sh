#!/bin/bash
# Hook for PermissionRequest events - With two-way approval

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
REQUEST_ID=$(echo "$INPUT" | jq -r '.request_id // "unknown"')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""')
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

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

# Setup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PENDING_DIR="${HOME}/.claude/telegram-notifier"
DECISION_FILE="${PENDING_DIR}/${REQUEST_ID}.decision"

mkdir -p "$PENDING_DIR"

# Build message
case "$TOOL_NAME" in
    "Bash")
        EMOJI="💻"
        HEADER="Claude wants to run a command"
        DETAIL="\`\`\`\n${COMMAND:0:300}\n\`\`\`"
        [ ${#COMMAND} -gt 300 ] && DETAIL="${DETAIL}..."
        ;;
    "Write")
        EMOJI="📝"
        HEADER="Claude wants to create a file"
        DETAIL="📄 ${FILE_PATH}"
        ;;
    "Edit")
        EMOJI="✏️"
        HEADER="Claude wants to edit a file"
        DETAIL="📄 ${FILE_PATH}"
        ;;
    "Read")
        EMOJI="👀"
        HEADER="Claude wants to read a file"
        DETAIL="📄 ${FILE_PATH}"
        ;;
    *)
        EMOJI="⚠️"
        HEADER="Claude needs permission"
        DETAIL="Action: ${TOOL_NAME}"
        [ -n "$FILE_PATH" ] && DETAIL="${DETAIL} - ${FILE_PATH}"
        ;;
esac

NOTIFICATION="${EMOJI} *${HEADER}*

${DETAIL}

_Tap to approve/deny:_"

# Send with inline keyboard
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${NOTIFICATION}\",
        \"parse_mode\": \"Markdown\",
        \"reply_markup\": {
            \"inline_keyboard\": [[
                {\"text\": \"✅ Approve\", \"callback_data\": \"approve:${REQUEST_ID}\"},
                {\"text\": \"❌ Deny\", \"callback_data\": \"deny:${REQUEST_ID}\"}
            ]]
        }
    }" > /dev/null

# Wait for decision (check file)
TIMEOUT=300
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if [ -f "$DECISION_FILE" ]; then
        DECISION=$(cat "$DECISION_FILE" 2>/dev/null)
        rm -f "$DECISION_FILE"
        [ "$DECISION" = "approve" ] && exit 0
        echo "Denied via Telegram" >&2
        exit 1
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

# Timeout - proceed
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\": \"${CHAT_ID}\", \"text\": \"⏰ Timed out - proceeding\", \"parse_mode\": \"Markdown\"}" > /dev/null

exit 0
