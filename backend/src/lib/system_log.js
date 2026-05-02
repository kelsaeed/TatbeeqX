import { prisma } from './prisma.js';

const LEVELS = ['debug', 'info', 'warn', 'error'];

export async function logSystem(level, source, message, context) {
  if (!LEVELS.includes(level)) level = 'info';
  try {
    await prisma.systemLog.create({
      data: {
        level,
        source: String(source || 'system').slice(0, 80),
        message: String(message || '').slice(0, 2000),
        context: context ? JSON.stringify(context) : null,
      },
    });
  } catch (err) {
    console.error('system log failed', err);
  }
}

export async function recordLoginEvent({
  userId = null,
  username = null,
  event,
  success = true,
  reason = null,
  req = null,
}) {
  try {
    await prisma.loginEvent.create({
      data: {
        userId,
        username: username ? String(username).slice(0, 120) : null,
        event,
        success,
        reason: reason ? String(reason).slice(0, 240) : null,
        ipAddress: req?.ip ?? null,
        userAgent: req?.get?.('user-agent') ?? null,
      },
    });
  } catch (err) {
    console.error('login event failed', err);
  }
}
