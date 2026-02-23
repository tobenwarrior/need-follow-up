/**
 * Configuration interface for the Telegram notifier plugin
 */
export interface NotifierConfig {
  /** Telegram bot token from BotFather */
  botToken: string;
  /** Telegram chat ID to send notifications to */
  chatId: string;
  /** Send notification when approval is needed */
  notifyOnApproval?: boolean;
  /** Send notification when task completes */
  notifyOnCompletion?: boolean;
  /** Send notification when thinking exceeds threshold */
  notifyOnLongThinking?: boolean;
  /** Minutes before "long thinking" notification (default: 5) */
  longThinkingThresholdMinutes?: number;
  /** Include task context in notifications (default: true) */
  includeContext?: boolean;
  /** Start of quiet hours in 24h format (e.g., "22:00") */
  quietHoursStart?: string | null;
  /** End of quiet hours in 24h format (e.g., "08:00") */
  quietHoursEnd?: string | null;
}

/**
 * Claude Code event types that the plugin listens to
 */
export enum ClaudeEventType {
  APPROVAL_REQUIRED = 'approval:required',
  APPROVAL_GRANTED = 'approval:granted',
  APPROVAL_DENIED = 'approval:denied',
  TASK_STARTED = 'task:started',
  TASK_COMPLETED = 'task:completed',
  TASK_FAILED = 'task:failed',
  THINKING_STARTED = 'thinking:started',
  THINKING_PROGRESS = 'thinking:progress',
  HEARTBEAT = 'heartbeat',
}

/**
 * Approval event payload
 */
export interface ApprovalEvent {
  type: ClaudeEventType.APPROVAL_REQUIRED;
  requestId: string;
  action: string;
  description: string;
  context?: string;
  timestamp: Date;
}

/**
 * Task completion event payload
 */
export interface TaskCompletedEvent {
  type: ClaudeEventType.TASK_COMPLETED;
  taskId: string;
  description: string;
  duration: number; // in milliseconds
  filesChanged?: number;
  summary?: string;
  timestamp: Date;
}

/**
 * Long thinking event payload
 */
export interface LongThinkingEvent {
  type: ClaudeEventType.THINKING_PROGRESS;
  taskId: string;
  description: string;
  thinkingDuration: number; // in milliseconds
  timestamp: Date;
}

export type ClaudeEvent = ApprovalEvent | TaskCompletedEvent | LongThinkingEvent;

/**
 * Telegram message response
 */
export interface TelegramResponse {
  messageId: number;
  chatId: number;
  text: string;
  timestamp: Date;
}
