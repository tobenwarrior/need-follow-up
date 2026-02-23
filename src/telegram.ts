import TelegramBot from 'node-telegram-bot-api';
import { NotifierConfig, TelegramResponse } from './types';

/**
 * Telegram bot wrapper for sending notifications
 */
export class TelegramNotifier {
  private bot: TelegramBot;
  private config: NotifierConfig;
  private messageHandlers: Map<number, (text: string) => void> = new Map();

  constructor(config: NotifierConfig) {
    this.config = {
      notifyOnApproval: true,
      notifyOnCompletion: true,
      notifyOnLongThinking: true,
      longThinkingThresholdMinutes: 5,
      includeContext: true,
      quietHoursStart: null,
      quietHoursEnd: null,
      ...config,
    };

    this.bot = new TelegramBot(this.config.botToken, { polling: true });
    this.setupMessageHandler();
  }

  /**
   * Check if currently in quiet hours
   */
  private isQuietHours(): boolean {
    if (!this.config.quietHoursStart || !this.config.quietHoursEnd) {
      return false;
    }

    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();
    
    const [startHour, startMin] = this.config.quietHoursStart.split(':').map(Number);
    const [endHour, endMin] = this.config.quietHoursEnd.split(':').map(Number);
    
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
   * Set up handler for incoming messages (replies)
   */
  private setupMessageHandler(): void {
    this.bot.on('message', (msg) => {
      if (!msg.text || msg.chat.id.toString() !== this.config.chatId) {
        return;
      }

      // Handle reply to approval message
      if (msg.reply_to_message && this.messageHandlers.has(msg.reply_to_message.message_id)) {
        const handler = this.messageHandlers.get(msg.reply_to_message.message_id)!;
        handler(msg.text);
        this.messageHandlers.delete(msg.reply_to_message.message_id);
      }
    });
  }

  /**
   * Send approval required notification
   */
  async sendApprovalNotification(
    requestId: string,
    action: string,
    description: string,
    context?: string
  ): Promise<TelegramResponse | null> {
    if (!this.config.notifyOnApproval || this.isQuietHours()) {
      return null;
    }

    const message = `⏸️ *Claude needs approval*

${this.config.includeContext && context ? `Task: _${this.escapeMarkdown(context)}_\n\n` : ''}Claude wants to: \`${this.escapeMarkdown(action)}\`

${this.escapeMarkdown(description)}

Reply with: ✅ Approve | ❌ Deny | 💬 Ask`;

    const sent = await this.bot.sendMessage(this.config.chatId, message, {
      parse_mode: 'Markdown',
      reply_markup: {
        inline_keyboard: [
          [
            { text: '✅ Approve', callback_data: `approve:${requestId}` },
            { text: '❌ Deny', callback_data: `deny:${requestId}` },
          ],
        ],
      },
    });

    return {
      messageId: sent.message_id,
      chatId: sent.chat.id,
      text: message,
      timestamp: new Date(),
    };
  }

  /**
   * Send task completed notification
   */
  async sendCompletionNotification(
    description: string,
    duration: number,
    filesChanged?: number,
    summary?: string
  ): Promise<TelegramResponse | null> {
    if (!this.config.notifyOnCompletion || this.isQuietHours()) {
      return null;
    }

    const durationMinutes = Math.round(duration / 60000);
    const durationText = durationMinutes < 1 ? '< 1 min' : `${durationMinutes} min`;

    let message = `✅ *Task Complete*\n\n`;
    
    if (this.config.includeContext) {
      message += `Task: _${this.escapeMarkdown(description)}_\n\n`;
    }
    
    message += `Duration: ${durationText}`;
    
    if (filesChanged !== undefined) {
      message += `\nFiles changed: ${filesChanged}`;
    }
    
    if (summary) {
      message += `\n\n_${this.escapeMarkdown(summary.substring(0, 200))}${summary.length > 200 ? '...' : ''}_`;
    }

    const sent = await this.bot.sendMessage(this.config.chatId, message, {
      parse_mode: 'Markdown',
    });

    return {
      messageId: sent.message_id,
      chatId: sent.chat.id,
      text: message,
      timestamp: new Date(),
    };
  }

  /**
   * Send long thinking notification
   */
  async sendLongThinkingNotification(
    description: string,
    thinkingDuration: number
  ): Promise<TelegramResponse | null> {
    if (!this.config.notifyOnLongThinking || this.isQuietHours()) {
      return null;
    }

    const durationMinutes = Math.round(thinkingDuration / 60000);

    const message = `🤔 *Still working...*

${this.config.includeContext ? `Task: _${this.escapeMarkdown(description)}_\n\n` : ''}Claude has been thinking for ${durationMinutes} minutes. Everything is proceeding normally.`;

    const sent = await this.bot.sendMessage(this.config.chatId, message, {
      parse_mode: 'Markdown',
    });

    return {
      messageId: sent.message_id,
      chatId: sent.chat.id,
      text: message,
      timestamp: new Date(),
    };
  }

  /**
   * Wait for a reply to a specific message
   */
  async waitForReply(messageId: number, timeoutMs: number = 300000): Promise<string | null> {
    return new Promise((resolve) => {
      const timeout = setTimeout(() => {
        this.messageHandlers.delete(messageId);
        resolve(null);
      }, timeoutMs);

      this.messageHandlers.set(messageId, (text: string) => {
        clearTimeout(timeout);
        resolve(text);
      });
    });
  }

  /**
   * Escape Markdown special characters
   */
  private escapeMarkdown(text: string): string {
    return text.replace(/([_*[\]()~`>#+\-=|{}.!])/g, '\\$1');
  }

  /**
   * Stop the bot
   */
  stop(): void {
    this.bot.stopPolling();
  }
}
