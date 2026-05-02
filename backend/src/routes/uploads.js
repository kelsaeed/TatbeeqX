import { Router } from 'express';
import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { authenticate } from '../middleware/auth.js';
import { asyncHandler, badRequest } from '../lib/http.js';
import { writeAudit } from '../lib/audit.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadsDir = path.resolve(__dirname, '..', '..', 'uploads');

if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

const ALLOWED = new Set(['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/svg+xml', 'image/x-icon', 'image/vnd.microsoft.icon']);
const MAX_BYTES = 5 * 1024 * 1024;

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
  filename: (_req, file, cb) => {
    const safe = file.originalname.replace(/[^a-zA-Z0-9.\-_]/g, '_').slice(-60);
    const stamp = Date.now();
    const rand = Math.random().toString(36).slice(2, 8);
    cb(null, `${stamp}_${rand}_${safe || 'file'}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: MAX_BYTES },
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED.has(file.mimetype)) return cb(new Error('Unsupported file type'));
    cb(null, true);
  },
});

const router = Router();

router.post(
  '/image',
  authenticate,
  upload.single('file'),
  asyncHandler(async (req, res) => {
    if (!req.file) throw badRequest('No file uploaded');
    const url = `/uploads/${req.file.filename}`;
    await writeAudit({ req, action: 'upload', entity: 'File', metadata: { name: req.file.filename, size: req.file.size } });
    res.status(201).json({
      url,
      filename: req.file.filename,
      size: req.file.size,
      mime: req.file.mimetype,
    });
  }),
);

export { uploadsDir };
export default router;
