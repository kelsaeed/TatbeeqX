import { Router } from 'express';
import { asyncHandler } from '../lib/http.js';
import { getSubsystemInfo } from '../lib/subsystem.js';

// Phase 4.12 — public subsystem info endpoint.
//
// The frontend fetches this BEFORE login to decide:
//   - whether to brand the login screen (custom app name, logo)
//   - whether to apply lockdown rules (hide super-admin routes from the
//     router, filter the sidebar, show only the modules the template
//     declared)
//
// No auth required — the response is non-sensitive metadata about how
// the binary was built. (Actual permission enforcement happens on every
// other endpoint via `requirePermission` / `requireSuperAdmin`.)

const router = Router();

router.get(
  '/info',
  asyncHandler(async (_req, res) => {
    res.json(await getSubsystemInfo());
  }),
);

export default router;
