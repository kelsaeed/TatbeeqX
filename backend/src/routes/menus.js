import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { asyncHandler } from '../lib/http.js';
import { buildMenuPayload } from '../lib/menu_payload.js';

const router = Router();

router.get(
  '/',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await buildMenuPayload(req.permissions));
  }),
);

export default router;
