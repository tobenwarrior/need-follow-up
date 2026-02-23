#!/bin/bash

# Setup script for Claude Code Telegram Notifier
# This helps users configure the plugin

set -e

echo "=========================================="
echo "Claude Code Telegram Notifier Setup"
echo "=========================================="
echo ""

# Check if running in correct directory
if [ ! -f "package.json" ]; then
    echo "Error: Please run this script from the plugin directory"
    exit 1
fi

# Install dependencies
echo "[1/4] Installing dependencies..."
npm install

# Build the project
echo "[2/4] Building project..."
npm run build

# Create global link
echo "[3/4] Creating global link..."
npm link

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Create a Telegram bot:"
echo "   - Message @BotFather on Telegram"
echo "   - Send /newbot and follow instructions"
echo "   - Save your bot token"
echo ""
echo "2. Get your Chat ID:"
echo "   - Message @userinfobot on Telegram"
echo "   - Note your Chat ID"
echo ""
echo "3. Configure Claude Code:"
echo "   Edit ~/.claude-code/config.json and add:"
echo ""
cat << 'EOF'
{
  "plugins": [
    {
      "name": "claude-code-telegram-notifier",
      "config": {
        "botToken": "YOUR_BOT_TOKEN",
        "chatId": "YOUR_CHAT_ID"
      }
    }
  ]
}
EOF

echo ""
echo "Or set environment variables:"
echo "   export TELEGRAM_BOT_TOKEN='your-bot-token'"
echo "   export TELEGRAM_CHAT_ID='your-chat-id'"
echo ""
echo "4. Test the plugin:"
echo "   claude-telegram-notifier init"
echo ""
