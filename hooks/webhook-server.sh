#!/bin/bash
# Webhook server - receives Telegram callbacks and writes decision files

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ]; then
    echo "[webhook] Error: TELEGRAM_BOT_TOKEN not set" >&2
    exit 1
fi

PENDING_DIR="${HOME}/.claude/telegram-notifier"
mkdir -p "$PENDING_DIR"

PID_FILE="${PENDING_DIR}/webhook.pid"
echo $$ > "$PID_FILE"

LOG_FILE="${PENDING_DIR}/webhook.log"
echo "[webhook] Started at $(date)" >> "$LOG_FILE"

cleanup() { 
    echo "[webhook] Stopping at $(date)" >> "$LOG_FILE"
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup EXIT INT TERM

OFFSET=0

while true; do
    # Get updates from Telegram
    RESPONSE=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&limit=10")
    
    # Check if response is valid
    if [ "$(echo "$RESPONSE" | jq -r '.ok')" != "true" ]; then
        echo "[webhook] API error: $(echo "$RESPONSE" | jq -r '.description')" >> "$LOG_FILE"
        sleep 2
        continue
    fi
    
    # Process updates
    RESULTS=$(echo "$RESPONSE" | jq -c '.result[]')
    
    if [ -n "$RESULTS" ]; then
        echo "$RESULTS" | while IFS= read -r UPDATE; do
            UPDATE_ID=$(echo "$UPDATE" | jq -r '.update_id')
            
            # Update offset for next poll
            if [ "$UPDATE_ID" -ge "$OFFSET" ]; then
                OFFSET=$((UPDATE_ID + 1))
            fi
            
            # Check for callback query
            CALLBACK=$(echo "$UPDATE" | jq -r '.callback_query // empty')
            
            if [ -n "$CALLBACK" ] && [ "$CALLBACK" != "null" ]; then
                CALLBACK_ID=$(echo "$CALLBACK" | jq -r '.id')
                DATA=$(echo "$CALLBACK" | jq -r '.data')
                
                echo "[webhook] Received callback: $DATA" >> "$LOG_FILE"
                
                # Parse action and request ID
                ACTION=$(echo "$DATA" | cut -d':' -f1)
                REQ_ID=$(echo "$DATA" | cut -d':' -f2)
                
                if [ "$ACTION" = "approve" ] || [ "$ACTION" = "deny" ]; then
                    DECISION_FILE="${PENDING_DIR}/${REQ_ID}.decision"
                    
                    # Write decision
                    echo "$ACTION" > "$DECISION_FILE"
                    echo "[webhook] Wrote decision to: $DECISION_FILE" >> "$LOG_FILE"
                    
                    # Answer callback to remove loading spinner
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery" \
                        -H "Content-Type: application/json" \
                        -d "{\"callback_query_id\": \"${CALLBACK_ID}\", \"text\": \"${ACTION}d\"}" > /dev/null
                    
                    # Update the message
                    MSG_ID=$(echo "$CALLBACK" | jq -r '.message.message_id')
                    CHAT=$(echo "$CALLBACK" | jq -r '.message.chat.id')
                    
                    if [ "$ACTION" = "approve" ]; then
                        TEXT="✅ Approved"
                    else
                        TEXT="❌ Denied"
                    fi
                    
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
                        -H "Content-Type: application/json" \
                        -d "{\"chat_id\": ${CHAT}, \"message_id\": ${MSG_ID}, \"text\": \"${TEXT}\", \"parse_mode\": \"Markdown\"}" > /dev/null
                    
                    echo "[webhook] Processed $ACTION for $REQ_ID" >> "$LOG_FILE"
                fi
            fi
        done
    fi
    
    sleep 1
done
