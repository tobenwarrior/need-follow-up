import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

export interface TelegramConfig {
  botToken: string;
  chatId: string;
  notifyOnApproval?: boolean;
  notifyOnCompletion?: boolean;
  notifyOnLongThinking?: boolean;
  longThinkingThresholdMinutes?: number;
  includeContext?: boolean;
  quietHoursStart?: string | null;
  quietHoursEnd?: string | null;
}

/**
 * Load config from Claude Code config or environment variables
 */
export function getConfig(): TelegramConfig | null {
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
      includeContext: process.env.TELEGRAM_INCLUDE_CONTEXT !== 'false',
    };
  }

  // Try Claude Code config file
  const configPath = path.join(os.homedir(), '.claude-code', 'config.json');
  
  if (fs.existsSync(configPath)) {
    try {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      const pluginConfig = config.plugins?.find(
        (p: any) => p.name === 'telegram-notifier' || p.name === 'claude-code-telegram-notifier'
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

/**
 * Check if currently in quiet hours
 */
export function isQuietHours(config: TelegramConfig): boolean {
  if (!config.quietHoursStart || !config.quietHoursEnd) {
    return false;
  }

  const now = new Date();
  const currentTime = now.getHours() * 60 + now.getMinutes();
  
  const [startHour, startMin] = config.quietHoursStart.split(':').map(Number);
  const [endHour, endMin] = config.quietHoursEnd.split(':').map(Number);
  
  const startTime = startHour * 60 + startMin;
  const endTime = endHour * 60 + endMin;

  if (startTime < endTime) {
    return currentTime >= startTime && currentTime < endTime;
  } else {
    // Quiet hours span midnight
    return currentTime >= startTime || currentTime < endTime;
  }
}

/**
 * Send a message via Telegram Bot API
 */
export async function sendTelegramMessage(
  config: TelegramConfig,
  text: string,
  options: {
    parse_mode?: 'Markdown' | 'HTML';
    reply_markup?: any;
  } = {}
): Promise<any> {
  if (isQuietHours(config)) {
    console.log('[Telegram Notifier] In quiet hours, skipping notification');
    return null;
  }

  const url = `https://api.telegram.org/bot${config.botToken}/sendMessage`;
  
  const body = {
    chat_id: config.chatId,
    text,
    ...options,
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Telegram API error: ${error}`);
  }

  return response.json();
}
