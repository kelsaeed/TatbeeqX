import 'dotenv/config';

function required(name, fallback) {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === '') {
    throw new Error(`Missing required env variable: ${name}`);
  }
  return value;
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 4000),
  host: process.env.HOST ?? '0.0.0.0',

  databaseUrl: required('DATABASE_URL', 'file:./dev.db'),

  jwtAccessSecret: required('JWT_ACCESS_SECRET', 'change-me-access-secret'),
  jwtRefreshSecret: required('JWT_REFRESH_SECRET', 'change-me-refresh-secret'),
  jwtAccessTtl: process.env.JWT_ACCESS_TTL ?? '15m',
  jwtRefreshTtl: process.env.JWT_REFRESH_TTL ?? '7d',

  corsOrigin: process.env.CORS_ORIGIN ?? '*',

  seed: {
    username: process.env.SEED_SUPERADMIN_USERNAME ?? 'superadmin',
    email: process.env.SEED_SUPERADMIN_EMAIL ?? 'superadmin@local',
    password: process.env.SEED_SUPERADMIN_PASSWORD ?? 'ChangeMe!2026',
  },

  // Phase 4.19 — outbound email via SMTP. Vendor-neutral (works with
  // SendGrid SMTP relay, AWS SES SMTP, Postmark SMTP, Gmail, self-
  // hosted Postfix). When SMTP_HOST is unset, the email lib falls
  // back to console-logging in dev and silently no-ops in prod (with
  // a SystemLog warning), so the rest of the system never crashes
  // for an unconfigured mail layer.
  smtp: {
    host: process.env.SMTP_HOST || null,
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE || 'false').toLowerCase() === 'true',
    user: process.env.SMTP_USER || null,
    pass: process.env.SMTP_PASS || null,
    from: process.env.SMTP_FROM || 'TatbeeqX <no-reply@localhost>',
  },
  // Public app URL for email links (password reset, etc.). LAN
  // installs can leave this at the default; cloud installs MUST set
  // it or password-reset links will point at localhost.
  appUrl: process.env.APP_URL || 'http://localhost:8080',
};

export const isProd = env.nodeEnv === 'production';
