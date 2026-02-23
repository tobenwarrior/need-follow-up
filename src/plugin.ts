import { 
  NotifierConfig, 
  ClaudeEventType, 
  ApprovalEvent, 
  TaskCompletedEvent,
  LongThinkingEvent 
} from './types';
import { TelegramNotifier } from './telegram';

/**
 * Main plugin class that integrates with Claude Code CLI
 */
export class ClaudeTelegramPlugin {
  private notifier: TelegramNotifier;
  private config: NotifierConfig;
  private activeTasks: Map<string, {
    description: string;
    startTime: Date;
    lastThinkingNotification?: Date;
  }> = new Map();
  private pendingApprovals: Map<string, {
    resolve: (value: boolean) => void;
    messageId: number;
  }> = new Map();

  constructor(config: NotifierConfig) {
    this.config = config;
    this.notifier = new TelegramNotifier(config);
  }

  /**
   * Initialize the plugin - called by Claude Code
   */
  async initialize(): Promise<void> {
    console.log('[Telegram Notifier] Plugin initialized');
    
    // Send startup notification
    await this.notifier.sendCompletionNotification(
      'Claude Code Telegram Notifier',
      0,
      undefined,
      'Plugin is now active. You will receive notifications for approvals and task completion.'
    );
  }

  /**
   * Handle approval required event from Claude Code
   */
  async onApprovalRequired(
    requestId: string,
    action: string,
    description: string,
    context?: string
  ): Promise<boolean> {
    const notification = await this.notifier.sendApprovalNotification(
      requestId,
      action,
      description,
      context
    );

    if (!notification) {
      // Quiet hours or disabled - fall back to CLI prompt
      return true;
    }

    // Wait for user reply
    return new Promise((resolve) => {
      this.pendingApprovals.set(requestId, {
        resolve,
        messageId: notification.messageId,
      });

      // Set up reply handler
      this.notifier.waitForReply(notification.messageId, 300000).then((reply) => {
        this.pendingApprovals.delete(requestId);
        
        if (!reply) {
          // Timeout - default to denying
          resolve(false);
          return;
        }

        const normalizedReply = reply.toLowerCase().trim();
        
        if (['yes', 'y', 'approve', '✅', 'ok', 'sure'].includes(normalizedReply)) {
          resolve(true);
        } else if (['no', 'n', 'deny', '❌', 'cancel', 'stop'].includes(normalizedReply)) {
          resolve(false);
        } else {
          // Ambiguous reply - ask for clarification via notification
          this.notifier.sendCompletionNotification(
            'Approval Response',
            0,
            undefined,
            `Received: "${reply}". Please reply with "yes" or "no".`
          );
          // Keep waiting
          this.pendingApprovals.set(requestId, { resolve, messageId: notification.messageId });
        }
      });
    });
  }

  /**
   * Handle task started event
   */
  onTaskStarted(taskId: string, description: string): void {
    this.activeTasks.set(taskId, {
      description,
      startTime: new Date(),
    });
  }

  /**
   * Handle task completed event
   */
  async onTaskCompleted(
    taskId: string,
    duration: number,
    filesChanged?: number,
    summary?: string
  ): Promise<void> {
    const task = this.activeTasks.get(taskId);
    
    if (task) {
      await this.notifier.sendCompletionNotification(
        task.description,
        duration,
        filesChanged,
        summary
      );
      
      this.activeTasks.delete(taskId);
    }
  }

  /**
   * Handle thinking progress (for long-running tasks)
   */
  async onThinkingProgress(taskId: string, thinkingDuration: number): Promise<void> {
    const task = this.activeTasks.get(taskId);
    
    if (!task) return;

    const thresholdMs = (this.config.longThinkingThresholdMinutes || 5) * 60000;
    
    // Only notify if we've exceeded threshold and haven't notified recently
    if (thinkingDuration > thresholdMs) {
      const lastNotification = task.lastThinkingNotification;
      const now = new Date();
      
      // Don't spam - only notify every 10 minutes after the first
      if (!lastNotification || (now.getTime() - lastNotification.getTime()) > 600000) {
        await this.notifier.sendLongThinkingNotification(
          task.description,
          thinkingDuration
        );
        
        task.lastThinkingNotification = now;
      }
    }
  }

  /**
   * Cleanup when plugin is stopped
   */
  async destroy(): Promise<void> {
    this.notifier.stop();
    console.log('[Telegram Notifier] Plugin stopped');
  }
}

// Export factory function for Claude Code
export function createPlugin(config: NotifierConfig): ClaudeTelegramPlugin {
  return new ClaudeTelegramPlugin(config);
}
