import { verifyAccessToken } from '../lib/jwt.js';
import { prisma } from '../lib/prisma.js';
import { unauthorized } from '../lib/http.js';
import { loadUserPermissions } from '../lib/permissions.js';

export async function authenticate(req, _res, next) {
  try {
    const header = req.get('authorization') || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) throw unauthorized('Missing access token');

    const payload = verifyAccessToken(token);
    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || !user.isActive) throw unauthorized('User inactive or removed');

    const permissions = await loadUserPermissions(user.id);

    req.user = {
      id: user.id,
      username: user.username,
      email: user.email,
      fullName: user.fullName,
      isSuperAdmin: user.isSuperAdmin,
      companyId: user.companyId,
      branchId: user.branchId,
    };
    req.permissions = permissions;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') return next(unauthorized('Access token expired'));
    if (err.name === 'JsonWebTokenError') return next(unauthorized('Invalid access token'));
    next(err);
  }
}
