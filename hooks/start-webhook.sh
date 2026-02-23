#!/bin/bash
# Start the webhook server for two-way Telegram approval

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEBHOOK="${SCRIPT_DIR}/webhook-server.sh"
PENDING_DIR="${HOME}/.claude/telegram-notifier"
PID_FILE="${PENDING_DIR}/webhook.pid"

mkdir -p "$PENDING_DIR"

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Webhook server already running (PID: $OLD_PID)"
        exit 0
    fi
fi

# Start server
if [ -x "$WEBHOOK" ]; then
    echo "Starting webhook server..."
    nohup "$WEBHOOK" > "${PENDING_DIR}/webhook.log" 2>&1 &
    sleep 1
    
    # Verify it started
    if [ -f "$PID_FILE" ]; then
        NEW_PID=$(cat "$PID_FILE")
        if kill -0 "$NEW_PID" 2>/dev/null; then
            echo "Webhook server started (PID: $NEW_PID)"
            echo "Logs: ${PENDING_DIR}/webhook.log"
        else
            echo "Failed to start webhook server"
            exit 1
        fi
    fi
else
    echo "Webhook script not found: $WEBHOOK"
    exit 1
fi
