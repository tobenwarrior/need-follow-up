import { getConfig, sendTelegramMessage } from '../telegram';

/**
 * Hook called when Claude starts thinking for a while
 */
export default async function onThinkingStart(context: {
  taskId: string;
  description: string;
  thinkingDuration: number; // milliseconds
}): Promise<void> {
  const config = getConfig();
  
  if (!config || config.notifyOnLongThinking === false) {
    return;
  }

  const thresholdMs = (config.longThinkingThresholdMinutes || 5) * 60000;
  
  // Only notify if we've exceeded threshold
  if (context.thinkingDuration < thresholdMs) {
    return;
  }

  const durationMinutes = Math.round(context.thinkingDuration / 60000);

  const message = `🤔 *Still working...*

${config.includeContext !== false ? `Task: _${context.description}_\n\n` : ''}Claude has been thinking for ${durationMinutes} minutes. Everything is proceeding normally.`;

  try {
    await sendTelegramMessage(config, message, { parse_mode: 'Markdown' });
  } catch (error) {
    console.error('Failed to send Telegram notification:', error);
  }
}
