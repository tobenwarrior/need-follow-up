#!/bin/bash
# Webhook receiver for Telegram callbacks
# This runs in the background and listens for approval/denial from Telegram

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID"
    exit 1
fi

# File to store pending approvals
PENDING_DIR="${HOME}/.claude/telegram-notifier"
mkdir -p "$PENDING_DIR"

# Function to process updates
process_updates() {
    local OFFSET=0
    
    while true; do
        # Get updates from Telegram
        UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&limit=10")
        
        # Check if we have updates
        if [ "$(echo "$UPDATES" | jq -r '.ok')" != "true" ]; then
            sleep 5
            continue
        fi
        
        # Process each update
        echo "$UPDATES" | jq -c '.result[]' 2>/dev/null | while read -r UPDATE; do
            # Get update ID
            UPDATE_ID=$(echo "$UPDATE" | jq -r '.update_id')
            OFFSET=$((UPDATE_ID + 1))
            
            # Check for callback query (inline button click)
            CALLBACK=$(echo "$UPDATE" | jq -r '.callback_query // empty')
            if [ -n "$CALLBACK" ]; then
                CALLBACK_ID=$(echo "$CALLBACK" | jq -r '.id')
                CALLBACK_DATA=$(echo "$CALLBACK" | jq -r '.data')
                
                # Parse approve:REQUEST_ID or deny:REQUEST_ID
                ACTION=$(echo "$CALLBACK_DATA" | cut -d':' -f1)
                REQUEST_ID=$(echo "$CALLBACK_DATA" | cut -d':' -f2)
                
                if [ "$ACTION" = "approve" ] || [ "$ACTION" = "deny" ]; then
                    # Store the decision
                    echo "$ACTION" > "${PENDING_DIR}/${REQUEST_ID}.decision"
                    
                    # Answer the callback to remove loading state
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery" \
                        -H "Content-Type: application/json" \
                        -d "{\"callback_query_id\": \"${CALLBACK_ID}\", \"text\": \"Decision recorded: ${ACTION}\"}" > /dev/null
                    
                    # Edit the message to show it's been handled
                    MESSAGE_ID=$(echo "$CALLBACK" | jq -r '.message.message_id')
                    CHAT_ID=$(echo "$CALLBACK" | jq -r '.message.chat.id')
                    
                    if [ "$ACTION" = "approve" ]; then
                        NEW_TEXT="✅ *Approved*\\n\\nThis action has been approved."
                    else
                        NEW_TEXT="❌ *Denied*\\n\\nThis action has been denied."
                    fi
                    
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
                        -H "Content-Type: application/json" \
                        -d "{
                            \"chat_id\": ${CHAT_ID},
                            \"message_id\": ${MESSAGE_ID},
                            \"text\": \"${NEW_TEXT}\",
                            \"parse_mode\": \"Markdown\"
                        }" > /dev/null
                fi
            fi
        done
        
        sleep 2
    done
}

# Start processing
process_updates
