#!/bin/bash
# Hook for PermissionRequest events - With two-way approval

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
REQUEST_ID=$(echo "$INPUT" | jq -r '.request_id // "unknown"')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""')
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

# Debug log
PENDING_DIR="${HOME}/.claude/telegram-notifier"
mkdir -p "$PENDING_DIR"
echo "[permission] Request: $REQUEST_ID for $TOOL_NAME" >> "${PENDING_DIR}/debug.log"

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

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "[permission] Error: No config found" >> "${PENDING_DIR}/debug.log"
    exit 0
fi

DECISION_FILE="${PENDING_DIR}/${REQUEST_ID}.decision"

# Build message
case "$TOOL_NAME" in
    "Bash")
        EMOJI="💻"
        HEADER="Claude wants to run a command"
        DETAIL="${COMMAND:0:300}"
        [ ${#COMMAND} -gt 300 ] && DETAIL="${DETAIL}..."
        ;;
    "Write")
        EMOJI="📝"
        HEADER="Claude wants to create a file"
        DETAIL="${FILE_PATH}"
        ;;
    "Edit")
        EMOJI="✏️"
        HEADER="Claude wants to edit a file"
        DETAIL="${FILE_PATH}"
        ;;
    "Read")
        EMOJI="👀"
        HEADER="Claude wants to read a file"
        DETAIL="${FILE_PATH}"
        ;;
    *)
        EMOJI="⚠️"
        HEADER="Claude needs permission"
        DETAIL="${TOOL_NAME}"
        [ -n "$FILE_PATH" ] && DETAIL="${DETAIL}: ${FILE_PATH}"
        ;;
esac

echo "[permission] Sending notification for $REQUEST_ID" >> "${PENDING_DIR}/debug.log"

# Create JSON payload using jq
PAYLOAD=$(jq -n \
    --arg chat_id "$CHAT_ID" \
    --arg text "$EMOJI $HEADER

$DETAIL

Tap to approve:" \
    --arg req_id "$REQUEST_ID" \
    '{
        chat_id: $chat_id,
        text: $text,
        parse_mode: "Markdown",
        reply_markup: {
            inline_keyboard: [[
                {text: "✅ Approve", callback_data: "approve:\($req_id)"},
                {text: "❌ Deny", callback_data: "deny:\($req_id)"}
            ]]
        }
    }')

# Send message
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

if [ "$(echo "$RESPONSE" | jq -r '.ok')" != "true" ]; then
    echo "[permission] Error sending message: $(echo "$RESPONSE" | jq -r '.description')" >> "${PENDING_DIR}/debug.log"
    exit 0
fi

echo "[permission] Waiting for decision at: $DECISION_FILE" >> "${PENDING_DIR}/debug.log"

# Wait for decision
TIMEOUT=300
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if [ -f "$DECISION_FILE" ]; then
        DECISION=$(cat "$DECISION_FILE" 2>/dev/null)
        rm -f "$DECISION_FILE"
        echo "[permission] Decision received: $DECISION" >> "${PENDING_DIR}/debug.log"
        [ "$DECISION" = "approve" ] && exit 0
        echo "Denied via Telegram" >&2
        exit 1
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

# Timeout
echo "[permission] Timeout waiting for decision" >> "${PENDING_DIR}/debug.log"
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\": \"${CHAT_ID}\", \"text\": \"⏰ Timed out\", \"parse_mode\": \"Markdown\"}" > /dev/null

exit 0
