#!/usr/bin/env node

/**
 * Claude Code CLI integration hook
 * This script is called by Claude Code when events occur
 */

import { createPlugin, NotifierConfig } from '../src';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

// Load config from Claude Code config or environment variables
function loadConfig(): NotifierConfig | null {
  // Try environment variables first
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;

  if (botToken && chatId) {
    return {
      botToken,
      chatId,
      notifyOnApproval: process.env.TELEGRAM_NOTIFY_APPROVAL !== 'false',
      notifyOnCompletion: process.env.TELEGRAM_NOTIFY_COMPLETION !== 'false',
      notifyOnLongThinking: process.env.TELEGRAM_NOTIFY_THINKING !== 'false',
      longThinkingThresholdMinutes: parseInt(process.env.TELEGRAM_THINKING_THRESHOLD || '5', 10),
    };
  }

  // Try Claude Code config file
  const configPath = path.join(os.homedir(), '.claude-code', 'config.json');
  
  if (fs.existsSync(configPath)) {
    try {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      const pluginConfig = config.plugins?.find(
        (p: any) => p.name === 'claude-code-telegram-notifier'
      );
      
      if (pluginConfig?.config) {
        return pluginConfig.config;
      }
    } catch (e) {
      console.error('Failed to load config:', e);
    }
  }

  return null;
}

// Handle CLI commands
async function main() {
  const config = loadConfig();
  
  if (!config) {
    console.error('Telegram notifier not configured. Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID environment variables,');
    console.error('or add configuration to ~/.claude-code/config.json');
    process.exit(1);
  }

  const plugin = createPlugin(config);
  const command = process.argv[2];

  switch (command) {
    case 'init':
      await plugin.initialize();
      break;

    case 'approval': {
      const requestId = process.argv[3];
      const action = process.argv[4];
      const description = process.argv[5];
      const context = process.argv[6];
      
      const approved = await plugin.onApprovalRequired(requestId, action, description, context);
      process.exit(approved ? 0 : 1);
    }

    case 'task-start': {
      const taskId = process.argv[3];
      const description = process.argv[4];
      plugin.onTaskStarted(taskId, description);
      break;
    }

    case 'task-complete': {
      const taskId = process.argv[3];
      const duration = parseInt(process.argv[4], 10);
      const filesChanged = process.argv[5] ? parseInt(process.argv[5], 10) : undefined;
      const summary = process.argv[6];
      
      await plugin.onTaskCompleted(taskId, duration, filesChanged, summary);
      break;
    }

    case 'thinking': {
      const taskId = process.argv[3];
      const duration = parseInt(process.argv[4], 10);
      await plugin.onThinkingProgress(taskId, duration);
      break;
    }

    case 'shutdown':
      await plugin.destroy();
      break;

    default:
      console.log('Usage: claude-telegram-notifier <command> [args...]');
      console.log('');
      console.log('Commands:');
      console.log('  init                          Initialize the plugin');
      console.log('  approval <id> <action> <desc> [context]  Request approval');
      console.log('  task-start <id> <description>        Mark task started');
      console.log('  task-complete <id> <duration> [files] [summary]  Mark task complete');
      console.log('  thinking <id> <duration>            Report thinking progress');
      console.log('  shutdown                      Stop the plugin');
      process.exit(1);
  }

  // Keep process alive for async operations
  setTimeout(() => process.exit(0), 1000);
}

main().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
