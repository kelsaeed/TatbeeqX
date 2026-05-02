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
};

export const isProd = env.nodeEnv === 'production';
