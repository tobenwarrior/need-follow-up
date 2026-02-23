#!/bin/bash
# Webhook server - receives Telegram callbacks and writes decision files

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

[ -z "$BOT_TOKEN" ] && exit 1

PENDING_DIR="${HOME}/.claude/telegram-notifier"
mkdir -p "$PENDING_DIR"

PID_FILE="${PENDING_DIR}/webhook.pid"
echo $$ > "$PID_FILE"

cleanup() { rm -f "$PID_FILE"; exit 0; }
trap cleanup EXIT INT TERM

OFFSET=0

while true; do
    UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&limit=10")
    
    [ "$(echo "$UPDATES" | jq -r '.ok')" != "true" ] && { sleep 2; continue; }
    
    echo "$UPDATES" | jq -c '.result[]' 2>/dev/null | while read -r UPDATE; do
        UPDATE_ID=$(echo "$UPDATE" | jq -r '.update_id')
        OFFSET=$((UPDATE_ID + 1))
        
        CALLBACK=$(echo "$UPDATE" | jq -r '.callback_query // empty')
        [ -z "$CALLBACK" ] && continue
        
        CALLBACK_ID=$(echo "$CALLBACK" | jq -r '.id')
        DATA=$(echo "$CALLBACK" | jq -r '.data')
        
        ACTION=$(echo "$DATA" | cut -d':' -f1)
        REQ_ID=$(echo "$DATA" | cut -d':' -f2)
        
        if [ "$ACTION" = "approve" ] || [ "$ACTION" = "deny" ]; then
            # Write decision
            echo "$ACTION" > "${PENDING_DIR}/${REQ_ID}.decision"
            
            # Answer callback
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery" \
                -H "Content-Type: application/json" \
                -d "{\"callback_query_id\": \"${CALLBACK_ID}\", \"text\": \"${ACTION}d\"}" > /dev/null
            
            # Update message
            MSG_ID=$(echo "$CALLBACK" | jq -r '.message.message_id')
            CHAT=$(echo "$CALLBACK" | jq -r '.message.chat.id')
            
            if [ "$ACTION" = "approve" ]; then
                TEXT="✅ *Approved*"
            else
                TEXT="❌ *Denied*"
            fi
            
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
                -H "Content-Type: application/json" \
                -d "{\"chat_id\": ${CHAT}, \"message_id\": ${MSG_ID}, \"text\": \"${TEXT}\", \"parse_mode\": \"Markdown\"}" > /dev/null
        fi
    done
    
    sleep 1
done
