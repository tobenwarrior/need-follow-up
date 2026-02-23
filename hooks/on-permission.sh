#!/bin/bash
# Hook for PermissionRequest events - WSL compatible

# Read JSON input from stdin
INPUT=$(cat)

# Extract fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
REQUEST_ID=$(echo "$INPUT" | jq -r '.request_id // "unknown"')
DESCRIPTION=$(echo "$INPUT" | jq -r '.description // ""')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""')
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

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

# Setup directories
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WEBHOOK_SCRIPT="${PLUGIN_DIR}/hooks/webhook-server.sh"
PENDING_DIR="${HOME}/.claude/telegram-notifier"
mkdir -p "$PENDING_DIR"
PID_FILE="${PENDING_DIR}/webhook.pid"

# WSL-friendly server check and start
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        : # Server is running
    else
        # PID file stale, remove it
        rm -f "$PID_FILE"
        # Start server
        if [ -x "$WEBHOOK_SCRIPT" ]; then
            bash "$WEBHOOK_SCRIPT" > "${PENDING_DIR}/webhook.log" 2>&1 &
            sleep 2
        fi
    fi
else
    # No PID file, start server
    if [ -x "$WEBHOOK_SCRIPT" ]; then
        bash "$WEBHOOK_SCRIPT" > "${PENDING_DIR}/webhook.log" 2>&1 &
        sleep 2
    fi
fi

# Build notification message
case "$TOOL_NAME" in
    "Bash")
        EMOJI="💻"
        HEADER="Claude wants to run a command"
        if [ -n "$COMMAND" ]; then
            DETAIL="Command:\\n\`\`\`\\n${COMMAND:0:200}\\n\`\`\`"
            [ ${#COMMAND} -gt 200 ] && DETAIL="${DETAIL}..."
        else
            DETAIL="Command: (see terminal)"
        fi
        ;;
    "Write")
        EMOJI="📝"
        HEADER="Claude wants to create a file"
        DETAIL="📄 \`${FILE_PATH}\`"
        ;;
    "Edit")
        EMOJI="✏️"
        HEADER="Claude wants to edit a file"
        DETAIL="📄 \`${FILE_PATH}\`"
        ;;
    "Read")
        EMOJI="👀"
        HEADER="Claude wants to read a file"
        DETAIL="📄 \`${FILE_PATH}\`"
        ;;
    *)
        EMOJI="⚠️"
        HEADER="Claude needs permission"
        DETAIL="Action: ${TOOL_NAME}"
        [ -n "$FILE_PATH" ] && DETAIL="${DETAIL}\\n📄 \`${FILE_PATH}\`"
        ;;
esac

[ -n "$DESCRIPTION" ] && DETAIL="${DETAIL}\\n\\n📝 ${DESCRIPTION}"

NOTIFICATION="${EMOJI} *${HEADER}*

${DETAIL}

_Tap a button below:_"

ESCAPED_NOTIFICATION=$(echo "$NOTIFICATION" | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/  */ /g')

# Send notification
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${ESCAPED_NOTIFICATION}\",
        \"parse_mode\": \"Markdown\",
        \"reply_markup\": {
            \"inline_keyboard\": [
                [
                    {\"text\": \"✅ Approve\", \"callback_data\": \"approve:${REQUEST_ID}\"},
                    {\"text\": \"❌ Deny\", \"callback_data\": \"deny:${REQUEST_ID}\"}
                ]
            ]
        }
    }")

[ "$(echo "$RESPONSE" | jq -r '.ok')" != "true" ] && exit 0

# Wait for decision
DECISION_FILE="${PENDING_DIR}/${REQUEST_ID}.decision"
TIMEOUT=300
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if [ -f "$DECISION_FILE" ]; then
        DECISION=$(cat "$DECISION_FILE")
        rm -f "$DECISION_FILE"
        [ "$DECISION" = "approve" ] && exit 0
        echo "Request denied by user via Telegram" >&2
        exit 1
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

# Timeout - notify and allow
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"⏰ Approval timed out - proceeding\",
        \"parse_mode\": \"Markdown\"
    }" > /dev/null

exit 0
