// Phase 4.18 — in-app notifications.
//
// Per-user notification rows. Created either by the workflow engine's
// `notify_user` action or by any backend code that imports `notify`.
// The frontend topbar bell polls `unread-count`, and a notifications
// page (or popover) renders the list.
//
// Resolver convention for the workflow action: callers may identify
// the target user by `userId`, `username`, or `email` (in that order
// of precedence). Returns null when none resolve, which the action
// surfaces as a step failure so the operator knows the workflow
// targeted a non-existent user.

import { prisma } from './prisma.js';
import { logSystem } from './system_log.js';

const TITLE_CAP = 200;
const BODY_CAP = 2_000;
const LINK_CAP = 500;

export async function notify(userId, { kind = 'system', title, body, link } = {}) {
  if (!Number.isInteger(userId) || userId <= 0) {
    throw new Error('notify: userId must be a positive integer');
  }
  if (typeof title !== 'string' || title.length === 0) {
    throw new Error('notify: title required');
  }
  return prisma.notification.create({
    data: {
      userId,
      kind: String(kind || 'system').slice(0, 64),
      title: title.slice(0, TITLE_CAP),
      body: body == null ? null : String(body).slice(0, BODY_CAP),
      link: link == null ? null : String(link).slice(0, LINK_CAP),
    },
  });
}

export async function resolveUserId({ userId, username, email } = {}) {
  // Numeric id wins. Falls back to username, then email. Returns null
  // when nothing matches — the caller decides how to surface that.
  if (Number.isFinite(Number(userId)) && Number(userId) > 0) {
    const u = await prisma.user.findUnique({ where: { id: Number(userId) } });
    if (u) return u.id;
  }
  if (typeof username === 'string' && username.length > 0) {
    const u = await prisma.user.findUnique({ where: { username } });
    if (u) return u.id;
  }
  if (typeof email === 'string' && email.length > 0) {
    const u = await prisma.user.findUnique({ where: { email } });
    if (u) return u.id;
  }
  return null;
}

// Best-effort fan-out helper for callers that want to ping every user
// with a given role code. Used by future broadcast features; v1 doesn't
// expose this through the workflow action (would be too easy to spam).
export async function notifyRole(roleCode, payload) {
  try {
    const users = await prisma.user.findMany({
      where: { isActive: true, userRoles: { some: { role: { code: roleCode } } } },
      select: { id: true },
    });
    let delivered = 0;
    const failures = [];
    for (const u of users) {
      try {
        await notify(u.id, payload);
        delivered++;
      } catch (err) {
        failures.push({ userId: u.id, error: String(err?.message || err) });
      }
    }
    if (failures.length > 0) {
      await logSystem('warn', 'notifications', 'notifyRole partial failure', {
        roleCode, attempted: users.length, delivered, failures: failures.slice(0, 20),
      }).catch(() => {});
    }
    return delivered;
  } catch (err) {
    await logSystem('warn', 'notifications', 'notifyRole failed', {
      roleCode, error: String(err?.message || err),
    }).catch(() => {});
    return 0;
  }
}
