// Phase 4.6 — extracted Express app builder.
//
// Pulled out of server.js so tests can mount the app via supertest without
// binding a port and without starting the cron loop.

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';

import { env, isProd } from '../config/env.js';
import api from '../routes/index.js';
import { uploadsDir } from '../routes/uploads.js';
import { errorHandler, notFoundHandler } from '../middleware/error.js';

export function buildApp({ silent = false } = {}) {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet({ crossOriginResourcePolicy: false }));
  // Phase 4.16 follow-up — gzip response compression. JSON typically
  // shrinks to 10-15% of its original size, which is the biggest single
  // perf win for endpoints like /api/audit and /api/system-logs that
  // can return MB-scale responses. Uncompressed is the Node default;
  // express ships nothing out of the box. Threshold of 1KB skips the
  // compress overhead on tiny payloads (auth.me, health, etc.).
  app.use(compression({ threshold: 1024 }));
  app.use(
    cors({
      origin: env.corsOrigin === '*' ? true : env.corsOrigin.split(',').map((s) => s.trim()),
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '2mb' }));
  app.use(express.urlencoded({ extended: true }));
  if (!silent) {
    app.use(morgan(isProd ? 'combined' : 'dev'));
  }

  app.use('/uploads', express.static(uploadsDir, { maxAge: '7d' }));
  app.use('/api', api);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
