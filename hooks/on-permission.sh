#!/bin/bash
# Hook for PermissionRequest events - sends detailed Telegram notification with approval buttons
# Waits for user response from Telegram

# Read JSON input from stdin
INPUT=$(cat)

# Extract all relevant fields from Claude Code's PermissionRequest event
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
REQUEST_ID=$(echo "$INPUT" | jq -r '.request_id // "unknown"')
DESCRIPTION=$(echo "$INPUT" | jq -r '.description // ""')

# Extract specific tool input details
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""')
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')
OLD_STRING=$(echo "$TOOL_INPUT" | jq -r '.old_string // ""')
NEW_STRING=$(echo "$TOOL_INPUT" | jq -r '.new_string // ""')

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
    # No config, just allow the request
    exit 0
fi

# Build detailed notification based on tool type
case "$TOOL_NAME" in
    "Bash")
        EMOJI="💻"
        HEADER="Claude wants to run a command"
        if [ -n "$COMMAND" ]; then
            DETAIL="Command:\\n\`\`\`\\n${COMMAND:0:200}\\n\`\`\`"
            if [ ${#COMMAND} -gt 200 ]; then
                DETAIL="${DETAIL}..."
            fi
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
        if [ -n "$FILE_PATH" ]; then
            DETAIL="${DETAIL}\\n📄 \`${FILE_PATH}\`"
        fi
        ;;
esac

# Add description if available
if [ -n "$DESCRIPTION" ]; then
    DETAIL="${DETAIL}\\n\\n📝 ${DESCRIPTION}"
fi

# Build the full message
NOTIFICATION="${EMOJI} *${HEADER}*

${DETAIL}

_Tap a button below to approve or deny:_"

# Escape for JSON
ESCAPED_NOTIFICATION=$(echo "$NOTIFICATION" | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/  */ /g')

# Send notification with inline keyboard for approval
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

# Check if message was sent successfully
if [ "$(echo "$RESPONSE" | jq -r '.ok')" != "true" ]; then
    echo "Failed to send Telegram notification" >&2
    # Allow the request if we can't notify
    exit 0
fi

# Wait for user response (check for decision file)
PENDING_DIR="${HOME}/.claude/telegram-notifier"
mkdir -p "$PENDING_DIR"
DECISION_FILE="${PENDING_DIR}/${REQUEST_ID}.decision"

# Wait up to 5 minutes for a decision
TIMEOUT=300  # 5 minutes in seconds
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if [ -f "$DECISION_FILE" ]; then
        DECISION=$(cat "$DECISION_FILE")
        rm -f "$DECISION_FILE"
        
        if [ "$DECISION" = "approve" ]; then
            # Return success to allow the request
            exit 0
        else
            # Return error to deny the request
            echo "Request denied by user via Telegram" >&2
            exit 1
        fi
    fi
    
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

# Timeout - allow the request but notify
TIMEOUT_NOTIFICATION="⏰ *Approval timed out*

No response received in 5 minutes. The request will proceed."
ESCAPED_TIMEOUT=$(echo "$TIMEOUT_NOTIFICATION" | sed 's/"/\\"/g')

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${ESCAPED_TIMEOUT}\",
        \"parse_mode\": \"Markdown\"
    }" > /dev/null

# Allow on timeout
exit 0
