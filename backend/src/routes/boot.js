// Phase 4.20 — pre-auth bundle.
//
// The Flutter app, on cold start, used to fire two independent
// unauthenticated requests in parallel:
//   - GET /api/subsystem/info  (lockdown / branding / module list)
//   - GET /api/themes/active   (login-screen theme)
//
// Both are tiny but on installs running on-access AV, each request
// pays a separate scanning round-trip. This single endpoint folds the
// two reads into one response — same data, one trip through the
// scanner, one less RTT before the login screen paints.
//
// Mounted BEFORE any auth middleware. Stays public; nothing here is
// sensitive (subsystem info is build metadata; the theme is what the
// login page needs to render).

import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { asyncHandler } from '../lib/http.js';
import { getSubsystemInfo } from '../lib/subsystem.js';
import { parseTheme } from '../lib/theme_parse.js';

const router = Router();

router.get(
  '/',
  asyncHandler(async (_req, res) => {
    // Same fallback chain as /themes/active with no companyId:
    // a global-active theme wins; otherwise fall back to the seeded
    // default theme. Run the two reads in parallel.
    const [subsystem, theme] = await Promise.all([
      getSubsystemInfo(),
      prisma.theme.findFirst({ where: { companyId: null, isActive: true } })
        .then((t) => t || prisma.theme.findFirst({ where: { isDefault: true } })),
    ]);
    res.json({
      subsystem,
      theme: theme ? parseTheme(theme) : null,
    });
  }),
);

export default router;
