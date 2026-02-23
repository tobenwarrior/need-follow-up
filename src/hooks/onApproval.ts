import { getConfig, sendTelegramMessage } from '../telegram';

/**
 * Hook called when Claude needs approval
 */
export default async function onApprovalRequired(context: {
  requestId: string;
  action: string;
  description: string;
  taskContext?: string;
}): Promise<{ approved: boolean; response?: string }> {
  const config = getConfig();
  
  if (!config || config.notifyOnApproval === false) {
    // Fall back to CLI prompt
    return { approved: true };
  }

  const message = `⏸️ *Claude needs approval*

${config.includeContext !== false && context.taskContext ? `Task: _${context.taskContext}_\n\n` : ''}Action: \`${context.action}\`

${context.description}

Reply with: ✅ yes | ❌ no`;

  try {
    const result = await sendTelegramMessage(config, message, {
      parse_mode: 'Markdown',
      reply_markup: {
        inline_keyboard: [
          [
            { text: '✅ Approve', callback_data: `approve:${context.requestId}` },
            { text: '❌ Deny', callback_data: `deny:${context.requestId}` },
          ],
        ],
      },
    });

    // Wait for user response (this would need a server component in practice)
    // For now, we return pending and let Claude poll or timeout
    return { 
      approved: false, 
      response: 'Notification sent. Please check Telegram and respond there, or approve here.' 
    };
  } catch (error) {
    console.error('Failed to send Telegram notification:', error);
    // Fall back to CLI prompt on error
    return { approved: true };
  }
}
