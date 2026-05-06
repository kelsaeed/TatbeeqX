// Phase 4.20 (Phase 2) — Subsystems Manager API.
//
// Studio-only feature. Subsystem (locked-down) builds hide this
// surface via HIDDEN_IN_LOCKDOWN; backend access is restricted to
// super-admin so a customer who somehow enables the route still
// can't poke at the registry.

import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { requireSuperAdmin } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound } from '../lib/http.js';
import {
  listSubsystems,
  getSubsystem,
  registerSubsystem,
  unregisterSubsystem,
  startSubsystem,
  stopSubsystem,
  restartSubsystem,
  reassignPort,
  tailLog,
  inspectBundle,
  REGISTRY_PATH,
} from '../lib/subsystems_manager.js';

const router = Router();
router.use(authenticate);
router.use(requireSuperAdmin());

router.get(
  '/',
  asyncHandler(async (_req, res) => {
    res.json({ items: listSubsystems(), registryPath: REGISTRY_PATH });
  }),
);

// Pre-flight check before registration. The frontend uses this when
// the user picks a path so we can show "looks like a valid bundle —
// port 4040" before they commit.
router.post(
  '/inspect',
  asyncHandler(async (req, res) => {
    const { bundleDir } = req.body || {};
    if (!bundleDir || typeof bundleDir !== 'string') {
      throw badRequest('bundleDir is required');
    }
    try {
      const info = inspectBundle(bundleDir);
      res.json({
        bundleDir: info.bundleDir,
        port: info.port,
        suggestedName: info.suggestedName,
        hasExe: !!info.exePath,
      });
    } catch (err) {
      throw badRequest(err.message);
    }
  }),
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const { bundleDir, name } = req.body || {};
    if (!bundleDir || typeof bundleDir !== 'string') {
      throw badRequest('bundleDir is required');
    }
    try {
      const item = registerSubsystem({ bundleDir, name });
      res.status(201).json(item);
    } catch (err) {
      throw badRequest(err.message);
    }
  }),
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    try {
      const removed = unregisterSubsystem(req.params.id);
      if (!removed) throw notFound('Subsystem not found');
      res.status(204).end();
    } catch (err) {
      if (err.status) throw err;
      throw badRequest(err.message);
    }
  }),
);

router.post(
  '/:id/start',
  asyncHandler(async (req, res) => {
    const existing = getSubsystem(req.params.id);
    if (!existing) throw notFound('Subsystem not found');
    try {
      const item = await startSubsystem(req.params.id);
      res.json(item);
    } catch (err) {
      throw badRequest(err.message);
    }
  }),
);

router.post(
  '/:id/stop',
  asyncHandler(async (req, res) => {
    const existing = getSubsystem(req.params.id);
    if (!existing) throw notFound('Subsystem not found');
    try {
      const item = stopSubsystem(req.params.id);
      res.json(item);
    } catch (err) {
      throw badRequest(err.message);
    }
  }),
);

router.post(
  '/:id/port',
  asyncHandler(async (req, res) => {
    const existing = getSubsystem(req.params.id);
    if (!existing) throw notFound('Subsystem not found');
    const port = Number(req.body?.port);
    try {
      const item = reassignPort(req.params.id, port);
      res.json(item);
    } catch (err) {
      throw badRequest(err.message);
    }
  }),
);

router.post(
  '/:id/restart',
  asyncHandler(async (req, res) => {
    const existing = getSubsystem(req.params.id);
    if (!existing) throw notFound('Subsystem not found');
    try {
      const item = await restartSubsystem(req.params.id);
      res.json(item);
    } catch (err) {
      throw badRequest(err.message);
    }
  }),
);

router.get(
  '/:id/logs',
  asyncHandler(async (req, res) => {
    const existing = getSubsystem(req.params.id);
    if (!existing) throw notFound('Subsystem not found');
    const requested = Number(req.query?.lines);
    const lines = Number.isFinite(requested) && requested > 0
      ? Math.min(2000, Math.floor(requested))
      : 200;
    try {
      res.json(tailLog(req.params.id, lines));
    } catch (err) {
      throw badRequest(err.message);
    }
  }),
);

export default router;
