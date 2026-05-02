import { HttpError } from '../lib/http.js';
import { isProd } from '../config/env.js';

export function notFoundHandler(_req, res) {
  res.status(404).json({ error: { message: 'Route not found' } });
}

export function errorHandler(err, _req, res, _next) {
  if (err instanceof HttpError) {
    return res.status(err.status).json({
      error: { message: err.message, details: err.details ?? null },
    });
  }
  if (err?.code === 'P2002') {
    return res.status(409).json({
      error: { message: 'Duplicate value', details: err.meta?.target ?? null },
    });
  }
  if (err?.code === 'P2025') {
    return res.status(404).json({ error: { message: 'Record not found' } });
  }
  console.error(err);
  res.status(500).json({
    error: {
      message: isProd ? 'Internal server error' : err.message || 'Internal server error',
    },
  });
}
