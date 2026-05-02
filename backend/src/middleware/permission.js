import { forbidden, unauthorized } from '../lib/http.js';
import { hasPermission } from '../lib/permissions.js';

export function requirePermission(...codes) {
  return (req, _res, next) => {
    if (!req.user) return next(unauthorized());
    if (req.user.isSuperAdmin) return next();
    const perms = req.permissions ?? new Set();
    const ok = codes.every((c) => hasPermission(perms, c));
    if (!ok) return next(forbidden('Permission denied'));
    next();
  };
}

export function requireSuperAdmin() {
  return (req, _res, next) => {
    if (!req.user) return next(unauthorized());
    if (!req.user.isSuperAdmin) return next(forbidden('Super Admin only'));
    next();
  };
}
