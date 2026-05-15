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
    // Projected fetch — only the columns the request context needs.
    // Deliberately does NOT pull the role/permission graph: this runs
    // on EVERY authenticated request, and a super-admin (the common
    // studio user) never needs it. The old path issued this query
    // AND a second deep 4-level nested join (userRoles→role→
    // rolePermissions→permission + overrides) inside
    // loadUserPermissions — then threw the entire join away for
    // super-admins. On SQLite that doubled the per-request DB cost of
    // every list/menu/poll call.
    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true,
        isSuperAdmin: true,
        isActive: true,
        companyId: true,
        branchId: true,
      },
    });
    if (!user || !user.isActive) throw unauthorized('User inactive or removed');

    req.user = {
      id: user.id,
      username: user.username,
      email: user.email,
      fullName: user.fullName,
      isSuperAdmin: user.isSuperAdmin,
      companyId: user.companyId,
      branchId: user.branchId,
    };
    // Super-admin → wildcard set with no extra query. This is the
    // exact value loadUserPermissions() returns for a super-admin
    // (`new Set(['*'])`), and requirePermission()/hasPermission()
    // already special-case '*', so behavior is unchanged. Regular
    // users still resolve effective permissions from roles+overrides.
    req.permissions = user.isSuperAdmin
      ? new Set(['*'])
      : await loadUserPermissions(user.id);
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') return next(unauthorized('Access token expired'));
    if (err.name === 'JsonWebTokenError') return next(unauthorized('Invalid access token'));
    next(err);
  }
}
