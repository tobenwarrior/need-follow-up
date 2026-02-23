import { getConfig, sendTelegramMessage } from '../telegram';

/**
 * Hook called when a task completes
 */
export default async function onTaskComplete(context: {
  taskId: string;
  description: string;
  duration: number; // milliseconds
  filesChanged?: number;
  summary?: string;
}): Promise<void> {
  const config = getConfig();
  
  if (!config || config.notifyOnCompletion === false) {
    return;
  }

  const durationMinutes = Math.round(context.duration / 60000);
  const durationText = durationMinutes < 1 ? '< 1 min' : `${durationMinutes} min`;

  let message = `✅ *Task Complete*\n\n`;
  
  if (config.includeContext !== false) {
    message += `Task: _${context.description}_\n\n`;
  }
  
  message += `Duration: ${durationText}`;
  
  if (context.filesChanged !== undefined) {
    message += `\nFiles changed: ${context.filesChanged}`;
  }
  
  if (context.summary) {
    const shortSummary = context.summary.substring(0, 200);
    message += `\n\n_${shortSummary}${context.summary.length > 200 ? '...' : ''}_`;
  }

  try {
    await sendTelegramMessage(config, message, { parse_mode: 'Markdown' });
  } catch (error) {
    console.error('Failed to send Telegram notification:', error);
  }
}
